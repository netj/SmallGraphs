_MySQL = require "mysql"
{RelationalDataBaseGraph} = require "./rdbgraph"

class MySQLGraph extends RelationalDataBaseGraph
    constructor: (@descriptor) ->
        super @descriptor
        d = @descriptor
        unless d.host? and d.port? and d.user? and d.password? and d.database?
            throw new Error "host, port, user, password, database are required for the graph descriptor"

    runSQL: (sql, rowTransformer, q) ->
        # then send it to MySQL and transform the result
        client = _MySQL.createClient
            user:     @descriptor.user
            password: @descriptor.password
            host:     @descriptor.host
            port:     @descriptor.port
        client.useDatabase @descriptor.database
        client.query sql, (err, results, fields) ->
            if err
                console.error "#{new Date()}: MySQL error:", JSON.stringify err
                q.emit 'error', err
            else
                console.log "#{new Date()}: MySQL returned #{results.length} results"
                try
                    q.emit 'result', results.map rowTransformer
                catch err
                    q.emit 'error', err
            client.end()
        q.abort = (err) ->
            console.log "<< #{new Date()}: aborting request " + (err ? "")
            client.end()
            client.destroy()
        client.once 'error', (err) ->
            q.abort err
            q.emit 'error', err
        q


exports.MySQLGraph = MySQLGraph
