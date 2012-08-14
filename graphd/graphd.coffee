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
coffeekup = require "coffeekup"
path = require "path"
http = require "http"
url = require "url"
fs = require "fs"

smallgraph = require "smallgraph"

failWith = (fail, succ) -> (err, args...) ->
    if err
        fail(err)
    else
        try
            succ(args...)
        catch err2
            fail(err2)

# factory
class GraphManager
    constructor: (@basepath) ->
    load: (graphId, done) ->
        basepath = "#{@basepath}/#{graphId}"
        graphDescriptorPath =  "#{basepath}/graphd.json"
        fs.readFile graphDescriptorPath, failWith done, (json) ->
            graphDescriptor = JSON.parse json
            for driverName, graphMetadata of graphDescriptor
                try
                    {driver:Graph} = require "./#{driverName}/#{driverName}graph"
                catch err
                    return done new Error "#{driverName}: unknown graph type"
                return done null, new Graph graphMetadata, basepath
    graphsById: {}
    get: (graphId, done) ->
        setTimeout =>
            g = @graphsById[graphId]
            load = =>
                @load graphId, failWith done, (g) =>
                    g.loadTimestamp = new Date().getTime()
                    @graphsById[graphId] = g
                    done(null, g)
            return load() unless g?
            fs.stat "#{@basepath}/#{graphId}/graphd.json", failWith done, (stat) ->
                # compare timestamps to see if we need reload
                if g.loadTimestamp > stat.mtime.getTime()
                    done(null, g)
                else
                    load()
        , 0
    list: (done) ->
        find = (path, done) =>
            fs.readdir "#{@basepath}/#{path}", failWith done, (files) =>
                graphs = []
                i = 0
                next = () =>
                    if i == files.length
                        return done(null, graphs)
                    f = files[i++]
                    p = "#{path}#{f}"
                    fs.stat "#{@basepath}/#{p}/graphd.json", failWith next, (stat) =>
                        if stat?.isDirectory()
                            find "#{p}/", failWith done, (moreGraphs) ->
                                graphs.append moreGraphs
                                next()
                        else
                            @get p, failWith next, (g) ->
                                graphs.push g
                                next()
                next()
        find "", done

graphManager = new GraphManager _GraphDirectoryPath

## ExpressJS server
app = express.createServer()

app.configure ->
    app.set "views", "#{__dirname}/views"
    app.set "view engine", "coffee"
    app.register ".coffee", coffeekup.adapters.express
    app.use express.logger()
    app.use express.methodOverride()
    app.use express.bodyParser()
    app.use app.router
    app.use express.static "#{__dirname}/public"

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


# reply to OPTIONS request for cross origin AJAX
app.options "/*", (req, res) ->
    res.writeHead 200,
        "Access-Control-Allow-Methods": "POST, GET, OPTIONS"
        "Access-Control-Allow-Headers": req.headers["access-control-request-headers"]
    res.end()

setupXHRResponse = (res) ->
    res.header "Access-Control-Allow-Origin", "*"


# ## Entrance
# app.all "/", (req, res) ->
#     res.render "start"


## Graphs
# list of graphs
app.all "/", (req, res, next) ->
    graphManager.list failWith next, (graphs) ->
        res.render "listGraphs",
            graphs: graphs

app.param "graphId", (req, res, next, id) ->
    graphManager.get id, (err, g) ->
        if err or not g?
            #res.send 404
            return next(new Error "Graph not found", err)
        req.graph = g
        next()

# schema of graph for SmallGraphs UI
app.all "/g/:graphId/schema", (req, res) ->
    setupXHRResponse res
    res.json req.graph.schema

# process queries sketched from SmallGraphs UI on this graph
app.all "/g/:graphId/query", (req, res, next) ->
    # collect inputs
    if req.is "json"
        query = req.body
        jsonIndent = 0
    else # req.is "application/x-www-form-urlencoded" or ""
        query = smallgraph.parse req.param("q")
        jsonIndent = 2
    limit  = req.headers["smallgraphs-result-limit"]  ? req.param("limit", 100)
    offset = req.headers["smallgraphs-result-offset"] ? req.param("offset",  0)
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

# query UI for graph
app.all "/g/:graphId/*", (req, res, next) ->
    req.url = req.url.replace("/g/#{req.params.graphId}", "/smallgraphs")
    next()

app.all "/g/:graphId", (req, res, next) ->
    res.redirect req.url + "/"


## Queries
app.all "/q/", (req, res) ->
    res.render "listQueries"

app.param "queryId", (req, res, next, id) ->
    getQuery id, (q, err) ->
        if err or not g?
            #res.send 404
            return next(new Error "Query not found", err)
        req.query = q
        next()

app.all "/q/:queryId/", (req, res, next) ->
    next()



app.listen _GraphDPort, ->
    console.log "graphd: running at http://%s:%d/", "localhost" ? app.address().address, app.address().port

