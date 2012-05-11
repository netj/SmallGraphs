# GraphD -- a property graph management system
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-05-09

# default values for some configuration variables
_GraphDPort = 53411
_GraphDirectoryPath = process.cwd() # __dirname + "/graphs"

# process arguments
argv = process.argv
if argv.length > 2
    _GraphDPort = argv[2]


{_} = require "underscore"
express = require "express"
path = require "path"
http = require "http"
url = require "url"
fs = require "fs"

smallgraph = require "smallgraph"

# factory method
{MySQLGraph} = require "./mysql/mysqlgraph"
{GiraphGraph} = require "./giraph/giraphgraph"
loadGraph = (graphId) ->
    graphdPath = "#{_GraphDirectoryPath}/#{graphId}/graphd.json"
    basepath = path.dirname graphdPath
    graphDescriptor = JSON.parse fs.readFileSync graphdPath
    if graphDescriptor.mysql?
        return new MySQLGraph graphDescriptor.mysql, basepath
    else if graphDescriptor.giraph?
        return new GiraphGraph graphDescriptor.giraph, basepath
    else
        throw new Error "unknown graph type"

graphsById = {}
getGraph = (graphId, next) ->
    setTimeout ->
        try
            g = graphsById[graphId]
            unless g? # TODO compare timestamps for refreshing
                graphsById[graphId] = g = loadGraph graphId
            next(g)
        catch err
            next(null, err)
    , 0


app = express.createServer()

app.configure ->
    app.use express.logger()
    app.use express.methodOverride()
    app.use express.bodyParser()
    app.use app.router

app.configure "development", ->
    #app.use express.static(__dirname + "/public")
    #app.error (err, req, res, next) ->
    #    console.log err
    #    switch err.code
    #        when "ENOENT"
    #            res.render "404.jade"
    #        else
    #            next(err)
    app.use express.errorHandler( dumpExceptions: true, showStack: true )

app.configure "production", ->
    #oneYear = 31557600000
    #app.use express.static(__dirname + "/public", { maxAge: oneYear })
    app.use express.errorHandler()

app.param "graphId", (req, res, next, id) ->
    getGraph id, (g, err) ->
        if err or not g?
            #res.send 404
            return next(new Error "Graph not found", err)
        req.graph = g
        next()

setupXHRResponse = (res) ->
    res.header "Access-Control-Allow-Origin", "*"

# reply to OPTIONS request for cross origin AJAX
app.options "/*", (req, res) ->
    res.writeHead 200,
        "Access-Control-Allow-Methods": "POST, GET, OPTIONS"
        "Access-Control-Allow-Headers": req.headers["access-control-request-headers"]
    res.end()

# schema of graph for SmallGraphs UI
app.all "/:graphId/schema", (req, res) ->
    setupXHRResponse res
    res.json req.graph.schema

# process queries sketched from SmallGraphs UI on this graph
app.all "/:graphId/query", (req, res, next) ->
    # collect inputs
    if req.is "json"
        query = req.body
        jsonIndent = 0
    else # req.is "application/x-www-form-urlencoded" or ""
        query = smallgraph.parse req.param("q")
        jsonIndent = 2
    limit  = req.param("SmallGraphs-Result-Limit", 100)
    offset = req.param("SmallGraphs-Result-Offset", 0)
    # run query and send results
    queried = req.graph.query query, limit, offset
    queried.on "result", (result) ->
        #clearInterval keepAliveInterval
        setupXHRResponse res
        res.contentType "application/json"
        res.send JSON.stringify result, null, jsonIndent
    queried.on "error", (err) ->
        #clearInterval keepAliveInterval
        next(err)
    req.once "close", queried.abort
    req.once "error", queried.abort
    res.once "error", queried.abort
    # send garbage back to keep the connection from dropping (WebKit drops it after 2 min)
    #res.writeHead 200 # XXX can't we defer sending headers while keeping the connection alive?
    #keepAlive = -> res.write " "
    #keepAliveInterval = setInterval keepAlive, 10000


app.listen _GraphDPort, ->
    console.log "graphd: running at http://%s:%d/", app.address().address, app.address().port

