graphdPort = 53411

smallgraphParser = require "../smallgraph/syntax"
http = require "http"
url = require "url"
fs = require "fs"

graphDescriptor = JSON.parse (fs.readFileSync "mysqlgraph.json")

mysqlGraph = graphDescriptor.mysql
mysql = require "mysql"



uniq = (list) ->
    list2 = []
    for v in list
        list2.push v if -1 == list2.indexOf v
    list2

mergeObject = ->
    o = {}
    for oo in arguments
        for k,v of oo
            o[k] = v
    o


normalizeSmallGraphQuery = (query) ->
    query # TODO

compileSmallGraphQueryToSQL = (query) ->
    objects = mysqlGraph.layout.objects
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
    # index "look for"s and "aggregate"s in a lightweight first pass scan
    env = {}
    for decl in query
        if decl.look?
            [name, attrs] = decl.look
            env[name] ?= {}
            env[name].lookFors ?= {}
            lookFor = env[name].lookFors
            lookFor.attrs = (lookFor.attrs ? []).concat attrs
        if decl.aggregate?
            [name, aggfn] = decl.aggregate
            env[name] ?= {}
            env[name].aggregates ?= {}
            aggregate = env[name].aggregates
            aggregate.fn = aggfn
    # now, do the real compilation for walks
    transforms = []
    transformFields = []
    addFieldTransform = (fName, tr) ->
        if fName?
            transformFields.push [fName,tr]
        else
            transforms.push tr
    compileAttribute = (s, attrName) ->
        return null unless attrName?
        # try not to compile same attr twice
        if s.compiledAttributes? and s.compiledAttributes[attrName]?
            return s.compiledAttributes[attrName]
        # add attribute field selection
        unless (attr = s.layout.attrs[attrName])?
            console.error "unknown attribute #{attrName} for #{s.type}"
            return null
        attrFieldName = sqlName s.tag, s.type, attrName
        # TODO generalize this to cover link attributes
        if !attr.table || attr.table == s.layout.id.table
            fields.push [s.sqlTableName, attr.field, attrFieldName]
        else
            tableName = sqlName s.tag, s.type, "attr", attr.table
            # TODO unless attr.table already pushed
            tables.push [attr.table, tableName]
            conditions.push [s.sqlId, '=', [tableName, attr.joinOn]]
            fields.push [tableName, attr.field, attrFieldName]
        s.compiledAttributes ?= {}
        s.compiledAttributes[attrName] = attrFieldName
        attrFieldName
    addStepOutput = (s) ->
        if s.name?
            addFieldTransform null, (r) ->
                r.walks[s.walkNum][s.stepNum] = s.name
            unless env[s.name].outputDone
                addFieldTransform s.sqlIdName, (v, r) ->
                    r.names[s.name] =
                        id: v
                        attrs: {}
                aggregate = env[s.name].aggregates
                if aggregate?
                    # TODO aggregate
                else
                    lookFor = env[s.name].lookFors
                    if lookFor?
                        for attrName in lookFor.attrs
                            attrFieldName = compileAttribute s, attrName
                            if attrFieldName?
                                addFieldTransform attrFieldName, (v, r) ->
                                    r.names[s.name].attrs[attrName] = v
                env[s.name].outputDone = true
            labelFieldName = compileAttribute s, s.layout.label
            if labelFieldName?
                addFieldTransform labelFieldName, (v, r) ->
                    r.names[s.name].label = v
        else
            addFieldTransform s.sqlIdName, (v, r) ->
                r.walks[s.walkNum][s.stepNum] =
                    id: v
            labelFieldName = compileAttribute s, s.layout.label
            if labelFieldName?
                addFieldTransform labelFieldName, (v, r) ->
                    r.walks[s.walkNum][s.stepNum].label = v
    i = 0
    for decl in query
        if decl.let? # update env from let decl
            [name, step] = decl.let
            env[name] ?= {}
            env[name].step = step
        if decl.walk? # process walk
            {walk} = decl
            fields = []
            tables = []
            conditions = []
            j = 0
            addSQLNames = (o) ->
                o.sqlTableName = sqlName o.tag, o.type
                o.sqlIdName    = sqlName o.tag, o.type, "id"
                o.sqlId        = [o.sqlTableName, "id"]
                if (o.name = o.step.objectRef ? o.step.alias)?
                    env[o.name].references ?= []
                    env[o.name].references.push o
                o
            oneStep = (j, refField, tyField, layoutF) ->
                st = walk[j]
                if st[refField]?
                    throw new Error "unknown reference to "+st[refField] unless env[st[refField]]?.step?
                    st = mergeObject env[st[refField]].step, st
                if st.alias?
                    env[st.alias] ?= {}
                    env[st.alias].step = st
                ty = st[tyField]
                addSQLNames
                    walkNum: i
                    stepNum: j
                    tag: "#{i}_#{j}"
                    step: st
                    type: ty
                    layout: layoutF ty
            objectStep = (j) ->
                oneStep j, "objectRef", "objectType", (ty) -> objects[ty]
            linkStep = (s, j) ->
                oneStep j, "linkRef",   "linkType",   (ty) -> s.layout.links[ty]
            s = objectStep j++
            tables.push [s.layout.id.table, s.sqlTableName]
            fields.push [s.sqlTableName, s.layout.id.field, s.sqlIdName]
            addStepOutput s
            while j < walk.length
                l = linkStep s, j++
                t = objectStep j++
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
                addStepOutput t
                s = t
            walkSQLs.push """
                SELECT #{fields.map(sqlField).join ",\n       "}
                FROM #{tables.map(sqlTable).join ",\n     "}
                WHERE #{conditions.map(sqlCond).join "\n  AND "}
                """
            i++
    numWalks = i
    # join walks on coinciding nodes (hyperwalk) and project fields
    junctionConditions = []
    for name,env1 of env
        steps = env1.references
        if steps.length > 1
            i = 0
            lastStep = steps[i++]
            while i < steps.length
                st = steps[i++]
                junctionConditions.push [lastStep.sqlIdName, '=', st.sqlIdName]
                lastStep = st
    # define how to transform results
    rowTransformer = (row) ->
        r =
            names: {}
            walks: [] for [1..numWalks]
        transformFields.forEach ([f, tr]) -> tr(row[f], r)
        transforms.forEach (tr) -> tr(r)
        r
    # finally, return SQL and transformer back
    [
        """
        SELECT #{
            fields = ([f,_]) ->
                # TODO apply aggregation function to some fields
                f
            (uniq transformFields.map(fields)).join ",\n       "
        } FROM
        #{
            walkNum = 0
            ("(#{w.replace /\n/g, "$& "}) AS walk_#{walkNum++}" for w in walkSQLs).join ",\n"
        }
        #{
            if walkSQLs.length > 1
                "WHERE #{junctionConditions.map(sqlCond).join "\n  AND "}"
            else
                ""
        }
        #{
            # TODO aggregation GROUP BY
        }
        """
        rowTransformer
    ]

processQuery = (query, res) ->
    console.log ">>> SmallGraph Query:\n#{JSON.stringify query}\n<<<"
    queryNorm = normalizeSmallGraphQuery query
    [sql, rowTransformer] = compileSmallGraphQueryToSQL queryNorm
    console.log ">>> Compiled SQL:\n#{sql}\n<<<"

    sql += " LIMIT 100 OFFSET 2" # TODO parameterize limit and offset

    try
        client = mysql.createClient
            user:       mysqlGraph.user
            password:   mysqlGraph.password
            host:       mysqlGraph.host
            port:       mysqlGraph.port
        client.useDatabase mysqlGraph.database
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
                    "Access-Control-Allow-Origin": "*"
                res.end (JSON.stringify results.map rowTransformer)
            client.end()
    catch err
        console.error "Error while processQuery:", JSON.stringify err
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
                    query = JSON.parse rawQuery
                    processQuery query, res
            else
                {q} = (url.parse req.url, true).query
                q ?= ""
                query = smallgraphParser.parse q
                processQuery query, res

    .listen graphdPort

console.log "graphd running on port #{graphdPort} for", mysqlGraph
