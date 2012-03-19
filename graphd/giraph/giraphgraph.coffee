fs = require "fs"
path = require "path"
{spawn} = require "child_process"

{StateMachineGraph} = require "../statemachinegraph"

class GiraphGraph extends StateMachineGraph
    constructor: (@descriptor, @basepath) ->
        super @descriptor, @basepath
        d = @descriptor
        unless d.graphPath? and d.codingSchemaPath?
            throw new Error "graphPath, codingSchemaPath, ... are required for the graph descriptor"

        # populate schema from codingSchema
        @codingSchema = JSON.parse (fs.readFileSync "#{@basepath}/#{d.codingSchemaPath}")
        attributesSchemaForProperties = (properties) =>
            if properties?
                attrs = {}
                for propId in properties
                    prop = @codingSchema.properties[propId]
                    attrs[prop.name] = prop.dataType
                attrs
            else
                null
        @schema.Objects = objects = {}
        for nodeTypeId,nodeType of @codingSchema.nodeTypes
            nodeTypeId = parseInt nodeTypeId
            o = objects[nodeType.name] =
                Attributes: attributesSchemaForProperties nodeType.properties
                Label: @codingSchema.properties[nodeType.labelProperty]?.name
            # TODO use centralized domain/range instead
            o.Links = {}
            for edgeTypeId,edgeType of @codingSchema.edgeTypes when nodeTypeId in edgeType.domain
                l = o.Links[edgeType.name] ?= []
                l.push @codingSchema.nodeTypes[rangeNodeTypeId].name for rangeNodeTypeId in edgeType.range
        # @schema.Links = links = {}
        # for edgeTypeId,edgeType of @codingSchema.edgeTypes
        #     links[edgeType.name] =
        #         Attributes: attributesSchemaForProperties edgeType.properties
        #         Label: @codingSchema.properties[edgeType.labelProperty]?.name
        #         Domain: edgeType.domain.map (nodeType) => @codingSchema.nodeTypes[nodeType].name
        #         Range : edgeType.range .map (nodeType) => @codingSchema.nodeTypes[nodeType].name

        # prepare a map for encoding
        @encodingMap = enc = {}
        enc.nodeTypes = {}
        for nodeTypeId,nodeType of @codingSchema.nodeTypes
            nodeTypeId = parseInt nodeTypeId
            enc.nodeTypes[nodeType.name] = nodeTypeId
        enc.edgeTypes = {}
        for edgeTypeId,edgeType of @codingSchema.edgeTypes
            edgeTypeId = parseInt edgeTypeId
            enc.edgeTypes[edgeType.name] = edgeTypeId
        enc.properties = {}
        for propId,prop of @codingSchema.properties
            propId = parseInt propId
            enc.properties[prop.name] = propId

    _runStateMachine: (statemachine, limit, offset, req, res, q) ->
        # generate Pregel vertex code from statemachine
        javaCode = @generateJavaCode statemachine
        # FIXME for debug
        javaFile = "test.java"
        fs.writeFileSync javaFile, javaCode
        # indent with Vim
        spawn "screen", [
            "-D"
            "-m"
            "vim"
            "-n"
            "+set sw=2 sts=2"
            "+norm gg=G"
            "+wq"
            javaFile
        ]
        # FIXME end of debug
        #  TODO map types, node/edge URIs in query to long long int IDs
        run = spawn "./giraph/run-smallgraph-on-giraph", [
            "SmallGraphGiraphVertex"
            path.join @basepath, @descriptor.graphPath
        ]
        rawResults = ""
        run.stderr.setEncoding 'utf-8'
        run.stderr.pipe process.stderr, { end: false }
        run.stdout.setEncoding 'utf-8'
        run.stdout.on 'data', (chunk) ->
            # collect raw matches
            rawResults += chunk
        run.on 'exit', (code, signal) ->
            switch code
                when 0
                    # TODO collect results
                    result = [rawResults]
                    # TODO  inverse-map long long int IDs back to types, node/edge URIs
                    q.emit 'result', result
                else
                    q.emit 'error', new Error "run-smallgraph-on-giraph ended with #{code}:\n" +
                        "#{rawResults.split(/\n/).map((l) -> "    "+l).join("\n")}"
        run.stdin.end javaCode, 'utf-8'
    generateJavaCode: (statemachine) ->
        codegenType = (expr) ->
            if expr.targetNodeOf?
                "LongWritable"
            else if expr.nodesBeforeWalk?
                { list: "LongWritable" }
            else if expr.outgoingEdgesOf?
                { list: "LongWritable" }

            else if expr.newPath?
                "MatchPath"

            else if expr.findAllConsistentMatches?
                { list: "Matches" }
            else if expr.newMatches?
                "Matches"

            else
                "/* XXX: unknown type for expr: #{JSON.stringify expr} */ void"

        codegenName = (sym) =>
            # TODO check and generate unique symbols?
            codegenExpr sym

        constants = {}
        constantSymCount = 0
        codegenConstant = (type, namePrefix, exprCode) =>
            c = constants[exprCode]
            unless c?
                c =
                    type: type
                    name: "#{namePrefix}_#{constantSymCount++}"
                constants[exprCode] = c
            c.name

        codegenNodeIdExpr = (expr) =>
            if typeof expr == 'string' and expr == '$this'
                "#{codegenExpr expr}.getVertexId().get()"
            else
                codegenExpr expr

        codegenEdgeIdExpr = (expr) =>
            if typeof expr == 'string' and expr == '$e'
                "#{codegenExpr expr}.get()"
            else
                codegenExpr expr

        codegenExpr = (expr) =>
            switch typeof expr
                when 'string'
                    if expr.match /^\$/ # symbol
                        return expr.replace /^\$/, ""
                    else # string literal
                        return "\"#{expr.replace /"/g, "\\\""}\""
                when 'number' # number literal
                    return expr
                when 'object'
                    true
                else
                    return "/* XXX: invalid expression of type #{typeof expr}: #{JSON.stringify expr} */ null"

            if expr.targetNodeOf?
                codegenExpr expr.targetNodeOf
            else if expr.nodesBeforeWalk?
                "#{
                    codegenExpr expr.inMatches
                }.getVertexIdsOfMatchesForWalk(#{
                    codegenExpr expr.nodesBeforeWalk
                })"

            else if expr.outgoingEdgesOf?
                codegenExpr expr.outgoingEdgesOf

            else if expr.newPath?
                newPathArgs = []
                if expr.newPath
                    newPathArgs.push codegenExpr expr.newPath
                if expr.augmentedWithNode?
                    newPathArgs.push codegenNodeIdExpr expr.augmentedWithNode
                else if expr.augmentedWithEdge?
                    # XXX EdgeListVertex has no ID for edges
                    newPathArgs.push codegenEdgeIdExpr expr.augmentedWithEdge
                # TODO collect attribute/property values
                "new MatchPath(#{newPathArgs.join ", "})"

            else if expr.findAllConsistentMatches?
                # TODO can we generate more explicit code for this?
                codegenPath = (path) => "new int[]{#{path.join ","}}"
                codegenPaths = (paths) => "new int[][]{#{paths.map(codegenPath).join(", ")}}"
                pathsetCode =
                    if expr.findAllConsistentMatches == 0
                        "null"
                    else
                        "new int[][][]{#{
                            (codegenPaths paths for s,paths of expr.findAllConsistentMatches).join ", "
                        }}"
                # make pathsetCode a constant field and use it
                if pathsetCode != "null"
                    pathsetCode = codegenConstant "int[][][]", "PATHSET", pathsetCode
                "this.getAllConsistentMatches(#{pathsetCode}, #{expr.ofWalks.join ","})"
            else if expr.newMatchesAtNode?
                "new Matches(#{codegenNodeIdExpr expr.newMatchesAtNode})"

            else
                "/* XXX: unknown expr: #{JSON.stringify expr} */ null"

        codegenConstraints = (pmap, constraints) =>
            codegenSingleConstraint = (c) =>
                [name, rel, value] = c
                if name?
                    switch typeof value
                        when "number"
                            if value == parseInt value
                                "#{pmap}.getLong(#{name}) #{rel} #{value}"
                            else
                                "#{pmap}.getDouble(#{name}) #{rel} #{value}"
                        when "string"
                            "#{pmap}.getString(#{name}) #{rel} \"#{value.replace /"/g, "\\\""}\""
                        else
                            "false /* XXX: unable to compile constraint: #{JSON.stringify c} */"
                else
                    "#{eV} #{rel} #{value}"
            if constraints? and constraints.length > 0 and constraints[0]? and constraints[0].length > 0
                code = "if ("
                numdisjs = 0
                for disjunction in constraints
                    if disjunction.length > 0
                        code += " && " if numdisjs > 0
                        code += "(#{disjunction.map(codegenSingleConstraint).join(" || ")})"
                        numdisjs++
                code
            else
                ""

        codegenAction = (action) =>
            if action instanceof Array
                if action.length == 1
                    codegenAction action[0]
                else
                    """
                    {
                        #{(codegenAction a for a in action).join "\n"}
                    }
                    """

            else if action.foreach?
                if typeof action.in == 'object'
                    xsty = codegenType action.in
                    xty = xsty?.list ? "Object"
                    """
                    for (#{xty} #{codegenExpr action.foreach} : #{codegenExpr action.in})
                        #{codegenAction action.do}
                    """
                else
                    """
                    // XXX unknown iteration target for foreach: #{JSON.stringify action}
                    """

            else if action.let?
                """
                {
                    #{codegenType action.be} #{codegenName action.let} = #{codegenExpr action.be};
                    #{codegenAction action.in}
                }
                """

            else if action.emitMatches?
                """
                emitMatches(#{codegenExpr action.emitMatches});
                """

            else if action.sendMessage?
                """
                this.sendMsg(#{codegenNodeIdExpr action.to}, new MatchingMessage(#{codegenExpr action.sendMessage}#{
                    if action.withMatches? then ", " + codegenExpr action.withMatches else ""
                }#{
                    if action.withPath? then ", " + codegenExpr action.withPath else ""
                }));
                """

            else if action.whenEdge?
                cond = action.satisfies
                edgeTypeId = @encodingMap.edgeTypes[cond.linkType]
                """
                {
                PropertyMap eV = this.getEdgeValue(#{codegenExpr action.whenEdge});
                if (#{codegenExpr edgeTypeId} == eV.getType()) #{codegenConstraints "eV", cond.constraints}
                    #{codegenAction action.then}
                }
                """
            else if action.whenNode?
                cond = action.satisfies
                nodeTypeId = @encodingMap.nodeTypes[cond.objectType]
                """
                if (#{codegenExpr nodeTypeId} == #{codegenExpr action.whenNode}.getVertexValue().getType()) #{codegenConstraints (codegenExpr action.whenNode), cond.constraints}
                    #{codegenAction action.then}
                """

            else if action.rememberMatches?
                if action.ofNode != "$this"
                    """
                    // XXX can't remember matches of node: #{action.ofNode}
                    """
                else if action.viaWalk?
                    """
                    this.getVertexValue().getMatches().addPathWithMatchesArrived(#{codegenExpr action.viaWalk}, #{codegenExpr action.withPath}, #{codegenExpr action.rememberMatches});
                    """
                else if action.returnedFromWalk?
                    """
                    this.getVertexValue().getMatches().addMatchesReturned(#{codegenExpr action.returnedFromWalk}, #{codegenExpr action.rememberMatches});
                    """

            else
                "// unknown action node: #{JSON.stringify action}"

        codegenSingleHandler = (msg) =>
            a = """
            case #{msg.msgId}:
                // #{msg.description}
                #{codegenAction msg.action}
                break;
            """

        maxMsgId = 0
        for step,msgs of statemachine.actionByMessages
            maxMsgId = Math.max maxMsgId, msgs.length

        """
        import org.apache.hadoop.io.LongWritable;

        import edu.stanford.smallgraphs.BaseSmallGraphGiraphVertex;
        import edu.stanford.smallgraphs.MatchPath;
        import edu.stanford.smallgraphs.Matches;
        import edu.stanford.smallgraphs.MatchingMessage;
        import edu.stanford.smallgraphs.PropertyMap;

        public class SmallGraphGiraphVertex extends BaseSmallGraphGiraphVertex  {

        @Override
	public void handleMessages(Iterable<MatchingMessage> messages) {
            boolean[] messageHasArrived = new boolean[#{maxMsgId}];
            for (MatchingMessage msg : messages) {
                messageHasArrived[msg.getMessageId()] = true;
                handleMessage(msg.getMessageId(), msg.getPath(), msg.getMatches());
            }
            for (int i=0; i<messageHasArrived.length; i++)
                if (messageHasArrived[i])
                    handleAggregatedMessage(i);
        }

        private void handleMessage(int msgId, MatchPath path, Matches matches) {
            switch (msgId) {#{statemachine.actionByMessages.individual.map(codegenSingleHandler).join "\n"}
            }
        }

        private void handleAggregatedMessage(int msgId) {
            switch (msgId) {#{statemachine.actionByMessages.aggregated.map(codegenSingleHandler).join "\n"}
            }
        }

        #{
            ("private static final #{c.type} #{c.name} = #{code};" for code,c of constants
            ).join "\n"
        }

        }
        """


exports.GiraphGraph = GiraphGraph
