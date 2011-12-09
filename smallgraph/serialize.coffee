serializeConstraint = (c) ->
    c

serializeStep = (step) ->
    s = ""
    if step.objectType
        s += step.objectType
        s += "(#{step.alias})" if step.alias
        s += "[#{serializeConstraint step.constraint}]" if step.constraint
    else if step.objectRef
        s += "$#{step.objectRef}"
        s += "[#{serializeConstraint step.constraint}]" if step.constraint
    else if step.linkType
        s += " -"
        s += step.linkType
        s += "(#{step.alias})" if step.alias
        s += "[#{serializeConstraint step.constraint}]" if step.constraint
        s += "-> "
    s

serialize = (smallgraph) ->
    s = ""
    for decl in smallgraph
        if decl.walk
            s += "walk "
            for step in decl.walk
                s += serializeStep step
        else if decl.look
            d = decl.look
            s += "look $#{d[0]} for #{d[1].join ", "}"
        else if decl.aggregate
            d = decl.aggregate
            s += "aggregate $#{d[0]} as #{d[1]}"
        else if decl.subgraph
            d = decl.subgraph
            s += "subgraph #{d[0]} = {\n  "
            s += (serialize d[1]).replace /\n/g, "\n  "
            s += "}"
        else if decl.let
            d = decl.let
            s += "let #{d[0]} = #{serializeStep d[1]}"
        s += ";\n"
    s

if typeof require != 'undefined' && typeof exports != 'undefined'
    exports.serialize = serialize
else if typeof window != 'undefined'
    window.smallgraphSerialize = serialize
