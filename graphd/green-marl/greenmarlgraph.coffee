{spawn} = require 'child_process'

{BaseGraph} = require "../basegraph"

class GreenMarlGraph extends BaseGraph
    constructor: (@descriptor) ->
        super
        d = @descriptor
        unless d.graphPath?
            throw new Error "graphPath, ... are required for the graph descriptor"
        # TODO populate schema from descriptor
        @schema.Objects = d.Objects

    _runQuery: (query, limit, offset, req, res, q) ->
        # TODO generate C++ code from query
        #  TODO map types, node/edge URIs in query to long long int IDs

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


exports.GreenMarlGraph = GreenMarlGraph
