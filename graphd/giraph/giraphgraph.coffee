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
        # TODO generate Pregel vertex compute code from statemachine
        javaCode = @generateJavaCode statemachine
        javaFile = "SmallGraphGiraphVertex.java"
        fs.writeFileSync javaFile, javaCode
        # indent with Vim
        spawn "screen", [
            "-D"
            "-m"
            "vim"
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
            else if expr.nodeInMatch?
                "LongWritable"
            else if expr.outgoingEdgesOf?
                { list: "LongWritable" }

            else if expr.newPath?
                "MatchPath"
            else if expr.newPathAugmentedWithEdge?
                "MatchPath"
            else if expr.newPathWithNode?
                "MatchPath"

            else if expr.findCompatibleMatchesWithMatch?
                { list: "Match" }
            else if expr.newMatch?
                "Match"

            else
                "/* XXX: unknown expr: #{JSON.stringify expr} */ void"

        codegenNodeExpr = (expr) ->
            if typeof expr == 'string' and expr == '$this'
                "#{codegenExpr expr}.getVertexId()"
            else
                codegenExpr expr

        codegenExpr = (expr) ->
            if typeof expr == 'string'
                if expr.match /^\$/ # symbol
                    expr.replace /^\$/, ""
                else # string literal
                    "\"#{expr.replace /"/g, "\\\""}\""
            else if typeof expr == 'number' # number literal
                expr

            else if expr.targetNodeOf?
                codegenExpr expr.targetNodeOf
            else if expr.nodeInMatch?
                "#{
                    codegenExpr expr.nodeInMatch
                }[#{
                    codegenExpr expr.ofWalk
                }][#{
                    codegenExpr expr.atIndex
                }]"

            else if expr.outgoingEdgesOf?
                codegenExpr expr.outgoingEdgesOf

            else if expr.newPath?
                "new MatchPath(#{
                    if expr.newPath
                        "#{codegenExpr expr.newPath}#{
                            if expr.augmentedWithNode?
                                ", #{codegenNodeExpr expr.augmentedWithNode}"
                                # EdgeListVertex has no ID for edges
                                # else if expr.augmentedWithEdge?
                                #     ", #{codegenExpr expr.augmentedWithEdge}"
                            else
                                ""
                        }"
                })"
            else if expr.newPathWithNode?
                "new MatchPath(#{codegenNodeExpr expr.newPathWithNode})"

            else if expr.findCompatibleMatchesWithMatch?
                # TODO can we expand this?
                "findCompatibleMatchesWithMatch(#{codegenExpr expr.findCompatibleMatchesWithMatch}, #{
                        expr.ofWalks.join ", "})"
            else if expr.newMatch?
                "new Match(#{
                    if expr.newMatch == 0
                        ""
                    else
                        "#{
                        codegenExpr expr.newMatch
                        }, #{
                            codegenExpr expr.forWalk
                        }, #{
                            codegenExpr expr.joinedWithPath
                        }"
                })"

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

            else if action.emitMatch?
                """
                emitMatch(#{codegenExpr action.emitMatch});
                """

            else if action.sendMessage?
                """
                sendMsg(#{codegenNodeExpr action.to}, new Message(#{codegenExpr action.sendMessage}#{
                    if action.withPath? then ", " + codegenExpr action.withPath else ""
                }#{
                    if action.withMatch? then ", " + codegenExpr action.withMatch else ""
                }));
                """

            else if action.whenEdge?
                cond = action.satisfies
                """
                {
                PropertyMap eV = getEdgeValue(#{codegenExpr action.whenEdge});
                if (eV.getType() == #{codegenExpr cond.linkType}) #{codegenConstraints "eV", cond.constraints}
                    #{codegenAction action.then}
                }
                """
            else if action.whenNode?
                cond = action.satisfies
                """
                if (#{codegenExpr action.whenNode}.getType() == #{codegenExpr cond.objectType}) #{codegenConstraints (codegenExpr action.whenNode), cond.constraints}
                    #{codegenAction action.then}
                """

            else if action.rememberMatch?
                """
                #{if action.ofNode != "$this" then "// XXX can't remember match of node: #{action.ofNode}" else ""}
                rememberMatch(#{codegenExpr action.rememberMatch}, #{codegenExpr action.viaWalk});
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
        void handleMessage(int msgId, Path path, Match match) {
            switch (msgId) {
                #{(codegenCase msg for msg in statemachine.messages).join "\n"}
            }
            voteToHalt();
        }
        }
        """


exports.GiraphGraph = GiraphGraph
