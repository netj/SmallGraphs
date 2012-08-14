sqlite = require "sqlite3"
{RelationalDataBaseGraph} = require "../rdbgraph"

class SQLiteGraph extends RelationalDataBaseGraph
    constructor: (@descriptor, args...) ->
        super @descriptor, args...
        d = @descriptor
        unless d.databasePath?
            throw new Error "databasePath is required for the graph descriptor"

    _runSQL: (sql, rowTransformer, q) ->
        try
            # FIXME support absolute path
            db = new sqlite.Database "#{@basepath}/#{@descriptor.databasePath}", sqlite.OPEN_READONLY
            db.all sql, (err, results) ->
                if err
                    console.error "#{new Date()}: SQLite error:", JSON.stringify err
                    q.emit 'error', err
                else
                    console.log "#{new Date()}: SQLite returned #{results.length} results"
                    try
                        q.emit 'result', results.map rowTransformer
                    catch err
                        q.emit 'error', err
                db.close()
            q.abort = (err) ->
                console.log "<< #{new Date()}: aborting request " + (err ? "")
                db.close()
        catch err
            q.emit 'error', err


exports.driver =
exports.SQLiteGraph = SQLiteGraph
