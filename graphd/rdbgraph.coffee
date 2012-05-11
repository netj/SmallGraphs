{_} = require "underscore"
fs = require "fs"

{BaseGraph} = require "./basegraph"

class RelationalDataBaseGraph extends BaseGraph
    constructor: (@descriptor, @basepath) ->
        super @basepath
        unless @descriptor.layout? or @descriptor.layoutPath?
            throw new Error "layout or layoutPath are required for the graph descriptor"
        if @descriptor.layoutPath? and not @descriptor.layout?
            @descriptor.layout = JSON.parse (fs.readFileSync "#{@basepath}/#{@descriptor.layoutPath}")
        # populate schema from the RDB layout
        schema = @schema
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

    _runQuery: (query, limit, offset, req, res, q) ->
        # first compile query into SQL
        [sql, rowTransformer] = @compileSmallGraphQueryToSQL query
        sql += "\nLIMIT #{parseInt(limit)} OFFSET #{parseInt(offset)}\n"
        console.log "#{new Date()}: Compiled SQL >\n#{sql}\n<"
        # then, run it
        @_runSQL sql, rowTransformer, q

    # XXX override this
    _runSQL: (sql, rowTransformer, q) ->
        q.emit 'error', new Error "_runSQL not implemented, cannot run #{sql}"

    compileSmallGraphQueryToSQL: (query) ->
        objects = @descriptor.layout.objects
        sqlSanitizeName = (n) ->
            if n then n.replace /[^A-Za-z_0-9]/g, "_"
        sqlName = ->
            "_#{(sqlSanitizeName name for name in arguments).join "_"}_"
        sqlSubName = (name, subnames...) ->
            name + (sqlName subnames...)
        sqlTable = ([table, alias]) ->
            "#{table} as #{alias}"
        sqlNameRef = (e) ->
            switch typeof e
                when 'string'
                    e
                when 'number'
                    e
                else
                    "#{e[0]}.#{e[1]}"
        sqlExpr = (expr) ->
            switch typeof expr
                when 'string'
                    '"' + ((expr.replace /\\/, '\\').replace /"/, '\"') + '"'
                else
                    expr
        sqlCond = (cond) ->
            if _.isArray cond
                [left, rel, right] = cond
                "#{sqlNameRef left} #{rel} #{sqlNameRef right}"
            else if typeof cond == 'object'
                {disjunctions} = cond
                "(#{(sqlCond c for c in disjunctions).join " OR "})"
            else
                throw new Error "malformed SQL condition: #{cond}"
        #############################################################
        # first, a quick validation of names
        env = {}
        for decl in query
            if decl.let? # update env from let decl
                [name, step] = decl.let
                if env[name]?
                    throw new Error "Cannot define $#{name} more than once"
                env1 = env[name] = {}
                env1.step = step
            if decl.walk? # look for aliases in each walk
                for step in decl.walk
                    if step.alias?
                        name = step.alias
                        env1 = env[name] ?= {}
                        env1.step ?= step
                    if step.objectRef? or step.linkRef?
                        name = step.objectRef ? step.linkRef
                        unless env[name]?
                            throw new Error "Bad reference to $#{name} from a walk"
            if decl.look?
                [name, attrs] = decl.look
                env1 = env[name]
                unless env1?
                    throw new Error "Bad reference to $#{name} from a look"
                env1.lookFors ?= {}
                lookFors = env1.lookFors
                # TODO give structure to string attrs
                lookFors.attrs = (lookFors.attrs ? []).concat attrs
                if env1.aggregates? # look xor aggregate
                    throw new Error "Cannot look for attributes of aggregated objects: $#{name}"
            if decl.aggregate?
                [name, attrAggs, constraint] = decl.aggregate
                env1 = env[name]
                unless env1?
                    throw new Error "Bad reference to $#{name} from an aggregate"
                env1.aggregates ?= {}
                env1.aggregates.attrs = attrAggs
                env1.aggregates.constraint = constraint
                if env1.lookFors? # look xor aggregate
                    throw new Error "Cannot look for attributes of aggregated objects: $#{name}"
        # XXX console.log ">>>env-precompilation>>>", JSON.stringify env, null, 2
        #############################################################
        # then, do some compilation for walks
        fields = {}
        tables = []
        conditions = []
        transforms = []
        transformFields = []
        addFieldTransform = (fName, tr) ->
            # XXX console.log "rowTransformer for ", fName
            if fName?
                transformFields.push [fName,tr]
            else
                transforms.push tr
        compileConstraint = (conjs, lhs, conditionsAcc = conditions) ->
            return unless conjs? and conjs.length > 0 and conjs[0].length > 0
            for disjs in conjs
                conditionsAcc.push
                    disjunctions: ([lhs, c.rel, sqlExpr c.expr] for c in disjs)
        compileOneStep = (s) ->
            if s.name?
                env1 = env[s.name]
                unless env1?
                    throw new Error "bad reference: $#{s.name}"
                addFieldTransform null, (r) ->
                    # XXX console.log "mapping", s.walkNum, s.stepNum
                    r.walks[s.walkNum][s.stepNum] = s.name
                unless env1.outputMapping?
                    env1.outputMapping = s
                    tables.push [s.layout.id.table, s.sql.tableName]
                    fields[s.sql.idName] = s.sql.idRef
            else
                tables.push [s.layout.id.table, s.sql.tableName]
                fields[s.sql.idName] = s.sql.idRef
                addFieldTransform s.sql.idName, (v, r) ->
                    # XXX console.log "mapping", s.walkNum, s.stepNum
                    r.walks[s.walkNum][s.stepNum] =
                        id: v
        walkMappings = []
        i = 0
        for decl in query
            if decl.walk? # process walk
                {walk} = decl
                walkMappings[i] = []
                j = 0
                stepMapping = (j, refField, tyField, layoutF) ->
                    step = walk[j]
                    walkMappings[i][j] = m =
                        walkNum: i
                        stepNum: j
                        tag: "#{i}_#{j}"
                        step: step
                        constraint: step.constraint
                    # if this step references a name or has an alias, look up the env
                    if step[refField]?
                        m.name = step[refField]
                        env1 = env[m.name]
                        # TODO what about recursive references? e.g., let a = object; let b = $a; walk $b;
                        unless env1?.step?
                            throw new Error "unknown reference to "+m.name
                        step = env1.step
                        # augment constraint, dont replace
                        m.constraint = (step.constraint ? []).concat (m.constraint ? [])
                    else if step.alias?
                        m.name = step.alias
                        env1 = env[step.alias]
                        if env1?.step?
                            # check for type mismatches
                            unless step[tyField] == env1.step[tyField]
                                throw new Error "type mismatch with previous alias "+m.name
                            # TODO decide whether we want to merge constraint, making walk order matter
                            #m.constraint ?= []
                            #m.constraint = env1.step.constraint.concat m.constraint
                        else
                            # add an entry to env otherwise
                            env1 = env[step.alias] ?= {}
                            env1.step = step
                    else
                        env1 = null
                    # record references
                    if env1?
                        env1.name = m.name
                        env1.referingSteps ?= []
                        env1.referingSteps.push m
                    # type and layout
                    m.type = step[tyField]
                    m.layout = layoutF m.type
                    # assign SQL names if it hasn't got them yet
                    m.sql = env1?.sql
                    unless m.sql?
                        m.sql =
                            tableName: sqlName m.tag, m.type
                        if m.layout.id?
                            m.sql.idName = sqlName m.tag, m.type, "id"
                            m.sql.idRef  = [m.sql.tableName, m.layout.id.field]
                        env1.sql ?= m.sql if env1?
                    m
                objectStepMapping =  (j) -> stepMapping j, "objectRef", "objectType", (ty) -> objects[ty]
                linkStepMapping = (s, j) -> stepMapping j,   "linkRef",   "linkType", (ty) -> s.layout.links[ty]
                s = objectStepMapping j++
                compileOneStep s
                while j < walk.length
                    l = linkStepMapping s, j++
                    t = objectStepMapping j++
                    console.assert l.layout.to == t.type,
                        "invalid walk step: #{s.type} -#{l.type}-> #{t.type}"
                    # add target object's fields and table
                    compileOneStep t
                    # add conditions for joining source and target based on link's layout
                    if !l.layout.table || l.layout.table == s.layout.id.table
                        # link's layout specifies the field on the source object's table
                        conditions.push [[s.sql.tableName, l.layout.field], '=', t.sql.idRef]
                    else if l.layout.table == t.layout.id.table
                        # or a field on the target table, so we still don't need any additional join
                        conditions.push [s.sql.idRef, '=', [t.sql.tableName, l.layout.joinOn]]
                    else
                        # otherwise, we need to consult another table that defines the link between source and target
                        tables.push [l.layout.table, l.sql.tableName]
                        conditions.push [[l.sql.tableName, l.layout.joinOn], '=', s.sql.idRef]
                        conditions.push [[l.sql.tableName, l.layout.field ], '=', t.sql.idRef]
                    s = t
                i++
        #############################################################
        # compile attributes and aggregations
        compileAttribute = (stepMapping, attrName) ->
            return null unless attrName?
            # try not to compile same attr twice
            if stepMapping.compiledAttributes? and stepMapping.compiledAttributes[attrName]?
                return stepMapping.compiledAttributes[attrName]
            # add attribute field selection
            unless (attr = stepMapping.layout.attrs[attrName])?
                throw new Error "unknown attribute #{attrName} for $#{stepMapping.name}"
                return null
            attrFieldName = sqlSubName stepMapping.sql.tableName, attrName
            # TODO generalize this to cover link attributes
            if !attr.table || attr.table == stepMapping.layout.id.table
                fields[attrFieldName] = [stepMapping.sql.tableName, attr.field]
                attrField = [
                    attrFieldName
                    [stepMapping.sql.tableName, attr.field]
                ]
            else
                tableName = sqlSubName stepMapping.sql.tableName, "attr", attr.table
                # TODO unless attr.table already pushed
                tables.push [attr.table, tableName]
                conditions.push [stepMapping.sql.idRef, '=', [tableName, attr.joinOn]]
                fields[attrFieldName] = [tableName, attr.field]
                attrField = [
                    attrFieldName
                    [tableName, attr.field]
                ]
            stepMapping.compiledAttributes ?= {}
            stepMapping.compiledAttributes[attrName] = attrField
            attrField
        # compile attributes
        for name, env1 of env
            continue unless env1.referingSteps?
            continue if env1.aggregates?
            do (name) ->
                outputMapping = env1.outputMapping
                env1.sql.orderByAttrFieldName = {}
                addFieldTransform outputMapping.sql.idName, (v, r) ->
                    # XXX console.log "mapping", name
                    r.names[name] =
                        id: v
                # look for attributes
                if env1.lookFors?
                    for attr in env1.lookFors.attrs
                        do (attr) ->
                            if typeof attr == 'string'
                                attrName = attr
                                attrConstraint = null
                            else
                                attrName = attr.name
                                attrConstraint = attr.constraint
                            attrField = compileAttribute outputMapping, attrName
                            if attrField?
                                [attrFieldName, attrFieldRef] = attrField
                                addFieldTransform attrFieldName, (v, r) ->
                                    # XXX console.log "mapping", name, attrName
                                    r.names[name].attrs ?= {}
                                    r.names[name].attrs[attrName] = v
                                env1.sql.orderByAttrFieldName[attrName] = attrFieldName
                                compileConstraint attrConstraint, attrFieldRef
                # label attribute
                if outputMapping.layout.label?
                    labelField = compileAttribute outputMapping, outputMapping.layout.label
                    if labelField?
                        [labelFieldName, labelFieldRef] = labelField
                        addFieldTransform labelFieldName, (v, r) ->
                            # XXX console.log "mapping", name, "label"
                            r.names[name].label = v
                        env1.sql.orderByAttrFieldName[outputMapping.layout.label] = labelFieldName
                # constraints
                if outputMapping.constraint?
                    compileConstraint outputMapping.constraint, outputMapping.sql.idRef
        # compile label attributes for unnamed steps of walks
        for walkMapping in walkMappings
            for stepMapping in walkMapping
                continue if stepMapping.name?
                continue unless stepMapping.layout?.label?
                labelField = compileAttribute stepMapping, stepMapping.layout.label
                if labelField?
                    [labelFieldName, labelFieldRef] = labelField
                    do (stepMapping) ->
                        addFieldTransform labelFieldName, (v, r) ->
                            # XXX console.log "mapping", stepMapping.walkNum, stepMapping.stepNum, "label"
                            r.walks[stepMapping.walkNum][stepMapping.stepNum].label = v
        # compile constraints of unnamed steps
        for walkMapping in walkMappings
            for stepMapping in walkMapping
                continue if stepMapping.name?
                compileConstraint stepMapping.constraint, stepMapping.sql.idRef
        # compile aggregations
        hasAggregation = false
        aggregatingFields = {}
        groupbyConditions = []
        for name, env1 of env
            continue unless env1.referingSteps?
            continue unless env1.aggregates?
            hasAggregation = true
            do (name) ->
                env1.sql.orderByAttrFieldName = {}
                outputMapping = env1.outputMapping
                # aggregate id as count
                aggfn = "count"
                aggregatedFieldName = sqlName outputMapping.tag, outputMapping.type, outputMapping.layout.id.field, aggfn
                aggregatingFields[aggregatedFieldName] =
                    fn: aggfn
                    fieldName: outputMapping.sql.idName
                    fieldRef : outputMapping.sql.idRef
                addFieldTransform aggregatedFieldName, (v, r) ->
                    # XXX console.log "mapping agg", name
                    r.names[name] =
                        label: v
                env1.sql.orderByFieldName = aggregatedFieldName
                compileConstraint env1.aggregates.constraint, aggregatedFieldName, groupbyConditions
                # aggregate each attribute
                for [attrName, aggfn, aggregatedAttrConstraint] in env1.aggregates.attrs
                    do (attrName) ->
                        aggfn ?= "count"
                        attrField = compileAttribute outputMapping, attrName
                        if attrField?
                            [attrFieldName, attrFieldRef] = attrField
                            aggregatedAttrFieldName = sqlName outputMapping.tag, outputMapping.type, attrName, aggfn
                            aggregatingFields[aggregatedAttrFieldName] =
                                fn: aggfn
                                fieldName: attrFieldName
                                fieldRef : attrFieldRef
                            addFieldTransform aggregatedAttrFieldName, (v, r) ->
                                # XXX console.log "mapping agg", name, attrName
                                r.names[name].attrs ?= {}
                                r.names[name].attrs[attrName] = v
                            env1.sql.orderByAttrFieldName[attrName] = aggregatedAttrFieldName
                            compileConstraint aggregatedAttrConstraint, aggregatedAttrFieldName, groupbyConditions
        # XXX console.log ">>>env>>>", JSON.stringify env, null, 2
        #############################################################
        # collect ordering criteria
        orderByFields = []
        for decl in query
            if decl.orderby?
                for d in decl.orderby
                    [name, attrName, order] = d
                    env1 = env[name]
                    unless env1?
                        throw new Error "bad reference: $#{name}"
                    if not attrName? and not env1.aggregates?
                        attrName = env1.outputMapping.layout.label
                    orderbyFieldName =
                        if attrName?
                            env1.sql.orderByAttrFieldName[attrName]
                        else
                            env1.sql.orderByFieldName ? env1.outputMapping.sql.idName
                    orderByFields.push [orderbyFieldName, order]
        numWalks = i
        # prepare some groupBys and aggregateFields
        aggFieldDecs = []
        for aggFieldName, {fn, fieldName, fieldRef} of aggregatingFields
            delete fields[fieldName] # no need to select the actual fields being aggregated
            aggFieldDecs.push "#{fn.toUpperCase()}(#{
                if fn == "count" then "DISTINCT "
                else ""}#{sqlNameRef fieldRef}) AS #{aggFieldName}"
        fieldDecs = []
        groupByFieldNames = []
        for fieldName, fieldRef of fields
            if fieldRef?
                fieldDecs.push "#{sqlNameRef fieldRef} AS #{fieldName}"
                groupByFieldNames.push fieldName
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
                else "GROUP BY #{(fieldName for fieldName in groupByFieldNames).join ",\n         "}"
            }
            #{
                if groupbyConditions.length == 0 then ""
                else "HAVING #{groupbyConditions.map(sqlCond).join "\n   AND "}"
            }
            #{
                unless orderByFields.length > 0 then ""
                else "ORDER BY #{("#{ord[0]} #{ord[1].toUpperCase()}" for ord in orderByFields).join ",\n         "}"
            }
            """
            rowTransformer
        ]


exports.RelationalDataBaseGraph = RelationalDataBaseGraph
