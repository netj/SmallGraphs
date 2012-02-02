smallgraph = require "smallgraph"

{BaseGraph} = require "./basegraph"


class StateMachineGraph extends BaseGraph
    constructor: (@descriptor) ->
        super
        # TODO

    _runQuery: (query, limit, offset, req, res, q) ->
        sm = @constructStateMachine query
        @_runStateMachine sm, limit, offset, req, res, q

    # XXX override this
    # @_runStateMachine should emit 'result' event on q
    _runStateMachine: (statemachine, limit, offset, req, res, q) ->
        q.emit 'error', new Error "_runStateMachine not implemented"

    constructStateMachine: (query) ->
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


exports.StateMachineGraph = StateMachineGraph
