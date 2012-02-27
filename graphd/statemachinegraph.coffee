smallgraph = require "smallgraph"
_ = require "underscore"

{BaseGraph} = require "./basegraph"


class StateMachineGraph extends BaseGraph
    constructor: (@descriptor) ->
        super

    _runQuery: (query, limit, offset, req, res, q) ->
        sm = @constructStateMachine query
        # FIXME for debug+development, REMOVEME
        fs = require "fs"
        child = require "child_process"
        fs.writeFileSync "test.sgm", JSON.stringify sm, null, 2
        console.log "test.sgm"
        child.spawn "./test-view-sgm.sh", ["test.sgm"]
        # FIXME end of debug
        @_runStateMachine sm, limit, offset, req, res, q

    # XXX override this
    # @_runStateMachine should emit 'result' event on q
    _runStateMachine: (statemachine, limit, offset, req, res, q) ->
        q.emit 'error', new Error "_runStateMachine not implemented"

    constructStateMachine: (query) ->
        # preprocess query
        qgraph = @simplifyQuery query
        qgraph = @addReturnEdges qgraph
        # first, assign message IDs
        msgId = 0
        msgIdStart = msgId++
        walks = []
        returns = []
        for e in qgraph.edges
            if e.steps?
                walks.push e
                e.msgIdArrived = msgId++
            else if e.walk?
                returns.push e
                w = qgraph.edges[e.walk]
                e.msgIdReturned = w.msgIdReturned = msgId++
        for w in walks
            w.msgIdWalkingBase = msgId
            msgId += w.steps.length-1
        # mark initial and terminal nodes
        for s in qgraph.nodes
            if not s.walks_in?.length
                s.isInitial = true
            if not s.walks_out?.length and not s.returns_out?.length
                s.isTerminal = true
        # then, generate actions for each messages
        # TODO reduce number of messages sent to self node
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
        symNode = "$this"
        symPath = "$path"
        symMatch = "$match"
        #  Start message
        addAction "Start", msgIdStart,
            for s in qgraph.nodes when s.isInitial
                null # XXX don't remove this line, or you'll break CoffeeScript's parser
                # TODO group initial nodes with same constraints
                whenNode: symNode
                satisfies: genConstraints s.step
                then:
                    for w_initId in s.walks_out
                        w_init = qgraph.edges[w_initId]
                        sendMessage: w_init.msgIdWalkingBase
                        to: symNode
                        withPath:
                            newPathWithNode: symNode
                        withMatch:
                            newMatch: 0
        # TODO optimize out unnecessary foreach findCompatibleMatchesWithMatch
        # Arrived messages
        symMatchIn = "$match_i"
        for w in walks
            s = qgraph.nodes[w.target]
            addAction "Arrived(#{w.id}, #{symMatch})", w.msgIdArrived,
                { rememberMatch: symMatch, ofNode: symNode, viaWalk: w.id }
                foreach: symMatchIn
                in:
                    findCompatibleMatchesWithMatch: symMatch
                    ofWalks: s.walks_in # TODO find out more points of join
                do: _.flatten [
                    if s.returns_in?.length
                        # initiate walks that need we expect to return
                        for r_iId in s.returns_in
                            w_o = qgraph.edges[qgraph.edges[r_iId].walk]
                            sendMessage: w_o.msgIdWalkingBase
                            to: symNode
                            withPath:
                                newPathWithNode: symNode
                            withMatch: symMatchIn
                    else # no incoming return edges
                        if s.isTerminal # we can emit since no Returned message is expected
                            emitMatch: symMatchIn
                        else if s.walks_out?.length # initiate outgoing walks
                            for w_oId in s.walks_out
                                w_o = qgraph.edges[w_oId]
                                sendMessage: w_o.msgIdWalkingBase
                                to: symNode
                                withPath:
                                    newPathWithNode: symNode
                                withMatch: symMatchIn
                        else # or, initiate Returned messages if no outgoing walks
                            for r_oId in s.returns_out ? []
                                w_i = qgraph.edges[qgraph.edges[r_oId].walk]
                                sendMessage: w_i.msgIdReturned
                                to:
                                    nodeInMatch: symMatchIn
                                    ofWalk: w_i.id
                                    atIndex: 0
                                withMatch: symMatchIn
                ]
        # Returned messages
        symMatchInRet = "$match_ir"
        for r in returns
            w = qgraph.edges[r.walk]
            s = qgraph.nodes[w.source]
            walks_out_with_returns = (qgraph.edges[r].walk for r in s.returns_in)
            addAction "Returned(#{w.id}, #{symMatch})", w.msgIdReturned,
                { rememberMatch: symMatch, ofNode: symNode, viaWalk: w.id }
                foreach: symMatchInRet
                in:
                    findCompatibleMatchesWithMatch: symMatch
                    ofWalks: _.union s.walks_in ? [], walks_out_with_returns # TODO find out more points of join
                do:
                    if s.isTerminal # we can emit once we get back all the Returned matches
                        emitMatch: symMatchInRet
                    else _.flatten [
                        for r_oId in s.returns_out ? []
                            w_i = qgraph.edges[qgraph.edges[r_oId].walk]
                            sendMessage: w_i.msgIdReturned
                            to:
                                nodeInMatch: symMatchInRet
                                ofWalk: w_i.id
                                atIndex: 0
                            withMatch: symMatchInRet
                        for w_oId in _.difference s.walks_out ? [], walks_out_with_returns
                            w_o = qgraph.edges[w_oId]
                            sendMessage: w_o.msgIdWalkingBase
                            to: symNode
                            withPath:
                                newPathWithNode: symNode
                            withMatch: symMatchInRet
                    ]
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
                                    newPath: symPath
                                    augmentedWithEdge: symEdge
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
        pickTerminalId = (qgraph) ->
            for tn in qgraph.nodes
                if not tn.walks_out? or tn.walks_out.length == 0
                    # TODO pick a better terminal node based on the length of steps of its incoming edge?
                    return tn.id
        terminalId = pickTerminalId qgraph
        # how to add a return edge
        addReturn = (sId, tId, wId) ->
            r =
                id: qgraph.edges.length
                source: sId
                target: tId
                walk: wId
            qgraph.edges.push r
            (qgraph.nodes[sId].returns_out ?= []).push r.id
            (qgraph.nodes[tId].returns_in  ?= []).push r.id
        # Start visiting from this terminal step node in a breadth first manner,
        # add return edge to current node from the target node of each outgoing
        # walk which has not been visited yet.
        # Then, continue visiting source node of each incoming edge, including
        # the newly added return edges.
        nodesToVisit = [terminalId]
        while nodesToVisit.length > 0
            nodeId = nodesToVisit.shift()
            n = qgraph.nodes[nodeId]
            if n.visited then continue else n.visited = true
            addReturn qgraph.edges[eId].target, nodeId, eId  for eId in n.walks_out when not qgraph.nodes[qgraph.edges[eId].target].visited  if n.walks_out?
            nodesToVisit.push qgraph.edges[eId].source       for eId in n.walks_in                                                           if n.walks_in?
            nodesToVisit.push qgraph.edges[eId].source       for eId in n.returns_in                                                         if n.returns_in?
        # TODO add return edges among disconnected components
        qgraph

exports.StateMachineGraph = StateMachineGraph
