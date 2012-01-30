# configure some knobs
_GraphDPort = 53411
_GraphDirectoryPath = "graphs"


{_} = require "underscore"
http = require "http"
url = require "url"
fs = require "fs"

smallgraph = require "smallgraph"

# factory method
{MySQLGraph} = require "./mysqlgraph"
{GreenMarlGraph} = require "./green-marl/greenmarlgraph"
loadGraph = (graphId) ->
    path = "#{_GraphDirectoryPath}/#{graphId}/graphd.json"
    graphDescriptor = JSON.parse fs.readFileSync path
    if graphDescriptor.mysql
        return new MySQLGraph graphDescriptor.mysql
    else if graphDescriptor.greenmarl
        return new GreenMarlGraph graphDescriptor.greenmarl
    else
        throw new Error "unknown graph type"


graphsById = {}
getGraph = (graphId) ->
    g = graphsById[graphId]
    unless g? # TODO compare timestamps for refreshing
        graphsById[graphId] = g = loadGraph graphId
    return g

http.createServer (req,res) ->
        sendHeaders = (code, hdrs) ->
            res.writeHead code,
                _.extend {
                    "Access-Control-Allow-Origin": "*"
                    "Content-Type": "text/plain" # "application/json"
                }, hdrs
        sendError = (err) ->
            sendHeaders 500,
                "Content-Type": "application/json"
            res.end (JSON.stringify err)
        try
            console.log ">> #{new Date()}: handling #{req.method} request for #{req.url} from #{req.socket.remoteAddress+":"+req.socket.remotePort}"
            # reply to OPTIONS request for cross origin AJAX
            switch req.method
                when 'OPTIONS'
                    sendHeaders 200,
                        "Access-Control-Allow-Methods": "POST, GET, OPTIONS"
                        "Access-Control-Allow-Headers": req.headers["access-control-request-headers"]
                    res.end()
                    return
            # prepare the graph we'll be working on by parsing the URL
            parsedURL = url.parse req.url, true
            [__, graphId, command] = parsedURL.pathname.match(/^\/(.*)\/(schema|query)$/)
            # TODO sanitize graphId (../, ...)
            try
                g = getGraph graphId
            catch err
                console.log "Cannot get graph '#{graphId}': " + err
            unless g?
                sendHeaders 404
                res.end "Graph not available"
                return
            console.log ">>> #{command} for graph '#{graphId}'"
            switch command
                when 'schema' # /#{graphname}/schema GET
                    # send schema of this graph for SmallGraphs UI
                    sendHeaders 200
                    res.end JSON.stringify g.schema
                    return
                when 'query' # /#{graphname}/query {POST,GET,OPTIONS}
                    # process queries sketched from SmallGraphs UI on this graph
                    sendResultOf = (queried, jsonIndent = 0) ->
                        # send garbage back to keep the connection from dropping (WebKit drops it after 2 min)
                        sendHeaders 200 # XXX can't we defer sending headers while keeping the connection alive?
                        keepAlive = -> res.write " "
                        keepAliveInterval = setInterval keepAlive, 10000
                        queried.on 'result', (result) ->
                                clearInterval keepAliveInterval
                                # XXX console.log (JSON.stringify result)
                                res.end JSON.stringify result, null, jsonIndent
                        queried.on 'error', (err) ->
                            clearInterval keepAliveInterval
                            sendError err
                        req.once "close", queried.abort
                        req.once "error", queried.abort
                        res.once "error", queried.abort
                        return
                    switch req.method
                        when 'POST'
                            limit  = req.headers["smallgraphs-result-limit"] ? 100
                            offset = req.headers["smallgraphs-result-offset"] ? 0
                            rawQuery = ""
                            req.on 'data', (chunk) ->
                                rawQuery += chunk
                            req.on 'end', ->
                                query = JSON.parse rawQuery
                                sendResultOf g.query query, limit, offset
                            return
                        when 'GET'
                            queryString = parsedURL.query
                            {q,limit,offset} = queryString
                            q ?= ""
                            limit  ?= 100
                            offset ?= 0
                            query = smallgraph.parse q
                            sendResultOf (g.query query, limit, offset), 2
                            return
            # if this point is reached, request was not handled, so error should be returned
            sendHeaders 400,
                "Content-Type": "text/plain"
            res.end "Unknown command: #{command}"
        catch err
            console.error "<< #{new Date()}: Error:", JSON.stringify err
            sendError err

    .listen _GraphDPort

console.log "#{new Date()}: graphd running on port #{_GraphDPort}"
