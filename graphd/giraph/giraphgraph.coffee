fs = require "fs"
path = require "path"
{spawn} = require "child_process"
_ = require "underscore"

{StateMachineGraph} = require "../statemachinegraph"

class GiraphGraph extends StateMachineGraph
    constructor: (@descriptor, @basepath) ->
        super @descriptor, @basepath
        d = @descriptor
        unless d.hdfsPath? and d.codingSchemaPath?
            throw new Error "hdfsPath, codingSchemaPath, ... are required for the graph descriptor"

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
        javaClassName = "SmallGraphGiraphVertex"
        javaCode = @generateJavaCode javaClassName, statemachine
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
            javaClassName
            @descriptor.hdfsPath
            @basepath
        ]
        run.stderr.setEncoding 'utf-8'
        run.stderr.pipe process.stderr, { end: false }
        run.stdout.setEncoding 'utf-8'
        results = []
        stdoutRemainder = ""
        generateEachMatch = @resultGeneratorForMatches statemachine
        run.stdout.on 'data', (chunk) ->
            # collect results from output
            lines = (stdoutRemainder + chunk).split /\n/
            stdoutRemainder = lines.pop()
            for line in lines when line.length > 0
                matches = JSON.parse line #(line.replace /[{][}]/g, "null")
                generateEachMatch matches, (r) ->
                    # TODO can't we just do q.emit 'eachResult' here?
                    results.push (JSON.parse JSON.stringify r)
        run.on 'exit', (code, signal) ->
            switch code
                when 0
                    q.emit 'result', results
                else
                    q.emit 'error', new Error "run-smallgraph-on-giraph ended with #{code}:\n" +
                        "#{results.map((l) -> "    "+l).join("\n")}"
        run.stdin.end javaCode, 'utf-8'

    generateJavaCode: (javaClassName, statemachine) ->
        codegenType = (expr) ->
            if expr.targetNodeOf?
                "LongWritable"
            else if expr.nodesBeforeWalk?
                { list: "LongWritable" }
            else if expr.outgoingEdgesOf?
                { list: "LongWritable" }

            else if expr.newPath?
                "List<PathElement>"

            else if expr.collectedAttributes?
                "PropertyMap"

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
                "#{codegenExpr expr}.getVertexId()"
            else
                codegenExpr expr

        codegenEdgeIdExpr = (expr) =>
            if typeof expr == 'string' and expr == '$e'
                #"#{codegenExpr expr}.get()"
                "null" # XXX Using null instead? EdgeListVertex has no Id for edges
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
                # TODO collect attribute/property values
                if expr.augmentedWithNode?
                    newPathArgs.push "new PathElement(#{
                        codegenNodeIdExpr expr.augmentedWithNode
                    }#{
                        if not expr.andAttributes? then ""
                        else ", #{codegenExpr expr.andAttributes}"
                    })"
                else if expr.augmentedWithEdge?
                    # XXX EdgeListVertex has no ID for edges
                    newPathArgs.push "new PathElement(#{
                        codegenEdgeIdExpr expr.augmentedWithEdge
                    }#{
                        if not expr.andAttributes? then ""
                        else ", #{codegenExpr expr.andAttributes}"
                    })"
                if expr.newPath
                    "Matches.newAugmentedPath(#{codegenExpr expr.newPath}, #{newPathArgs.join ", "})"
                else
                    "Matches.newPath(#{newPathArgs.join ", "})"

            else if expr.collectedAttributes?
                "#{
                    if expr.ofNode?
                        "#{codegenExpr expr.ofNode}.getVertexValue()"
                    else if expr.ofEdge?
                        "#{codegenExpr expr.ofNode}.getEdgeValue()"
                }.project(#{
                    (
                        for [attrName, attrConstraint] in expr.collectedAttributes
                            codegenExpr String @encodingMap.properties[attrName]
                    ).join(", ")
                })"

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
                "new Matches(new PathElement(#{
                    codegenNodeIdExpr expr.newMatchesAtNode
                }#{
                    unless expr.andAttributes? then ""
                    else ", #{codegenExpr expr.andAttributes}"
                }))"

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
                if (#{codegenExpr edgeTypeId} == eV.getType())
                #{codegenConstraints "eV", cond.constraints} {
                    #{codegenAction action.then}
                }
                }
                """
            else if action.whenNode?
                cond = action.satisfies
                nodeTypeId = @encodingMap.nodeTypes[cond.objectType]
                """
                if (#{codegenExpr nodeTypeId} == #{codegenExpr action.whenNode}.getVertexValue().getType())
                #{codegenConstraints (codegenExpr action.whenNode), cond.constraints} {
                #{codegenAction action.then}
                }
                """

            else if action.rememberAttributes?
                if action.ofNode != "$this"
                    """
                    // XXX can't remember matches of node: #{action.ofNode}
                    """
                else
                    """
                    this.getVertexValue().getMatches().vertex.properties = #{codegenExpr action.rememberAttributes};
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
        import java.io.FileInputStream;
        import java.util.List;
        import java.util.Map;
        
        import org.apache.commons.io.IOUtils;
        import org.apache.hadoop.io.LongWritable;
        import org.apache.giraph.utils.InternalVertexRunner;
        
        import com.google.common.collect.Maps;

        import edu.stanford.smallgraphs.giraph.BaseSmallGraphGiraphVertex;
        import edu.stanford.smallgraphs.giraph.Matches;
        import edu.stanford.smallgraphs.giraph.Matches.PathElement;
        import edu.stanford.smallgraphs.giraph.MatchingMessage;
        import edu.stanford.smallgraphs.giraph.PropertyMap;
        import edu.stanford.smallgraphs.giraph.FinalMatchesOutputFormat;
        import edu.stanford.smallgraphs.giraph.PropertyGraphJSONVertexInputFormat;
        

        public class #{javaClassName} extends BaseSmallGraphGiraphVertex  {

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

        private void handleMessage(int msgId, List<PathElement> path, Matches matches) {
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

        public static void main(String[] args) throws Exception {
            String fileName = "/tmp/smallgiraph.XXXXXX/input";
            @SuppressWarnings("unchecked")
            List<String> lines = (List<String>) IOUtils.readLines(new FileInputStream(fileName));
            String[] graph = lines.toArray(new String[0]);
            Map<String, String> params = Maps.newHashMap();
            Iterable<String> result = InternalVertexRunner.run(
                #{javaClassName}.class,
                PropertyGraphJSONVertexInputFormat.class,
                FinalMatchesOutputFormat.class
                // PropertyGraphJSONVertexOutputFormat.class
                , params, graph);
            for (String line : result)
                System.out.println(line);
        }

        }
        """

    # An example Matches will be: {"v":{"":25197,"a":{}},"w":{"0":[{"p":[{}],"m":{"v":{"":54,"a":{"50783":"EDTv is a comedy film directed by Ron Howard released in 1999."}}}},{"p":[{}],"m":{"v":{"":475,"a":{"50783":"Cocoon is a 1985 science fiction film, directed by Ron Howard about a group of elderly people who are rejuvenated by aliens. The movie starred Don Ameche, Wilford Brimley, Hume Cronyn, Brian Dennehy, Jack Gilford, Steve Guttenberg, Maureen Stapleton, Jessica Tandy, Gwen Verdon, Herta Ware, Tahnee Welch, and Linda Harrison."}}}},{"p":[{}],"m":{"v":{"":987,"a":{"50783":"Willow is a 1988 fantasy film directed by Ron Howard, based on a story by George Lucas."}}}},{"p":[{}],"m":{"v":{"":2458,"a":{"50783":"The Da Vinci Code is a 2006 feature film, which is based on the bestselling 2003 novel The Da Vinci Code by Dan Brown. It was one of the most anticipated films of 2006, and was previewed at the opening night of the Cannes Film Festival on May 17, 2006. The Da Vinci Code then entered major release in many other countries on May 18 2006 with its first showing in the United States on May 19 2006."}}}},{"p":[{}],"m":{"v":{"":4109,"a":{"50783":"Apollo 13 is a 1995 film portrayal of the ill-fated Apollo 13 lunar mission in 1970. The movie was adapted by William Broyles Jr. and Al Reinert from the book Lost Moon by Jim Lovell and Jeffrey Kluger. It was directed by Ron Howard."}}}},{"p":[{}],"m":{"v":{"":5652,"a":{"50783":"Far and Away (1992) is a drama movie directed by Ron Howard, starring Tom Cruise and Nicole Kidman. Cruise and Kidman play Irish immigrants seeking their fortune in 1890s America, eventually taking part in the Land Run of 1893."}}}},{"p":[{}],"m":{"v":{"":29972,"a":{"50783":"Dr. Seuss\u0027 How the Grinch Stole Christmas! better known as The Grinch is a 2000 live-action film, based on the 1957 book by Dr. Seuss. Due to additions made to the storyline so that it could be brought up to feature-length, it was considerably less faithful to the original book, creating a new back-story to explain the Grinch\u0027s motivations and reasons behind his hatred of Christmas."}}}},{"p":[{}],"m":{"v":{"":29408,"a":{"50783":"Parenthood is a 1989 film starring Steve Martin, Dianne Wiest, Dennis Dugan, Mary Steenburgen, Jason Robards, Rick Moranis, Tom Hulce, Martha Plimpton, Keanu Reeves, Harley Jane Kozak, Eileen Ryan, Helen Shaw, Jasen Fisher, Alisan Porter,Zachary LaVoy, Ivyann Schwan and Joaquin Phoenix (as Leaf Phoenix)."}}}},{"p":[{}],"m":{"v":{"":44785,"a":{"50783":"Splash is a 1984 fantasy film and romantic comedy film directed by Ron Howard and written by Lowell Ganz and Babaloo Mandel. It was the first movie released by Touchstone Pictures, which was established by The Walt Disney Company to release films targeted towards older audiences. Although originally conceived as an \"adult\" film, Splash today is considered by some to be a family-friendly movie."}}}},{"p":[{}],"m":{"v":{"":41355,"a":{"50783":"Ransom is a thriller film released in 1996, starring Mel Gibson, Rene Russo, and Gary Sinise and directed by Ron Howard."}}}}]}}
    # for a qgraph like: { "nodes": [ { "id": 0, "step": { "objectType": "Film106613686", "attrs": [ [ "comment" ] ], "sourceInQuery": { "name": "n1", "refs": [ [ 0, 0 ] ] } }, "walks_out": [ 0 ], "isCanonical": true, "visited": true, "isInitial": true }, { "id": 1, "step": { "objectType": "Actor109765278", "attrs": [ [ "placeOfBirth" ] ], "sourceInQuery": { "name": "n0", "refs": [ [ 0, 2 ] ] } }, "walks_in": [ 0 ], "isCanonical": true, "visited": true, "isTerminal": true } ], "edges": [ { "id": 0, "source": 0, "target": 1, "steps": [ 0, { "linkType": "director", "sourceInQuery": { "pos": [ 0, 1 ] } }, 1 ], "msgIdWalkingBase": 1, "msgIdArrived": 1 } ] }
    resultGeneratorForMatches: (statemachine) ->
        # prepare some vocabularies
        qgraph = statemachine.qgraph
        assign = (result, sourceInQuery, data) ->
            if sourceInQuery.name?
                (result.names ?= {})[sourceInQuery.name] = data
                for ref in sourceInQuery.refs
                    (result.walks[ref[0]] ?= [])[ref[1]] = sourceInQuery.name
            else if sourceInQuery.pos?
                (result.walks[sourceInQuery.pos[0]] ?= [])[sourceInQuery.pos[1]] = data
        decodeAttributes = (attrs) =>
            decodedAttrs = {}
            for aId,aV of attrs
                prop = @codingSchema.properties[aId]
                decodedAttrs[prop.name] = aV
            decodedAttrs
        # find the terminal node
        tNode = null
        for node in qgraph.nodes
            if node.isTerminal
                tNode = node
                break
        (matches, emit) ->
            # this is a way to do the traversal of the tree of matches
            # for generating combinations in a continuation-passing-style
            assignSubMatchesAndContinue = (result, matches, node, ret) ->
                assign result, node.step.sourceInQuery,
                    id: matches.v[""]
                    attrs: decodeAttributes matches.v.a
                if node.isInitial
                    ret result
                else
                    continueYieldingSiblings = (result, ret) -> ret result
                    # TODO not sure if this is also correct for return edges
                    incomingEdgeIds = (node.walks_in ? []).concat (node.returns_in ? [])
                    for wId in incomingEdgeIds
                        continueYieldingSiblings = do (wId, matches, continueYieldingSiblings) ->
                            (result, ret) ->
                                w = qgraph.edges[wId]
                                n = qgraph.nodes[w.source]
                                for {p:path, m:subMatches} in matches.w[wId]
                                    for i in [1 .. w.steps.length-2] by 1
                                        m = path[i-1]
                                        assign result, w.steps[i].sourceInQuery,
                                            id: m?[""]
                                            attrs: decodeAttributes m?.a
                                    assignSubMatchesAndContinue result, subMatches, n,
                                        (result) -> continueYieldingSiblings result, ret
                    continueYieldingSiblings result, ret
            assignSubMatchesAndContinue { walks: [] }, matches, tNode, emit

exports.GiraphGraph = GiraphGraph
