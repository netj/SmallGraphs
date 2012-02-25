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
        q.emit 'result', javaCode; return # FIXME lets construct the correct statemachine for the moment

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
                "Node"
            else if expr.nodeInMatch?
                "Node"
            else if expr.outgoingEdgesOf?
                { list: "Edge" }

            else if expr.newPath?
                "Path"
            else if expr.newPathAugmentedWithEdge?
                "Path"
            else if expr.newPathWithNode?
                "Path"

            else if expr.findCompatibleMatchesWithMatch?
                { list: "Match" }
            else if expr.newMatch?
                "Match"

            else
                "/* XXX: unknown expr: #{JSON.stringify expr} */ void"

        codegenExpr = (expr) ->
            if typeof expr == 'string'
                if expr.match /^\$/ # symbol
                    expr.replace /^\$/, ""
                else # string literal
                    "\"#{expr.replace /"/g, "\\\""}\""
            else if typeof expr == 'number' # number literal
                expr

            else if expr.targetNodeOf?
                "/* TODO */"
            else if expr.nodeInMatch?
                "#{
                    codegenExpr expr.nodeInMatch
                }[#{
                    codegenExpr expr.ofWalk
                }][#{
                    codegenExpr expr.atIndex
                }]"

            else if expr.newPath?
                "new MatchPath(#{
                    if expr.newPath
                        "#{codegenExpr expr.newPath}#{
                            if expr.augmentedWithNode?
                                ", #{codegenExpr expr.augmentedWithNode}"
                            else if expr.augmentedWithEdge?
                                ", #{codegenExpr expr.augmentedWithEdge}"
                        }"
                })"
            else if expr.newPathWithNode?
                "new MatchPath(#{codegenExpr expr.newPathWithNode})"

            else if expr.findCompatibleMatchesWithMatch?
                # TODO can we expand this?
                "findCompatibleMatchesWithMatch(#{codegenExpr expr.findCompatibleMatchesWithMatch}, #{
                        expr.ofWalks.join ", "})"
            else if expr.newMatch?
                "new Match(#{
                    codegenExpr expr.newMatch
                }, #{
                    codegenExpr expr.forWalk
                }, #{
                    codegenExpr expr.joinedWithPath
                })"

            else
                "/* XXX: unknown expr: #{JSON.stringify expr} */ null"

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
                    if action.in.outgoingEdgesOf
                        """
                        // XXX: this is hard to mix C++ and Green-Marl :(
                        for (#{codegenExpr action.foreach} : ) {
                        }
                        """
                    else
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
                sendMsg(#{codegenExpr action.to}, new Message(#{codegenExpr action.sendMessage}#{
                    if action.withPath? then ", " + codegenExpr action.withPath else ""
                }#{
                    if action.withMatch? then ", " + codegenExpr action.withMatch else ""
                }));
                """

            else if action.whenEdge?
                """
                if (getVertexValue().get().type == #{codegenExpr action.satisfies.linkType}))
                    #{
                    if action.satisfies
                        satisfies(#{codegenExpr action.whenEdge}, 
                        )
                    }
                    #{codegenAction action.then}
                """
            else if action.whenNode?
                """
                if (satisfies(#{codegenExpr action.whenNode}, #{codegenExpr action.satisfies.objectType}))
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
