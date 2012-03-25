exports.parse = (require "./syntax").parse
exports.serialize = (require "./serialize").serialize

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

