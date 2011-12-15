# configure some knobs
_GraphDPort = 53411
_GraphDirectoryPath = "graphs"


# TODO move this to smallgraph
smallgraph =
    parse: (require "../smallgraph/syntax").parse
    serialize: (require "../smallgraph/serialize").serialize

http = require "http"
url = require "url"
fs = require "fs"


normalizeSmallGraphQuery = (query) ->
    # TODO type check, prevent invalid queries from being run
    query # TODO someday


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


{EventEmitter} = require('events')

class RelationalDataBaseGraph
    constructor: (@descriptor) ->
        # derive SmallGraphs schema from the RDB layout
        schema =
            Namespaces:
                xsd: 'http://www.w3.org/2001/XMLSchema'
            Objects: {}
            TypeLabels: {}
        for objName, objLayout of @descriptor.layout.objects
            links = {}
            for lnName, lnLayout of objLayout.links
                links[lnName] = [lnLayout.to]
            attrs = {}
            for attrName, attrLayout of objLayout.attrs
                attrs[attrName] = attrLayout.type
            schema.Objects[objName] =
                Label: objLayout.label
                Links: links
                Attributes: attrs
        @smallGraphsSchema = schema

    compileSmallGraphQueryToSQL: (query) ->
        objects = @descriptor.layout.objects
        sqlSanitizeName = (n) ->
            if n then n.replace /[^A-Za-z_0-9]/g, "_"
        sqlName = ->
            "_#{(sqlSanitizeName name for name in arguments).join "_"}_"
        sqlTable = ([table, alias]) ->
            "#{table} as #{alias}"
        sqlNameRef = (e) ->
            if typeof e == 'string'
                e
            else
                "#{e[0]}.#{e[1]}"
        sqlCond = ([left, rel, right]) ->
            "#{sqlNameRef left} #{rel} #{sqlNameRef right}"
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
                [name, attrAggs] = decl.aggregate
                env[name] ?= {}
                env[name].aggregates ?= {}
                aggregate = env[name].aggregates
                aggregate.attrs = attrAggs
        # now, do the real compilation for walks
        fields = {}
        tables = []
        conditions = []
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
                fields[attrFieldName] = [s.sqlTableName, attr.field]
                attrField = [
                        attrFieldName
                        [s.sqlTableName, attr.field]
                    ]
            else
                tableName = sqlName s.tag, s.type, "attr", attr.table
                # TODO unless attr.table already pushed
                tables.push [attr.table, tableName]
                conditions.push [s.sqlId, '=', [tableName, attr.joinOn]]
                fields[attrFieldName] = [tableName, attr.field]
                attrField = [
                        attrFieldName
                        [tableName, attr.field]
                    ]
            s.compiledAttributes ?= {}
            s.compiledAttributes[attrName] = attrField
            attrField
        hasAggregation = false
        aggregatingFields = {}
        addStepOutput = (s) ->
            if s.step.constraint?
                # TODO support full CNF
                cnf = s.step.constraint
                if cnf.length > 0
                    c = cnf[0][0]
                    sqlExpr = (expr) ->
                        switch typeof expr
                            when 'string'
                                '"' + ((expr.replace /\\/, '\\').replace /"/, '\"') + '"'
                            else
                                expr
                    conditions.push [[s.sqlTableName, s.layout.id.field], c.rel, sqlExpr c.expr]
            if s.name?
                env1 = env[s.name]
                unless env1?
                    throw new Error "bad reference: $#{s.name}"
                addFieldTransform null, (r) ->
                    r.walks[s.walkNum][s.stepNum] = s.name
                if env1.outputStep?
                    # use the representative table
                    s.sqlTableName = env1.outputStep.sqlTableName
                    s.sqlIdName = env1.outputStep.sqlIdName
                    s.sqlId = env1.outputStep.sqlId
                else
                    tables.push [s.layout.id.table, s.sqlTableName]
                    fields[s.sqlIdName] = [s.sqlTableName, s.layout.id.field]
                    env1.sqlOrderByAttrFieldName = {}
                    if env1.aggregates?
                        hasAggregation = true
                        # aggregate id's as count
                        aggfn = "count"
                        aggregatedFieldName = sqlName s.tag, s.type, s.layout.id.field, aggfn
                        aggregatingFields[aggregatedFieldName] =
                            fn: aggfn
                            fieldname: s.sqlIdName
                            fieldref: s.sqlId
                        addFieldTransform aggregatedFieldName, (v, r) ->
                            r.names[s.name] =
                                label: v
                                attrs: {}
                        s.sqlOrderByFieldName = aggregatedFieldName
                        # aggregate each attribute
                        for [attrName, aggfn] in env1.aggregates.attrs
                          do (attrName) ->
                            aggfn ?= "count"
                            attrField = compileAttribute s, attrName
                            if attrField?
                                [attrFieldName, attrFieldRef] = attrField
                                aggregatedAttrFieldName = sqlName s.tag, s.type, attrName, aggfn
                                aggregatingFields[aggregatedAttrFieldName] =
                                    fn: aggfn
                                    fieldname: attrFieldName
                                    fieldref: attrField
                                addFieldTransform aggregatedAttrFieldName, (v, r) ->
                                    r.names[s.name].attrs[attrName] = v
                                env1.sqlOrderByAttrFieldName[attrName] = aggregatedAttrFieldName
                    else # look for attributes only when not aggregating
                        addFieldTransform s.sqlIdName, (v, r) ->
                            r.names[s.name] =
                                id: v
                                attrs: {}
                        if env1.lookFors?
                            for attrName in env1.lookFors.attrs
                              do (attrName) ->
                                attrField = compileAttribute s, attrName
                                if attrField?
                                    [attrFieldName, attrFieldRef] = attrField
                                    addFieldTransform attrFieldName, (v, r) ->
                                        r.names[s.name].attrs[attrName] = v
                                    env1.sqlOrderByAttrFieldName[attrName] = attrFieldName
                        # label attribute
                        if s.layout.label?
                            labelField = compileAttribute s, s.layout.label
                            if labelField?
                                [labelFieldName, labelFieldRef] = labelField
                                addFieldTransform labelFieldName, (v, r) ->
                                    r.names[s.name].label = v
                                env1.sqlOrderByAttrFieldName[s.layout.label] = labelFieldName
                    env1.outputStep = s
            else
                tables.push [s.layout.id.table, s.sqlTableName]
                fields[s.sqlIdName] = [s.sqlTableName, s.layout.id.field]
                addFieldTransform s.sqlIdName, (v, r) ->
                    r.walks[s.walkNum][s.stepNum] =
                        id: v
                labelField = compileAttribute s, s.layout.label
                if labelField?
                    [labelFieldName, labelFieldRef] = labelField
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
                j = 0
                addSQLNames = (o) ->
                    o.sqlTableName = sqlName o.tag, o.type
                    if o.layout.id?
                        o.sqlIdName    = sqlName o.tag, o.type, "id"
                        o.sqlId        = [o.sqlTableName, o.layout.id.field]
                    if (o.name = o.step.objectRef ? o.step.alias)?
                        env[o.name].references ?= []
                        env[o.name].references.push o
                    o
                oneStep = (j, refField, tyField, layoutF) ->
                    st = walk[j]
                    if st[refField]?
                        throw new Error "unknown reference to "+st[refField] unless env[st[refField]]?.step?
                        st = mergeObject env[st[refField]].step, st
                        # TODO augment constraints, dont replace
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
                addStepOutput s
                while j < walk.length
                    l = linkStep s, j++
                    t = objectStep j++
                    console.assert l.layout.to == t.type,
                        "invalid walk step: #{s.type} -#{l.type}-> #{t.type}"
                    # add target object's fields and table
                    addStepOutput t
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
                    s = t
                i++
        # collect ordering criteria
        orderByFields = []
        for decl in query
            if decl.orderby?
                for d in decl.orderby
                    env1 = env[d[0]]
                    unless env1?
                        throw new Error "bad reference: $#{d[0]}"
                    s = env1.outputStep
                    attrName = d[1]
                    if not attrName? and not env1.aggregates?
                        attrName = s.layout.label
                    orderbyFieldName =
                        if attrName?
                            env1.sqlOrderByAttrFieldName[attrName]
                        else
                            s.sqlOrderByFieldName ? s.sqlIdName
                    orderByFields.push [orderbyFieldName, d[2]]
        numWalks = i
        # join walks on coinciding nodes (hyperwalk) and project fields
        for name,env1 of env
            steps = env1.references
            if steps and steps.length > 1
                i = 0
                lastStep = steps[i++]
                while i < steps.length
                    st = steps[i++]
                    conditions.push [lastStep.sqlId, '=', st.sqlId]
                    lastStep = st
        # prepare some groupBys and aggregateFields
        aggFieldDecs = []
        for aggFieldName, {fn, fieldname, fieldref} of aggregatingFields
            fields[fieldname] = null # no need to select the actual fields being aggregated
            aggFieldDecs.push "#{fn.toUpperCase()}(#{
                if fn == "count" then "DISTINCT "
                else ""}#{sqlNameRef fieldref}) AS #{aggFieldName}"
        fieldDecs = []
        groupByFieldNames = []
        for fieldname, fieldref of fields
            if fieldref?
                fieldDecs.push "#{sqlNameRef fieldref} AS #{fieldname}"
                groupByFieldNames.push fieldname
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
            SELECT #{fieldDecs.concat(aggFieldDecs).join ",\n       "}
            FROM #{tables.map(sqlTable).join ",\n     "}
            #{
                if conditions.length == 0 then ""
                else "WHERE #{conditions.map(sqlCond).join "\n  AND "}"
            }
            #{
                unless hasAggregation and fieldDecs.length > 0 then ""
                else "GROUP BY #{(fieldname for fieldname in groupByFieldNames).join ",\n         "}"
            }
            #{
                unless orderByFields.length > 0 then ""
                else "ORDER BY #{("#{ord[0]} #{ord[1].toUpperCase()}" for ord in orderByFields).join ",\n "}"
            }
            """
            rowTransformer
        ]

    query: (query, limit, offset, req, res) ->
        q = new EventEmitter
        q.abort = (err) ->
        # first compile query
        console.log "#{new Date()}: >>> SmallGraph Query:\n#{JSON.stringify query}\n<<< >>>\n#{smallgraph.serialize query}\n<<<"
        query = normalizeSmallGraphQuery query
        [sql, rowTransformer] = @compileSmallGraphQueryToSQL query
        sql += "\nLIMIT #{parseInt(limit)} OFFSET #{parseInt(offset)}\n"
        console.log "#{new Date()}: >>> Compiled SQL:\n#{sql}\n<<<"
        @runSQL sql, rowTransformer, q

    runSQL: (sql, rowTransformer, q) ->
        q.emit 'error', new Error "runSQL not implemented, cannot run #{sql}"


_MySQL = require "mysql"

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
                q.emit 'result', results.map rowTransformer
            client.end()
        q.abort = (err) ->
            console.log "<< #{new Date()}: aborting request " + (err ? "")
            client.end()
            client.destroy()
        client.once 'error', (err) ->
            q.abort err
            q.emit 'error', err
        q


# factory method
loadGraph = (graphId) ->
    path = "#{_GraphDirectoryPath}/#{graphId}/graphd.json"
    graphDescriptor = JSON.parse fs.readFileSync path
    if graphDescriptor.mysql
        return new MySQLGraph graphDescriptor.mysql
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
                mergeObject {
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
            [_, graphId, command] = parsedURL.pathname.match(/^\/(.*)\/(schema|query)$/)
            # TODO sanitize graphId (../, ...)
            try
                g = getGraph graphId
            catch err
                console.log "Cannot get graph '#{graphId}': " + err
            unless g?
                sendHeaders 404
                res.end "Graph not available"
                return
            console.log " #{command} for graph '#{graphId}'"
            switch command
                when 'schema' # /#{graphname}/schema GET
                    # send schema of this graph for SmallGraphs UI
                    sendHeaders 200
                    res.end JSON.stringify g.smallGraphsSchema
                    return
                when 'query' # /#{graphname}/query {POST,GET,OPTIONS}
                    # process queries sketched from SmallGraphs UI on this graph
                    sendResultOf = (queried) ->
                        # send garbage back to keep the connection from dropping (WebKit drops it after 2 min)
                        keepAlive = -> res.write " "
                        keepAliveInterval = setInterval keepAlive, 10000
                        queried.on 'result', (result) ->
                                clearInterval keepAliveInterval
                                sendHeaders 200
                                res.end (JSON.stringify result)
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
                            sendResultOf g.query query, limit, offset
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
