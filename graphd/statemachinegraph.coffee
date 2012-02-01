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
        walks = (decl.walk for decl in query when decl.walk?)
        console.log walks.length
        walks


exports.StateMachineGraph = StateMachineGraph
