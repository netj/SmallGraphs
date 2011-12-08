smallgraphParser = require "../smallgraph/syntax"
http = require "http"
url = require "url"
fs = require "fs"

graphDescriptor = JSON.parse (fs.readFileSync "mysqlgraph.json")

mysqlGraph = graphDescriptor.mysql
mysql = require "mysql"

normalizeSmallGraphQuery = (query) ->
    query # TODO

compileSmallGraphQueryToSQL = (query) ->
    objects = mysqlGraph.layout.objects
    walkNum = 0
    env = {}
    junctions = []
    rememberJunction = (name, step) ->
        junctions[name] ?= []
        junctions[name].push step
    mergeObject = ->
        o = {}
        for oo in arguments
            for k,v of oo
                o[k] = v
        o
    sqlSanitizeName = (n) ->
        if n then n.replace /[^A-Za-z_0-9]/g, "_"
    sqlName = ->
        "_#{(sqlSanitizeName name for name in arguments).join "_"}_"
    sqlField = ([tableName, field, alias]) ->
        "#{tableName}.#{field} as #{alias}"
    sqlTable = ([table, alias]) ->
        "#{table} as #{alias}"
    sqlNameRef = (e) ->
        if typeof e == 'string'
            e
        else
            "#{e[0]}.#{e[1]}"
    sqlCond = ([left, rel, right]) ->
        "#{sqlNameRef left} #{rel} #{sqlNameRef right}"
    walkSQLs = []
    for decl in query
        if decl.let? # update env from let decl
            [name, step] = decl.let
            env[name] = step
        if decl.walk? # process walk
            {walk} = decl
            fields = []
            tables = []
            conditions = []
            i = 0
            addSQLNames = (walkNum, i, o) ->
                tag = "#{walkNum}_#{i}"
                o.sqlTableName = sqlName tag, o.type
                o.sqlIdName    = sqlName tag, o.type, "id"
                o.sqlId        = [o.sqlTableName, "id"]
                if o.step.objectRef? or o.step.alias?
                    rememberJunction (o.step.objectRef ? o.step.alias), o
                o
            objectStep = (i) ->
                st = walk[i]
                if st.objectRef?
                    st = mergeObject env[st.objectRef], st
                if st.alias?
                    env[st.alias] = st
                ty = st.objectType
                addSQLNames walkNum, i,
                    step: st
                    type: ty
                    layout: objects[ty]
            linkStep = (s, i) ->
                st = walk[i]
                if st.linkRef?
                    st = mergeObject env[st.linkRef], st
                if st.alias?
                    env[st.alias] = st
                ty = st.linkType
                addSQLNames walkNum, i,
                    step: st
                    type: ty
                    layout: s.layout.links[ty]
            s = objectStep i++
            tables.push [s.layout.id.table, s.sqlTableName]
            fields.push [s.sqlTableName, s.layout.id.field, s.sqlIdName]
            # TODO add label field and attribute fields
            while i < walk.length
                l = linkStep s, i++
                t = objectStep i++
                console.assert l.layout.to == t.type,
                    "invalid walk step: #{s.type} -#{l.type}-> #{t.type}"
                # add conditions for joining source and target based on link's layout
                if !l.layout.table || l.layout.table == s.layout.id.table
                    # link's layout specifies the field on the source object's table
                    conditions.push [[s.sqlTableName, l.layout.field], '=', t.sqlId]
                else if l.layout.table == t.layout.id.table
                    # or a field on the target table, so we still don't need any additional join
                    conditions.push [s.sqlId, '=', [t.sqlTableName, l.layout.joinOn]]
                else
                    # otherwise, we need to consult another table that defines the link between source and target
                    tables.push [l.layout.table, l.sqlTableName]
                    conditions.push [s.sqlId, '=', [l.sqlTableName, l.layout.joinOn]]
                    conditions.push [[l.sqlTableName, l.layout.field], '=', t.sqlId]
                # add target object's fields and table
                tables.push [t.layout.id.table, t.sqlTableName]
                fields.push [t.sqlTableName, t.layout.id.field, t.sqlIdName]
                # TODO add label field and attribute fields
                s = t
            walkSQLs.push """
                SELECT #{fields.map(sqlField).join ",\n       "}
                FROM #{tables.map(sqlTable).join ",\n     "}
                WHERE #{conditions.map(sqlCond).join "\n  AND "}
                """
            walkNum++
    if walkSQLs.length > 1
        # hyperwalk: join walks on coinciding nodes
        junctionConditions = []
        for name,steps of junctions
            if steps.length > 1
                i = 0
                lastStep = steps[i++]
                while i < steps.length
                    st = steps[i++]
                    junctionConditions.push [lastStep.sqlIdName, '=', st.sqlIdName]
                    lastStep = st
        console.log junctionConditions
        """
        SELECT * FROM
        #{
            walkNum = 0
            ("(#{w.replace /\n/g, "$& "}) AS walk_#{walkNum++}" for w in walkSQLs).join ",\n"
        }
        WHERE #{junctionConditions.map(sqlCond).join "\n  AND "}
        """
    else
        walkSQLs[0]

processQuery = (query, res) ->
    console.log ">>> SmallGraph Query:", JSON.stringify query
    queryNorm = normalizeSmallGraphQuery query
    sql = compileSmallGraphQueryToSQL queryNorm
    console.log ">>> Compiled SQL:", sql

    sql += " LIMIT 100 OFFSET 2" # TODO parameterize limit and offset

    try
        client = mysql.createClient
            user:       mysqlGraph.user
            password:   mysqlGraph.password
            host:       mysqlGraph.host
            port:       mysqlGraph.port
        client.query 'USE '+mysqlGraph.database
        client.query sql, (err, results, fields) ->
                if err
                    console.error "MySQL error:", JSON.stringify err
                    res.writeHead 500,
                        "Content-Type": "text/plain" # "application/json"
                    res.end (JSON.stringify err)
                else
                    console.log "MySQL returned #results:", results.length
                    res.writeHead 200,
                        "Content-Type": "text/plain" # "application/json"
                    res.end (JSON.stringify results)
                client.end()
    catch err
        res.writeHead 500,
            "Content-Type": "text/plain" # "application/json"
        res.end (JSON.stringify err)

console.log compileSmallGraphQueryToSQL [{"walk":[{"objectType":"user"},{"linkType":"wrote"},{"objectType":"post"}]}]

http.createServer (req,res) ->
        console.log ">> handling request from #{req.socket.remoteAddress+":"+req.socket.remotePort}"
        switch req.method
            when 'POST'
                rawQuery = ""
                req.on 'data', (chunk) ->
                    rawQuery += chunk
                req.on 'end', ->
                    query = JSON.parse rawQuery
                    processQuery query, res
            else
                {q} = (url.parse req.url, true).query
                q ?= ""
                query = smallgraphParser.parse q
                processQuery query, res

    .listen 53411

console.log "graphd running for", mysqlGraph
