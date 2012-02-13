(function() {
  var serialize, serializeConstraint, serializeExpr, serializeStep;

  serializeExpr = function(expr) {
    switch (typeof expr) {
      case 'string':
        return '"' + ((expr.replace(/\\/, '\\')).replace(/"/, '\"')) + '"';
      default:
        return expr;
    }
  };

  serializeConstraint = function(conj) {
    var c, disj;
    if (conj) {
      return ((function() {
        var _i, _len, _results;
        _results = [];
        for (_i = 0, _len = conj.length; _i < _len; _i++) {
          disj = conj[_i];
          _results.push("[" + (((function() {
            var _j, _len2, _results2;
            _results2 = [];
            for (_j = 0, _len2 = disj.length; _j < _len2; _j++) {
              c = disj[_j];
              _results2.push("" + c.rel + (serializeExpr(c.expr)));
            }
            return _results2;
          })()).join("; ")) + "]");
        }
        return _results;
      })()).join("");
    } else {
      return "";
    }
  };

  serializeStep = function(step) {
    var s;
    s = "";
    if (step.objectType) {
      s += step.objectType;
      if (step.alias) s += "(" + step.alias + ")";
      if (step.constraint) s += serializeConstraint(step.constraint);
    } else if (step.objectRef) {
      s += "$" + step.objectRef;
      if (step.constraint) s += serializeConstraint(step.constraint);
    } else if (step.linkType) {
      s += " -";
      s += step.linkType;
      if (step.alias) s += "(" + step.alias + ")";
      if (step.constraint) s += serializeConstraint(step.constraint);
      s += "-> ";
    }
    return s;
  };

  serialize = function(smallgraph) {
    var aggfn, attr, attrNameOrNameWithConstraint, constraint, d, decl, ord, s, step, _i, _j, _len, _len2, _ref, _ref2;
    s = "";
    for (_i = 0, _len = smallgraph.length; _i < _len; _i++) {
      decl = smallgraph[_i];
      if (decl.walk) {
        s += "walk ";
        _ref = decl.walk;
        for (_j = 0, _len2 = _ref.length; _j < _len2; _j++) {
          step = _ref[_j];
          s += serializeStep(step);
        }
      } else if (decl.look) {
        d = decl.look;
        attrNameOrNameWithConstraint = function(a) {
          if (typeof a === 'object') {
            return "@" + a.name + (serializeConstraint(a.constraint));
          } else {
            return "@" + a;
          }
        };
        s += "look $" + d[0] + " for " + (d[1].map(attrNameOrNameWithConstraint).join(", "));
      } else if (decl.aggregate) {
        d = decl.aggregate;
        s += "aggregate $" + d[0];
        if (d[2] && d[2].length > 0) s += serializeConstraint(d[2]);
        if (d[1] && d[1].length > 0) {
          s += " with ";
          s += ((function() {
            var _k, _len3, _ref2, _ref3, _results;
            _ref2 = d[1];
            _results = [];
            for (_k = 0, _len3 = _ref2.length; _k < _len3; _k++) {
              _ref3 = _ref2[_k], attr = _ref3[0], aggfn = _ref3[1], constraint = _ref3[2];
              _results.push("@" + attr + " as " + aggfn + (serializeConstraint(constraint)));
            }
            return _results;
          })()).join(", ");
        }
      } else if (decl.subgraph) {
        d = decl.subgraph;
        s += "subgraph " + d[0] + " = {\n  ";
        s += (serialize(d[1])).replace(/\n/g, "\n  ");
        s += "}";
      } else if (decl["let"]) {
        d = decl["let"];
        s += "let " + d[0] + " = " + (serializeStep(d[1]));
      } else if (decl.orderby) {
        d = decl.orderby;
        if (!(((_ref2 = decl.orderby) != null ? _ref2.length : void 0) > 0)) {
          continue;
        }
        s += "order by ";
        s += ((function() {
          var _k, _len3, _results;
          _results = [];
          for (_k = 0, _len3 = d.length; _k < _len3; _k++) {
            ord = d[_k];
            _results.push("$" + ord[0] + (ord[1] != null ? " @" + ord[1] : "") + " " + ord[2]);
          }
          return _results;
        })()).join(", ");
      }
      s += ";\n";
    }
    return s;
  };

  if (typeof require !== 'undefined' && typeof exports !== 'undefined') {
    exports.serialize = serialize;
  } else if (typeof window !== 'undefined') {
    window.smallgraphSerialize = serialize;
  }

}).call(this);
