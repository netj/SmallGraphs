fs = require "fs"
{spawn} = require "child_process"

{StateMachineGraph} = require "../statemachinegraph"

class GreenMarlGraph extends StateMachineGraph
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
        # TODO generate C++ code from statemachine
        msgHandlerCode = @generateCodeForMessageHandlerCXX statemachine
        fs.writeFileSync "test.cc", msgHandlerCode
        
        #  TODO map types, node/edge URIs in query to long long int IDs
        q.emit 'result', msgHandlerCode; return # FIXME lets construct the correct statemachine for the moment

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
    generateCodeForMessageHandlerCXX: (statemachine) ->
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
                "/* TODO */"
            else if expr.newPathAugmentedWithEdge?
                "/* TODO */"
            else if expr.newPathWithNode?
                "/* TODO */"

            else if expr.findCompatibleMatchesWithMatch?
                # TODO can we expand this?
                "findCompatibleMatchesWithMatch(#{
                    expr.findCompatibleMatchesWithMatch}, #{
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
                "/* XXX: unknown expr: #{JSON.stringify expr} */ NULL"

        codegenAction = (action) ->
            if action instanceof Array
                "{#{(codegenAction a for a in action).join "\n"}}"

            else if action.foreach?
                if action.in == 'object'
                    if action.in.outgoingEdgesOf
                        """
                        // XXX: this is hard to mix C++ and Green-Marl :(
                        Foreach (#{codegenExpr action.foreach} : ) {
                        }
                        """
                    else
                        x = action.foreach
                        xs = "#{x}s" # TODO generate symbols
                        xtype = codegenType action.in
                        """
                        #{xtype} #{xs} = #{codegenExpr action.in}
                        for (#{xtype}::iterator #{x} = #{xs}.begin(); it != #{xs}.end(); #{xs}++) {
                            #{codegenAction action.do}
                        }
                        """

            else if action.sendMessage?
                "// TODO"

            else if action.whenEdge?
                "// TODO"
            else if action.whenNode?
                "// TODO"

            else if action.rememberMatch?
                "// TODO"

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
        void handleMessage(int msgId, Path path, Match match) {
            switch (msgId) {
                #{(codegenCase msg for msg in statemachine.messages).join "\n"}
            }
        }
        """


exports.GreenMarlGraph = GreenMarlGraph
