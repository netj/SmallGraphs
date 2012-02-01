{EventEmitter} = require "events"
smallgraph = require "smallgraph"


class BaseGraph
    constructor: () ->
        # skeleton schema
        @schema =
            Namespaces:
                xsd: 'http://www.w3.org/2001/XMLSchema'
            Objects: {}
            TypeLabels: {}
        # TODO anything else?

    query: (query, limit, offset, req, res) ->
        # TODO create a class QuerySession extends EventEmitter
        q = new EventEmitter
        q.abort = (err) ->
        console.log "#{new Date()}: Query in JSON: >\n#{JSON.stringify query, null, 0}\n< in SmallGraph: >\n#{smallgraph.serialize query}<"
        query = smallgraph.normalize query
        # FIXME and move this setTimeout to QuerySession#run
        setTimeout (=>
          try
            @_runQuery query, limit, offset, req, res, q
          catch err
            q.emit 'error', err
        ), 0
        # TODO and let the caller use q.run after all the q.on's
        q

    # XXX override this
    # @_runQuery should emit 'result' event on q
    _runQuery: (query, limit, offset, req, res, q) ->
        q.emit 'error', new Error "_runQuery not implemented, cannot run #{query}"


exports.BaseGraph = BaseGraph
