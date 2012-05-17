# export syntax.parse
exports.parse = (require "./syntax").parse

# FIXME should be doing this with Jison
exports.parseExpr = parseExpr = JSON.parse
exports.parseConstraint = parseConstraint = (s) ->
    disjStrs = s.replace(/^\[(.*)\]$/, "$1").split /\s*\]\[\s*/
    for disjStr in disjStrs
        if disjStr == ""
            []
        else
            for cStr in disjStr.split /\s*;\s*/
                m = cStr.match /^(=|!=|<=|<|>=|>)\s*(.*)/
                if m?
                    c =
                        rel: m[1]
                        expr: parseExpr m[2]
                    c
                else
                    throw new Error "cannot parse constraint: #{cStr}"

# export everything of serialize
for i,f of require "./serialize"
    exports[i] = f

# TODO type check, prevent invalid queries from being run
exports.normalize = (q) ->
    eliminateEmptyConstraints = (q) ->
        elim = (s) ->
            if s.constraint? and s.constraint.length == 0
                delete s.constraint
        for decl in q when decl.let?
            elim decl.let[1]
        for decl in q when decl.walk?
            decl.walk.forEach elim
        q
    q = eliminateEmptyConstraints q
    q
