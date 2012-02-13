(function() {

  exports.parse = (require("./syntax")).parse;

  exports.serialize = (require("./serialize")).serialize;

  exports.normalize = function(q) {
    return q;
  };

}).call(this);
