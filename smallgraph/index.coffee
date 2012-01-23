exports.parse = (require "./syntax").parse
exports.serialize = (require "./serialize").serialize

# TODO type check, prevent invalid queries from being run
exports.normalize = (q) -> q
