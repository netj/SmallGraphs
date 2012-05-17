exports.serializeExpr = serializeExpr = (expr) ->
    switch typeof expr
        when 'string'
            '"' + ((expr.replace /\\/, '\\').replace /"/, '\"') + '"'
        else
            expr

exports.serializeConstraint = serializeConstraint = (conj) ->
    if conj
        ("[#{("#{c.rel}#{serializeExpr c.expr}" for c in disj).join "; "}]" for disj in conj).join ""
    else
        ""

serializeStep = (step) ->
    s = ""
    if step.objectType
        s += step.objectType
        s += "(#{step.alias})" if step.alias
        s += serializeConstraint step.constraint if step.constraint
    else if step.objectRef
        s += "$#{step.objectRef}"
        s += serializeConstraint step.constraint if step.constraint
    else if step.linkType
        s += " -"
        s += step.linkType
        s += "(#{step.alias})" if step.alias
        s += serializeConstraint step.constraint if step.constraint
        s += "-> "
    s

exports.serialize = serialize = (smallgraph) ->
    s = ""
    for decl in smallgraph
        if decl.walk
            s += "walk "
            for step in decl.walk
                s += serializeStep step
        else if decl.look
            d = decl.look
            attrNameOrNameWithConstraint = (a) ->
                if typeof a == 'object'
                    "@#{a.name}#{serializeConstraint a.constraint}"
                else
                    "@#{a}"
            s += "look $#{d[0]} for #{d[1].map(attrNameOrNameWithConstraint).join ", "}"
        else if decl.aggregate
            d = decl.aggregate
            s += "aggregate $#{d[0]}"
            if d[2] and d[2].length > 0
                s += serializeConstraint d[2]
            if d[1] and d[1].length > 0
                s += " with "
                s += ("@#{attr} as #{aggfn}#{serializeConstraint constraint}" for [attr, aggfn, constraint] in d[1]).join ", "
        else if decl.subgraph
            d = decl.subgraph
            s += "subgraph #{d[0]} = {\n  "
            s += (serialize d[1]).replace /\n/g, "\n  "
            s += "}"
        else if decl.let
            d = decl.let
            s += "let #{d[0]} = #{serializeStep d[1]}"
        else if decl.orderby
            d = decl.orderby
            continue unless decl.orderby?.length > 0
            s += "order by "
            s += ("$#{ord[0]}#{if ord[1]? then " @#{ord[1]}" else ""} #{ord[2]}" for ord in d).join ", "
        s += ";\n"
    s
