smallgraphParser = require "../smallgraph/syntax"
http = require "http"
url = require "url"
fs = require "fs"

graphDescriptor = JSON.parse (fs.readFileSync "mysqlgraph.json")

mysqlGraph = graphDescriptor.mysql
mysql = require "mysql"

compileSmallGraphQueryToSQL = (query) ->
    "SELECT COUNT(*) FROM user"

processQuery = (query, res) ->
    console.log query
    sql = compileSmallGraphQueryToSQL query
    console.log sql

    try
        client = mysql.createClient
            user:       mysqlGraph.user
            password:   mysqlGraph.password
            host:       mysqlGraph.host
            port:       mysqlGraph.port
        client.query 'USE '+mysqlGraph.database
        client.query sql,
            (err, results, fields) ->
                console.log results
                if err
                    res.writeHead 500,
                        "Content-Type": "text/plain" # "application/json"
                    res.end (JSON.stringify err)
                else
                    res.writeHead 200,
                        "Content-Type": "text/plain" # "application/json"
                    res.end (JSON.stringify results)
                client.end()
    catch err
        res.writeHead 500,
            "Content-Type": "text/plain" # "application/json"
        res.end (JSON.stringify err)


http.createServer (req,res) ->
        console.log ">> handling request from #{req.socket.remoteAddress+":"+req.socket.remotePort}"
        switch req.method
            when 'POST'
                rawQuery = ""
                req.on 'data', (chunk) ->
                    rawQuery += chunk
                req.on 'end', ->
                    console.log "rawQuery", rawQuery
                    query = JSON.parse rawQuery
                    processQuery query, res
            else
                {q} = (url.parse req.url, true).query
                q ?= ""
                query = smallgraphParser.parse q
                processQuery query, res

    .listen 53411

console.log "graphd running for", mysqlGraph
