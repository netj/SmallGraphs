smallgraph = require "smallgraph"
_ = require "underscore"

{BaseGraph} = require "./basegraph"


class StateMachineGraph extends BaseGraph
    constructor: (@descriptor, @basepath) ->
        super @basepath

    _runQuery: (query, limit, offset, req, res, q) ->
        sm = @constructStateMachine query
        # FIXME for debug+development, REMOVEME
        fs = require "fs"
        child = require "child_process"
        fs.writeFileSync "test.sgm", JSON.stringify sm, null, 2
        #console.log "test.sgm"
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
                e.msgIdWalkingBase = msgId
                msgId += (e.steps.length-1)/2 - 1
                e.msgIdArrived = msgId++
            else if e.walk?
                returns.push e
                w = qgraph.edges[e.walk]
                e.msgIdReturned = w.msgIdReturned = msgId++
        # mark initial and terminal nodes
        for s in qgraph.nodes
            if not s.walks_in?.length
                s.isInitial = true
            if not s.walks_out?.length and not s.returns_out?.length
                s.isTerminal = true
        # find converging paths
        pathsBySource = (targetNode) ->
            paths = {}
            traverseBackwards = (nodeId, path) ->
                (paths[nodeId] ?= []).push path
                # avoid generating every combination of paths and infinite loops with cycles
                if paths[nodeId].length == 1
                    node = qgraph.nodes[nodeId]
                    traverseBackwards qgraph.edges[wId].source, (path.concat [wId])  for wId in node.walks_in  if node.walks_in?
            traverseBackwards targetNode.id, []
            paths
        for t in qgraph.nodes when not t.isInitial
            pathset = pathsBySource t
            # mark joining paths (more than two) only when prefixes differ
            for s,paths of pathset
                if paths.length == 1 or (paths.every (p) -> paths[0][0] == p[0])
                    delete pathset[s]
            t.joiningPaths = pathset unless _.isEmpty pathset
        # then, generate actions for each messages
        stateMachine =
            qgraph: qgraph
            messages: []
        addAction = (pass, msgId, desc, actions...) ->
            (stateMachine.messages[pass] ?= [])[msgId] =
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
        symNode2 = "$node"
        symEdge = "$e"
        symPath = "$path"
        symPath2 = "$path2"
        symMatches = "$matches"
        actionForWalkingOnEdge = (w, i=0, node=symNode, path=0, matches=symMatches) ->
            # edge step
            foreach: symEdge
            in:
                outgoingEdgesOf: node
            do:
                whenEdge: symEdge
                satisfies: genConstraints w.steps[2*i+1]
                then:
                    sendMessage: w.msgIdWalkingBase + i
                    to:
                        targetNodeOf: symEdge
                    withPath:
                        # TODO collect attribute values
                        newPath: path
                        augmentedWithEdge: symEdge
                    withMatches: matches
        #  Start message
        addAction 1, msgIdStart, "Start",
            for s in qgraph.nodes when s.isInitial
                null # XXX don't remove this line, or you'll break CoffeeScript's parser
                # TODO group initial nodes with same constraints
                whenNode: symNode
                satisfies: genConstraints s.step
                then:
                    for w_initId in s.walks_out
                        w_init = qgraph.edges[w_initId]
                        # TODO unless it has a corresponding return edge
                        actionForWalkingOnEdge w_init, 0, symNode, 0, { newMatchesAtNode: symNode }
        # TODO optimize out unnecessary foreach CompatibleMatchesWithMatches
        # Arrived messages
        symMatchesIn = "$matches_i"
        for w in walks
            # TODO merge the same arrived messages for each walk to the same step node
            s = qgraph.nodes[w.target]
            addAction 0, w.msgIdArrived, "Arrived(#{w.id}, #{symPath}, #{symMatches})",
                whenNode: symNode
                satisfies: genConstraints w.steps[w.steps.length-1]
                then:
                    { rememberMatches: symMatches, ofNode: symNode, viaWalk: w.id, withPath: symPath }
            addAction 1, w.msgIdArrived, "Arrived(#{w.id}, #{symPath}, #{symMatches})",
                whenNode: symNode
                satisfies: genConstraints w.steps[w.steps.length-1]
                then:
                    foreach: symMatchesIn
                    in:
                        findAllConsistentMatches: s.joiningPaths ? 0
                        ofWalks: s.walks_in
                    do: _.flatten [
                        if s.returns_in?.length
                            # initiate walks that we expect to return
                            for r_iId in s.returns_in
                                w_o = qgraph.edges[qgraph.edges[r_iId].walk]
                                actionForWalkingOnEdge w_o, 0, symNode, 0, symMatchesIn
                        else # no incoming return edges
                            if s.isTerminal # we can emit since no Returned message is expected
                                emitMatches: symMatchesIn
                            else if s.walks_out?.length # initiate outgoing walks
                                for w_oId in s.walks_out
                                    w_o = qgraph.edges[w_oId]
                                    actionForWalkingOnEdge w_o, 0, symNode, 0, symMatchesIn
                            else # or, initiate Returned messages if no outgoing walks
                                for r_oId in s.returns_out ? []
                                    w_i = qgraph.edges[qgraph.edges[r_oId].walk]
                                    foreach: symNode2
                                    in:
                                        nodesBeforeWalk: w_i.id
                                        inMatches: symMatchesIn
                                    do:
                                        sendMessage: w_i.msgIdReturned
                                        to: symNode2
                                        withMatches: symMatchesIn
                    ]
        # Returned messages
        symMatchesInRet = "$matches_ir"
        for r in returns
            w = qgraph.edges[r.walk]
            s = qgraph.nodes[w.source]
            walks_out_with_returns = (qgraph.edges[r].walk for r in s.returns_in)
            addAction 0, w.msgIdReturned, "Returned(#{w.id}, #{symMatches})",
                { rememberMatches: symMatches, ofNode: symNode, returnedFromWalk: w.id }
            addAction 1, w.msgIdReturned, "Returned(#{w.id}, #{symMatches})",
                foreach: symMatchesInRet
                in:
                    findAllConsistentMatches: s.joiningPaths ? 0
                    ofWalks: _.union s.walks_in ? [], walks_out_with_returns
                do:
                    if s.isTerminal # we can emit once we get back all the Returned matches
                        emitMatches: symMatchesInRet
                    else _.flatten [
                        for r_oId in s.returns_out ? []
                            w_i = qgraph.edges[qgraph.edges[r_oId].walk]
                            foreach: symNode2
                            in:
                                nodesBeforeWalk: w_i.id
                                inMatches: symMatchesInRet
                            do:
                                sendMessage: w_i.msgIdReturned
                                to: symNode2
                                withMatches: symMatchesInRet
                        for w_oId in _.difference s.walks_out ? [], walks_out_with_returns
                            w_o = qgraph.edges[w_oId]
                            actionForWalkingOnEdge w_o, 0, symNode, 0, symMatchesInRet
                    ]
        # Walking message btwn intermediate steps
        for w in walks
            numEdges = (parseInt (w.steps.length-1))/2
            for i in [1 ... numEdges] by 1
                addAction 1, w.msgIdWalkingBase + i-1, "Walking(#{w.id}, #{2*i}, #{symPath}, #{symMatches})",
                    # node step
                    whenNode: symNode
                    satisfies: genConstraints w.steps[2*i]
                    then:
                        let: symPath2
                        be:
                            # TODO collect attribute values
                            newPath: symPath
                            augmentedWithNode: symNode
                        in: actionForWalkingOnEdge w, i, symNode, symPath2, symMatches
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
            qgraph.edges[wId].return = r.id
            qgraph.edges.push r
            (qgraph.nodes[sId].returns_out ?= []).push r.id
            (qgraph.nodes[tId].returns_in  ?= []).push r.id
        # First, mark step nodes on the canonical way
        nodesToVisit = [terminalId]
        while nodesToVisit.length > 0
            nodeId = nodesToVisit.shift()
            n = qgraph.nodes[nodeId]
            n.isCanonical = true
            nodesToVisit.push qgraph.edges[eId].source for eId in n.walks_in if n.walks_in?
        # Then, start visiting from this terminal step node in a breadth first manner,
        # add return edge to current node from the target node of each outgoing
        # walk which has not been visited yet.
        # Then, continue visiting source node of each incoming edge, including
        # the newly added return edges.
        needsReturn = (eId) ->
            t = qgraph.nodes[qgraph.edges[eId].target]
            not t.visited and # target node shouldn't be visited yet
                not t.isCanonical and # nodes on the canonical need no return to other nodes
                not t.returns_out?.length > 0 # and no redundant returns XXX is it true that only a single return is necessary for all cases?
        nodesToVisit = [terminalId]
        while nodesToVisit.length > 0
            nodeId = nodesToVisit.shift()
            n = qgraph.nodes[nodeId]
            if n.visited then continue else n.visited = true
            addReturn qgraph.edges[eId].target, nodeId, eId  for eId in n.walks_out when needsReturn eId  if n.walks_out?
            nodesToVisit.push qgraph.edges[eId].source       for eId in n.walks_in                        if n.walks_in?
            nodesToVisit.push qgraph.edges[eId].source       for eId in n.returns_in                      if n.returns_in?
        # TODO add return edges among disconnected components
        qgraph

exports.StateMachineGraph = StateMachineGraph
