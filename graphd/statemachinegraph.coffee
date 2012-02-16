smallgraph = require "smallgraph"
_ = require "underscore"

{BaseGraph} = require "./basegraph"


class StateMachineGraph extends BaseGraph
    constructor: (@descriptor) ->
        super
        # TODO

    _runQuery: (query, limit, offset, req, res, q) ->
        sm = @constructStateMachine query
        q.emit 'result', sm
        @_runStateMachine sm, limit, offset, req, res, q

    # XXX override this
    # @_runStateMachine should emit 'result' event on q
    _runStateMachine: (statemachine, limit, offset, req, res, q) ->
        q.emit 'error', new Error "_runStateMachine not implemented"

    constructStateMachine: (query) ->
        # preprocess query
        qgraph = @simplifyQuery query
        qgraph = @addReturnEdges qgraph
        console.log qgraph
        # first, assign message IDs
        msgId = 0
        msgIdStart = msgId++
        walks = (w for w in qgraph.edges when w.steps?)
        for w in walks
            w.msgIdArrived  = msgId++
        for w in walks
            w.msgIdReturned = msgId++
        for w in walks
            w.msgIdWalkingBase = msgId
            msgId += w.steps.length-1
        # then, generate actions for each messages
        stateMachine =
            qgraph: qgraph
            messages: []
        addAction = (desc, msgId, actions...) ->
            stateMachine.messages[msgId] =
                msgId: msgId
                description: desc
                action: actions
            msgId
        genConstraints = (s) ->
            if typeof s == 'number'
                qgraph.nodes[s].step
            else
                s
        symNode = "$self"
        symPath = "$path"
        symMatch = "$match"
        symMatchIn = "$match_i"
        #  Start message
        addAction "Start", msgIdStart,
            for w_init in walks when (w_init.source.walks_in ? []).length == 0
                whenNode: symNode
                satisfies: genConstraints w_init.steps[0]
                then:
                    sendMessage: w_init.msgIdWalkingBase + 0
                    to: symNode
                    withPath:
                        newPathWithNode: symNode
                    withMatch:
                        newMatch: null
        # Arrived message
        for w in walks
            s = qgraph.nodes[w.target]
            addAction "Arrived(#{w.id}, #{symMatch})", w.msgIdArrived,
                { rememberMatch: symMatch, ofNode: symNode }
                foreach: symMatchIn
                in:
                    findCompatibleMatchesWithMatch: symMatch
                    ofWalks: s.walks_in # TODO find out more points of join
                do:
                    if not s.walks_out? or s.walks_out.length == 0
                        if not s.returns_out? or s.returns_out.length == 0
                            output: symMatchIn
                        else # s.returns_out.length > 0
                            for r_o in s.returns_out
                                w_i = qgraph.edges[qgraph.edges[r_o].walk]
                                sendMessage: w_i.msgIdReturned
                                to:
                                    nodeInMatch: symMatchIn
                                    ofWalk: w_i.id
                                    atIndex: 0
                                withMatch: symMatchIn
                    else # s.walks_out.length > 0
                        if not s.returns_in? or s.returns_in.length == 0
                            # FIXME there can be multiple walks
                            theWalk = s.walks_out[0]
                            sendMessage: theWalk.msgIdWalkingBase+0
                            to: symNode
                            withPath:
                                newPathWithNode: symNode
                            withMatch: symMatchIn
                        else # s.returns_in.length > 0
                            for r_i in s.returns_in
                                w_o = qgraph.edges[qgraph.edges[r_i].walk]
                                sendMessage: w_o.msgIdWalkingBase+0
                                to: symNode
                                withPath:
                                    newPathWithNode: symNode
                                withMatch: symMatchIn
        # TODO Returned message
        for w in walks
            s = qgraph.nodes[w.source]
            addAction "Returned(#{w.id}, #{symMatch})", w.msgIdReturned,
                [ ]
        # Walking message btwn intermediate steps
        for w in walks
            mId = w.msgIdWalkingBase
            for i in [0 .. w.steps.length-3]
                s = w.steps[i+1]
                symEdge = "$e"
                addAction "Walking(#{w.id}, #{i}, #{symPath}, #{symMatch})", mId,
                    if i % 2 == 1
                        # node step
                        whenNode: symNode
                        satisfies: genConstraints s
                        then:
                            sendMessage: mId+1
                            to: symNode
                            withPath:
                                newPath: symPath
                                augmentedWithNode: symNode
                            withMatch: symMatch
                    else
                        # edge step
                        foreach: symEdge
                        in:
                            outgoingEdgesOf: symNode
                        do:
                            whenEdge: symEdge
                            satisfies: genConstraints s
                            then:
                                sendMessage: mId+1
                                to:
                                    targetNodeOf: symEdge
                                withPath:
                                    newPathAugmentedWithEdge: symEdge
                                withMatch: symMatch
                mId++
            addAction "Walking(#{w.id}, #{w.steps.length-2}, #{symPath}, #{symMatch})", mId,
                whenNode: symNode
                satisfies: genConstraints w.steps[w.steps.length-1]
                then:
                    sendMessage: w.msgIdArrived
                    to: symNode
                    withMatch:
                        newMatch: symMatch
                        joinedWithPath:
                            newPath: symPath
                            augmentedWithNode: symNode
                        forWalk: w.id
        # we're done constructing the state machine
        stateMachine

    # simplifyQuery creates a collapsed query graph by representing longer walks
    # with walk edges between non-intermediate step nodes.
    simplifyQuery: (query) ->
        names = {}
        for decl in query when decl.let?
            [name, cond] = decl.let
            names[name] =
                condition: cond
        # first count occurrences of named steps while indexing walks
        i = 0
        walks = {}
        for decl in query when decl.walk?
            {walk: ss} = decl
            walks[i++] = ss
            for s in ss when s.objectRef?
                env = names[s.objectRef]
                env.occurrence ?= 0
                env.occurrence++
        # eliminate all intermediate named steps and either ends from walks
        for name,env of names when env.occurrence == 2
            walks_in  = (w for w,ss of walks when name == ss[ss.length-1].objectRef)
            walks_out = (w for w,ss of walks when name == ss[0].objectRef)
            if walks_in.length == walks_out.length == 1
                wo = walks[walks_out[0]]
                delete walks[walks_out[0]]
                wi = walks[walks_in[0]]
                wi.push.apply wi, wo
                env.occurrence = 1
        # then, split walks for junction steps
        qnodes = []
        stepNodeCount = 0
        stepNode = (s) ->
            if s.objectRef?
                env = names[s.objectRef]
                unless (nodeId = env.stepNodeId)?
                    nodeId = env.stepNodeId ?= stepNodeCount++
                    qnodes[nodeId] =
                        id: nodeId
                        step: env.condition
                        name: s.objectRef
            else
                nodeId = stepNodeCount++
                qnodes[nodeId] =
                    id: nodeId
                    step: s
            nodeId
        qedges = []
        addEdge = (steps, s = steps[steps.length-1]) ->
            lastStepNode = steps[steps.length-1] = stepNode s
            qedges.push
                id: qedges.length
                source: steps[0]
                target: lastStepNode
                steps: steps
        for w,ss of walks
            steps = []
            for s in ss
                if steps.length == 0
                    steps.push stepNode s
                else if s.objectRef?
                    env = names[s.objectRef]
                    steps.push env.condition
                else
                    steps.push s
                # generate a walk edge if this is a junction step
                if steps.length > 1 and s.objectRef? and names[s.objectRef].occurrence > 1
                    addEdge steps, s
                    steps = [steps[steps.length-1]]
            if steps.length > 1
                addEdge steps
        # index in/out edges of each node
        i = 0
        for e in qedges
            s = qnodes[e.source]
            t = qnodes[e.target]
            (s.walks_out ?= []).push i
            (t.walks_in  ?= []).push i
            e.id = i++
        # finally, here's our simplified query graph
        { nodes: qnodes, edges: qedges }

    # normalizeQuery paves the canonical way by determining the final terminal
    # step, and adding required return edges.
    addReturnEdges: (qgraph) ->
        # how to pick a terminal step
        pickTerminal = (qgraph) ->
            for tn in qgraph.nodes
                if not tn.walks_out? or tn.walks_out.length == 0
                    # TODO pick a better terminal node based on the length of steps of its incoming edge?
                    return tn.id
        terminal = pickTerminal qgraph
        # how to add a return edge
        addReturn = (s, t, w) ->
            ret =
                id: qgraph.edges.length
                source: s
                target: t
                walk: w
            qgraph.edges.push ret
            (qgraph.nodes[s].returns_out ?= []).push ret.id
            (qgraph.nodes[t].returns_in  ?= []).push ret.id
        # Starting from this terminal step node,
        # add a return edge to here from the target node of each outgoing walk
        # except the one that we followed to reach this node.
        # Then, continue visiting source node of each incoming edge, including
        # the newly added return edges. (depth first order is better for
        # tracking the immediate edge we followed)
        visit = (n, outEdgeJustFollowed) ->
            node = qgraph.nodes[n]
            if node.visited then return else node.visited = true
            addReturn qgraph.edges[e].target, n, e  for e in node.walks_out when e != outEdgeJustFollowed if node.walks_out?
            visit qgraph.edges[e].source, e  for e in node.walks_in   if node.walks_in?
            visit qgraph.edges[e].source, e  for e in node.returns_in if node.returns_in?
        visit terminal
        qgraph

exports.StateMachineGraph = StateMachineGraph
