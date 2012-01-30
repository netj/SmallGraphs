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
        q = new EventEmitter
        q.abort = (err) ->
        console.log "#{new Date()}: Query in JSON: >\n#{JSON.stringify query, null, 0}\n< in SmallGraph: >\n#{smallgraph.serialize query}<"
        query = smallgraph.normalize query
        @_runQuery query, limit, offset, req, res, q
        q

    # XXX override this
    # @runQuery should emit 'result' event on q
    _runQuery: (query, limit, offset, req, res, q) ->
        q.emit 'error', new Error "_runQuery not implemented, cannot run #{query}"


exports.BaseGraph = BaseGraph
