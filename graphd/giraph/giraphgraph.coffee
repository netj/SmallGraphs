fs = require "fs"
{spawn} = require "child_process"

{StateMachineGraph} = require "../statemachinegraph"

class GiraphGraph extends StateMachineGraph
    constructor: (@descriptor) ->
        super @descriptor
        d = @descriptor
        unless d.graphPath?
            throw new Error "graphPath, ... are required for the graph descriptor"
        # populate schema from descriptor
        objects = {}
        for nodeTypeId,nodeType of d.nodes
            o = objects[nodeType.type] =
                Attributes: nodeType.props
                Label: nodeType.label
            o.Links = {}
            nodeTypeId = parseInt nodeTypeId
            for edgeTypeId,edgeType of d.edges when nodeTypeId in edgeType.domain
                l = o.Links[edgeType.type] ?= []
                l.push d.nodes[rangeNodeTypeId].type for rangeNodeTypeId in edgeType.range
        @schema.Objects = objects

    _runStateMachine: (statemachine, limit, offset, req, res, q) ->
        # generate Pregel vertex compute code from statemachine
        javaCode = @generateJavaCode statemachine
        javaFile = "SmallGraphGiraphVertex.java"
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
        
        #  TODO map types, node/edge URIs in query to long long int IDs
        q.emit 'result', JSON.stringify javaCode; return # FIXME lets construct the correct statemachine for the moment

        # use match.sh to compile, link, and run it
        run = spawn "./match.sh", [cxxPath, @descriptor.graphPath]
        rawResults = ""
        run.on 'data', (data) ->
            # collect raw matches
            rawResults += data
        run.on 'exit', (code) ->
            switch code
                when 0
                    # TODO collect results
                    rawResults
                    # TODO  inverse-map long long int IDs back to types, node/edge URIs
                    result = []
                    q.emit 'result', result
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

            else if expr.findCompatibleMatchesWithMatches?
                { list: "Matches" }
            else if expr.newMatches?
                "Matches"

            else
                "/* XXX: unknown type for expr: #{JSON.stringify expr} */ void"

        codegenName = (sym) ->
            # TODO check and generate unique symbols?
            codegenExpr sym

        codegenNodeIdExpr = (expr) ->
            if typeof expr == 'string' and expr == '$this'
                "#{codegenExpr expr}.getVertexId()"
            else
                codegenExpr expr

        codegenExpr = (expr) ->
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
                    newPathArgs.push codegenExpr expr.augmentedWithEdge
                # TODO collect attribute/property values
                "new MatchPath(#{newPathArgs.join ", "})"

            else if expr.findCompatibleMatchesWithMatches?
                # TODO can we expand this?
                "findCompatibleMatchesWithMatches(#{codegenExpr expr.findCompatibleMatchesWithMatches}, #{
                        expr.ofWalks.join ", "})"
            else if expr.newMatchesAtNode?
                "new Matches(#{codegenNodeIdExpr expr.newMatchesAtNode})"

            else
                "/* XXX: unknown expr: #{JSON.stringify expr} */ null"

        codegenConstraints = (pmap, constraints) ->
            codegenSingleConstraint = (c) ->
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

        codegenAction = (action) ->
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
                this.sendMsg(#{codegenNodeIdExpr action.to}, new Message(#{codegenExpr action.sendMessage}#{
                    if action.withPath? then ", " + codegenExpr action.withPath else ""
                }#{
                    if action.withMatches? then ", " + codegenExpr action.withMatches else ""
                }));
                """

            else if action.whenEdge?
                cond = action.satisfies
                # TODO edgeTypeId = typeDictionary cond.linkType
                edgeTypeId = codegenExpr cond.linkType
                """
                {
                PropertyMap eV = this.getEdgeValue(#{codegenExpr action.whenEdge});
                if (eV.getType() == #{edgeTypeId}) #{codegenConstraints "eV", cond.constraints}
                    #{codegenAction action.then}
                }
                """
            else if action.whenNode?
                cond = action.satisfies
                # TODO map to typeId: nodeTypeId = typeDictionary cond.objectType
                nodeTypeId = codegenExpr cond.objectType
                """
                if (#{codegenExpr action.whenNode}.getVertexValue().getType() == #{nodeTypeId}) #{codegenConstraints (codegenExpr action.whenNode), cond.constraints}
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

        codegenCase = (msg) ->
            a = """
            case #{msg.msgId}:
                // #{msg.description}
                #{codegenAction msg.action}
                break;
            """
        """
        public class SmallGraphGiraphVertex extends BaseSmallGraphGiraphVertex  {
        @Override
        void handleMessage(int msgId, Path path, Matches matches) {
            switch (msgId) {
                #{(codegenCase msg for msg in statemachine.messages).join "\n"}
            }
            voteToHalt();
        }
        }
        """


exports.GiraphGraph = GiraphGraph
