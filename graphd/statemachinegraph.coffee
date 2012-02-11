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
        qgraph = @simplifyQuery query
        return @addReturnEdges qgraph
        # TODO
        names = {}
        for decl in query when decl.let?
            [name, cond] = decl.let
            names[name] =
                condition: cond
        walks = (decl.walk for decl in query when decl.walk?)
        states = {}
        statenum = 0
        genState = ->
            s = states[statenum] =
                number: statenum
                transitions: []
            statenum++
            s
        initState = genState()
        for walk in walks
            prevState = initState
            for stepCondition in walk
                if stepCondition.objectRef?
                    namedStep = names[stepCondition.objectRef]
                    state = namedStep.state ?= genState()
                    stepCondition = namedStep.condition
                else
                    state = genState()
                prevState.transitions.push [stepCondition, state.number]
                prevState = state

    # simplifyQuery creates a simplified graph of the query by representing it
    # with only walk edges and non-intermediate step nodes.
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
