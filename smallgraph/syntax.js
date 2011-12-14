/* Jison generated parser */
var syntax = (function(){


var parser = {trace: function trace() { },
yy: {},
symbols_: {"error":2,"smallgraph":3,"declarations":4,"EOF":5,"declaration":6,";":7,"WALK":8,"walk":9,"SUBGRAPH":10,"NAME":11,"=":12,"{":13,"subgraph":14,"}":15,"LET":16,"object":17,"LOOK":18,"VARREF":19,"FOR":20,"attributes":21,"AGGREGATE":22,"optional_attributeAggregations":23,"ORDER":24,"BY":25,"orderings":26,"stepObject":27,"-":28,"stepLink":29,"->":30,"optional_alias":31,"optional_constraint":32,"(":33,")":34,"[":35,"constraint_disjunctions":36,"]":37,"constraint":38,"|":39,"rel":40,"expr":41,"!=":42,"<=":43,"<":44,">=":45,">":46,"NUMBER_LIT":47,"STRING_LIT":48,"attribute":49,",":50,"ATTRNAME":51,"WITH":52,"attributeAggregations":53,"attributeAggregation":54,"AS":55,"aggregation":56,"COUNT":57,"SUM":58,"MIN":59,"MAX":60,"ordering":61,"order":62,"DESCENDING":63,"ASCENDING":64,"$accept":0,"$end":1},
terminals_: {2:"error",5:"EOF",7:";",8:"WALK",10:"SUBGRAPH",11:"NAME",12:"=",13:"{",15:"}",16:"LET",18:"LOOK",19:"VARREF",20:"FOR",22:"AGGREGATE",24:"ORDER",25:"BY",28:"-",30:"->",33:"(",34:")",35:"[",37:"]",39:"|",42:"!=",43:"<=",44:"<",45:">=",46:">",47:"NUMBER_LIT",48:"STRING_LIT",50:",",51:"ATTRNAME",52:"WITH",55:"AS",57:"COUNT",58:"SUM",59:"MIN",60:"MAX",63:"DESCENDING",64:"ASCENDING"},
productions_: [0,[3,2],[4,3],[4,0],[6,2],[6,6],[6,4],[6,4],[6,3],[6,3],[9,1],[9,5],[27,3],[27,2],[17,2],[29,3],[31,3],[31,0],[32,4],[32,0],[36,3],[36,1],[38,2],[40,1],[40,1],[40,1],[40,1],[40,1],[40,1],[41,1],[41,1],[21,3],[21,1],[49,2],[23,0],[23,2],[53,1],[53,3],[54,4],[56,1],[56,1],[56,1],[56,1],[26,1],[26,3],[61,2],[61,3],[62,1],[62,1],[14,1]],
performAction: function anonymous(yytext,yyleng,yylineno,yy,yystate,$$,_$) {

var $0 = $$.length - 1;
switch (yystate) {
case 1:return $$[$0-1];
break;
case 2:this.$ = [$$[$0-2]].concat($$[$0]);
break;
case 3:this.$ = [];
break;
case 4:this.$ = {walk:$$[$0]};
break;
case 5:this.$ = {subgraph:[$$[$0-4], $$[$0-1]]};
break;
case 6:this.$ = {let:[$$[$0-2], $$[$0]]};
break;
case 7:name=$$[$0-2].substring(1); this.$ = {look:[name, $$[$0]]};
break;
case 8:name=$$[$0-1].substring(1); this.$ = {aggregate:[name, $$[$0]]};
break;
case 9:this.$ = {orderby:$$[$0]};
break;
case 10:this.$ = [$$[$0]];
break;
case 11:this.$ = [$$[$0-4],$$[$0-2]].concat($$[$0]);
break;
case 12:this.$ = {objectType:$$[$0-2]}; if($$[$0-1])this.$.alias=$$[$0-1]; if($$[$0])this.$.constraint=$$[$0];
break;
case 13:name=$$[$0-1].substring(1); this.$ = {objectRef:name}; if($$[$0])this.$.constraint=$$[$0];
break;
case 14:this.$ = {objectType:$$[$0-1]}; if($$[$0])this.$.constraint=$$[$0];
break;
case 15:this.$ = {linkType:$$[$0-2]}; if($$[$0-1])this.$.alias=$$[$0-1]; if($$[$0])this.$.constraint=$$[$0];
break;
case 16:this.$ = $$[$0-1];
break;
case 17:this.$ = null;
break;
case 18:this.$ = [$$[$0-2]].concat($$[$0]);
break;
case 19:this.$ = [];
break;
case 20:this.$ = [$$[$0-2]].concat($$[$0]);
break;
case 21:this.$ = [$$[$0]];
break;
case 22:this.$ = {rel:$$[$0-1], expr:$$[$0]};
break;
case 29:this.$ = parseFloat($$[$0]);
break;
case 31:this.$ = [$$[$0-2]].concat($$[$0]);
break;
case 32:this.$ = [$$[$0]];
break;
case 33:this.$ = {name:$$[$0-1].substring(1), constraint:$$[$0]};
break;
case 34:this.$ = [];
break;
case 35:this.$ = $$[$0];
break;
case 36:this.$ = [$$[$0]];
break;
case 37:this.$ = [$$[$0-2]].concat($$[$0]);
break;
case 38:this.$ = [$$[$0-3].substring(1), $$[$0-1], $$[$0]];
break;
case 43:this.$ = [$$[$0]];
break;
case 44:this.$ = [$$[$0-2]].concat($$[$0]);
break;
case 45:this.$ = [$$[$0-1].substring(1), null, $$[$0]];
break;
case 46:this.$ = [$$[$0-2].substring(1), $$[$0-1].substring(1), $$[$0]];
break;
case 49:this.$ = $$[$0];
break;
}
},
table: [{3:1,4:2,5:[2,3],6:3,8:[1,4],10:[1,5],16:[1,6],18:[1,7],22:[1,8],24:[1,9]},{1:[3]},{5:[1,10]},{7:[1,11]},{9:12,11:[1,14],19:[1,15],27:13},{11:[1,16]},{11:[1,17]},{19:[1,18]},{19:[1,19]},{25:[1,20]},{1:[2,1]},{4:21,5:[2,3],6:3,8:[1,4],10:[1,5],15:[2,3],16:[1,6],18:[1,7],22:[1,8],24:[1,9]},{7:[2,4]},{7:[2,10],28:[1,22]},{7:[2,17],28:[2,17],31:23,33:[1,24],35:[2,17]},{7:[2,19],28:[2,19],32:25,35:[1,26]},{12:[1,27]},{12:[1,28]},{20:[1,29]},{7:[2,34],23:30,52:[1,31]},{19:[1,34],26:32,61:33},{5:[2,2],15:[2,2]},{11:[1,36],29:35},{7:[2,19],28:[2,19],32:37,35:[1,26]},{11:[1,38]},{7:[2,13],28:[2,13]},{12:[1,42],36:39,38:40,40:41,42:[1,43],43:[1,44],44:[1,45],45:[1,46],46:[1,47]},{13:[1,48]},{11:[1,50],17:49},{21:51,49:52,51:[1,53]},{7:[2,8]},{51:[1,56],53:54,54:55},{7:[2,9]},{7:[2,43],50:[1,57]},{51:[1,59],62:58,63:[1,60],64:[1,61]},{30:[1,62]},{30:[2,17],31:63,33:[1,24],35:[2,17]},{7:[2,12],28:[2,12]},{34:[1,64]},{37:[1,65]},{37:[2,21],39:[1,66]},{41:67,47:[1,68],48:[1,69]},{47:[2,23],48:[2,23]},{47:[2,24],48:[2,24]},{47:[2,25],48:[2,25]},{47:[2,26],48:[2,26]},{47:[2,27],48:[2,27]},{47:[2,28],48:[2,28]},{4:71,6:3,8:[1,4],10:[1,5],14:70,15:[2,3],16:[1,6],18:[1,7],22:[1,8],24:[1,9]},{7:[2,6]},{7:[2,19],32:72,35:[1,26]},{7:[2,7]},{7:[2,32],50:[1,73]},{7:[2,19],32:74,35:[1,26],50:[2,19]},{7:[2,35]},{7:[2,36],50:[1,75]},{55:[1,76]},{19:[1,34],26:77,61:33},{7:[2,45],50:[2,45]},{62:78,63:[1,60],64:[1,61]},{7:[2,47],50:[2,47]},{7:[2,48],50:[2,48]},{9:79,11:[1,14],19:[1,15],27:13},{30:[2,19],32:80,35:[1,26]},{7:[2,16],28:[2,16],30:[2,16],35:[2,16]},{7:[2,19],28:[2,19],30:[2,19],32:81,35:[1,26],50:[2,19]},{12:[1,42],36:82,38:40,40:41,42:[1,43],43:[1,44],44:[1,45],45:[1,46],46:[1,47]},{37:[2,22],39:[2,22]},{37:[2,29],39:[2,29]},{37:[2,30],39:[2,30]},{15:[1,83]},{15:[2,49]},{7:[2,14]},{21:84,49:52,51:[1,53]},{7:[2,33],50:[2,33]},{51:[1,56],53:85,54:55},{56:86,57:[1,87],58:[1,88],59:[1,89],60:[1,90]},{7:[2,44]},{7:[2,46],50:[2,46]},{7:[2,11]},{30:[2,15]},{7:[2,18],28:[2,18],30:[2,18],50:[2,18]},{37:[2,20]},{7:[2,5]},{7:[2,31]},{7:[2,37]},{7:[2,19],32:91,35:[1,26],50:[2,19]},{7:[2,39],35:[2,39],50:[2,39]},{7:[2,40],35:[2,40],50:[2,40]},{7:[2,41],35:[2,41],50:[2,41]},{7:[2,42],35:[2,42],50:[2,42]},{7:[2,38],50:[2,38]}],
defaultActions: {10:[2,1],12:[2,4],30:[2,8],32:[2,9],49:[2,6],51:[2,7],54:[2,35],71:[2,49],72:[2,14],77:[2,44],79:[2,11],80:[2,15],82:[2,20],83:[2,5],84:[2,31],85:[2,37]},
parseError: function parseError(str, hash) {
    throw new Error(str);
},
parse: function parse(input) {
    var self = this, stack = [0], vstack = [null], lstack = [], table = this.table, yytext = "", yylineno = 0, yyleng = 0, recovering = 0, TERROR = 2, EOF = 1;
    this.lexer.setInput(input);
    this.lexer.yy = this.yy;
    this.yy.lexer = this.lexer;
    if (typeof this.lexer.yylloc == "undefined")
        this.lexer.yylloc = {};
    var yyloc = this.lexer.yylloc;
    lstack.push(yyloc);
    if (typeof this.yy.parseError === "function")
        this.parseError = this.yy.parseError;
    function popStack(n) {
        stack.length = stack.length - 2 * n;
        vstack.length = vstack.length - n;
        lstack.length = lstack.length - n;
    }
    function lex() {
        var token;
        token = self.lexer.lex() || 1;
        if (typeof token !== "number") {
            token = self.symbols_[token] || token;
        }
        return token;
    }
    var symbol, preErrorSymbol, state, action, a, r, yyval = {}, p, len, newState, expected;
    while (true) {
        state = stack[stack.length - 1];
        if (this.defaultActions[state]) {
            action = this.defaultActions[state];
        } else {
            if (symbol == null)
                symbol = lex();
            action = table[state] && table[state][symbol];
        }
        if (typeof action === "undefined" || !action.length || !action[0]) {
            if (!recovering) {
                expected = [];
                for (p in table[state])
                    if (this.terminals_[p] && p > 2) {
                        expected.push("'" + this.terminals_[p] + "'");
                    }
                var errStr = "";
                if (this.lexer.showPosition) {
                    errStr = "Parse error on line " + (yylineno + 1) + ":\n" + this.lexer.showPosition() + "\nExpecting " + expected.join(", ") + ", got '" + this.terminals_[symbol] + "'";
                } else {
                    errStr = "Parse error on line " + (yylineno + 1) + ": Unexpected " + (symbol == 1?"end of input":"'" + (this.terminals_[symbol] || symbol) + "'");
                }
                this.parseError(errStr, {text: this.lexer.match, token: this.terminals_[symbol] || symbol, line: this.lexer.yylineno, loc: yyloc, expected: expected});
            }
        }
        if (action[0] instanceof Array && action.length > 1) {
            throw new Error("Parse Error: multiple actions possible at state: " + state + ", token: " + symbol);
        }
        switch (action[0]) {
        case 1:
            stack.push(symbol);
            vstack.push(this.lexer.yytext);
            lstack.push(this.lexer.yylloc);
            stack.push(action[1]);
            symbol = null;
            if (!preErrorSymbol) {
                yyleng = this.lexer.yyleng;
                yytext = this.lexer.yytext;
                yylineno = this.lexer.yylineno;
                yyloc = this.lexer.yylloc;
                if (recovering > 0)
                    recovering--;
            } else {
                symbol = preErrorSymbol;
                preErrorSymbol = null;
            }
            break;
        case 2:
            len = this.productions_[action[1]][1];
            yyval.$ = vstack[vstack.length - len];
            yyval._$ = {first_line: lstack[lstack.length - (len || 1)].first_line, last_line: lstack[lstack.length - 1].last_line, first_column: lstack[lstack.length - (len || 1)].first_column, last_column: lstack[lstack.length - 1].last_column};
            r = this.performAction.call(yyval, yytext, yyleng, yylineno, this.yy, action[1], vstack, lstack);
            if (typeof r !== "undefined") {
                return r;
            }
            if (len) {
                stack = stack.slice(0, -1 * len * 2);
                vstack = vstack.slice(0, -1 * len);
                lstack = lstack.slice(0, -1 * len);
            }
            stack.push(this.productions_[action[1]][0]);
            vstack.push(yyval.$);
            lstack.push(yyval._$);
            newState = table[stack[stack.length - 2]][stack[stack.length - 1]];
            stack.push(newState);
            break;
        case 3:
            return true;
        }
    }
    return true;
}
};/* Jison generated lexer */
var lexer = (function(){

/*
vim:ft=lex
*/

var lexer = ({EOF:1,
parseError:function parseError(str, hash) {
        if (this.yy.parseError) {
            this.yy.parseError(str, hash);
        } else {
            throw new Error(str);
        }
    },
setInput:function (input) {
        this._input = input;
        this._more = this._less = this.done = false;
        this.yylineno = this.yyleng = 0;
        this.yytext = this.matched = this.match = '';
        this.conditionStack = ['INITIAL'];
        this.yylloc = {first_line:1,first_column:0,last_line:1,last_column:0};
        return this;
    },
input:function () {
        var ch = this._input[0];
        this.yytext+=ch;
        this.yyleng++;
        this.match+=ch;
        this.matched+=ch;
        var lines = ch.match(/\n/);
        if (lines) this.yylineno++;
        this._input = this._input.slice(1);
        return ch;
    },
unput:function (ch) {
        this._input = ch + this._input;
        return this;
    },
more:function () {
        this._more = true;
        return this;
    },
pastInput:function () {
        var past = this.matched.substr(0, this.matched.length - this.match.length);
        return (past.length > 20 ? '...':'') + past.substr(-20).replace(/\n/g, "");
    },
upcomingInput:function () {
        var next = this.match;
        if (next.length < 20) {
            next += this._input.substr(0, 20-next.length);
        }
        return (next.substr(0,20)+(next.length > 20 ? '...':'')).replace(/\n/g, "");
    },
showPosition:function () {
        var pre = this.pastInput();
        var c = new Array(pre.length + 1).join("-");
        return pre + this.upcomingInput() + "\n" + c+"^";
    },
next:function () {
        if (this.done) {
            return this.EOF;
        }
        if (!this._input) this.done = true;

        var token,
            match,
            col,
            lines;
        if (!this._more) {
            this.yytext = '';
            this.match = '';
        }
        var rules = this._currentRules();
        for (var i=0;i < rules.length; i++) {
            match = this._input.match(this.rules[rules[i]]);
            if (match) {
                lines = match[0].match(/\n.*/g);
                if (lines) this.yylineno += lines.length;
                this.yylloc = {first_line: this.yylloc.last_line,
                               last_line: this.yylineno+1,
                               first_column: this.yylloc.last_column,
                               last_column: lines ? lines[lines.length-1].length-1 : this.yylloc.last_column + match[0].length}
                this.yytext += match[0];
                this.match += match[0];
                this.matches = match;
                this.yyleng = this.yytext.length;
                this._more = false;
                this._input = this._input.slice(match[0].length);
                this.matched += match[0];
                token = this.performAction.call(this, this.yy, this, rules[i],this.conditionStack[this.conditionStack.length-1]);
                if (token) return token;
                else return;
            }
        }
        if (this._input === "") {
            return this.EOF;
        } else {
            this.parseError('Lexical error on line '+(this.yylineno+1)+'. Unrecognized text.\n'+this.showPosition(), 
                    {text: "", token: null, line: this.yylineno});
        }
    },
lex:function lex() {
        var r = this.next();
        if (typeof r !== 'undefined') {
            return r;
        } else {
            return this.lex();
        }
    },
begin:function begin(condition) {
        this.conditionStack.push(condition);
    },
popState:function popState() {
        return this.conditionStack.pop();
    },
_currentRules:function _currentRules() {
        return this.conditions[this.conditionStack[this.conditionStack.length-1]].rules;
    },
topState:function () {
        return this.conditionStack[this.conditionStack.length-2];
    },
pushState:function begin(condition) {
        this.begin(condition);
    }});
lexer.performAction = function anonymous(yy,yy_,$avoiding_name_collisions,YY_START) {

var YYSTATE=YY_START
switch($avoiding_name_collisions) {
case 0:/* skip whitespace */
break;
case 1:/* skip comment */
break;
case 2:/* skip comment */
break;
case 3:return 7;
break;
case 4:return 50;
break;
case 5:return 33;
break;
case 6:return 34;
break;
case 7:return 35;
break;
case 8:return 37;
break;
case 9:return 39;
break;
case 10:return 12
break;
case 11:return 42
break;
case 12:return 43
break;
case 13:return 45
break;
case 14:return 44
break;
case 15:return 46
break;
case 16:return 13;
break;
case 17:return 15;
break;
case 18:return 30;
break;
case 19:return 28;
break;
case 20:return 8;
break;
case 21:return 10;
break;
case 22:return 18;
break;
case 23:return 20;
break;
case 24:return 16;
break;
case 25:return 22;
break;
case 26:return 52;
break;
case 27:return 55;
break;
case 28:return 24;
break;
case 29:return 25;
break;
case 30:return 63;
break;
case 31:return 64;
break;
case 32:return 57;
break;
case 33:return 58;
break;
case 34:return 59;
break;
case 35:return 60;
break;
case 36:yy_.yytext = yy_.yytext.substr(1,yy_.yyleng-2); return 48;
break;
case 37:return 47;
break;
case 38:return 19;
break;
case 39:return 51;
break;
case 40:return 11;
break;
case 41:return 5;
break;
}
};
lexer.rules = [/^\s+/,/^\/\/[^\n]*/,/^#[^\n]*/,/^;/,/^,/,/^\(/,/^\)/,/^\[/,/^\]/,/^\|/,/^=/,/^!=/,/^<=/,/^>=/,/^</,/^>/,/^\{/,/^\}/,/^->/,/^-/,/^walk\b/,/^subgraph\b/,/^look\b/,/^for\b/,/^let\b/,/^aggregate\b/,/^with\b/,/^as\b/,/^order\b/,/^by\b/,/^desc\b/,/^asc\b/,/^count\b/,/^sum\b/,/^min\b/,/^max\b/,/^"(?:\\["bfnrt/\\]|\\u[a-fA-F0-9]{4}|[^"\\])*"/,/^-?(?:[0-9]|[1-9][0-9]+)(?:\.[0-9]+)?(?:[eE][-+]?[0-9]+)?\b/,/^\$[A-Za-z_][A-Za-z_0-9]*(-[A-Za-z_0-9]+)*(\.[A-Za-z_][A-Za-z_0-9]*(-[A-Za-z_0-9]+)*)*/,/^@([A-Za-z_][A-Za-z_0-9]*(-[A-Za-z_0-9]+)*:)?[A-Za-z_][A-Za-z_0-9]*(-[A-Za-z_0-9]+)*/,/^([A-Za-z_][A-Za-z_0-9]*(-[A-Za-z_0-9]+)*:)?[A-Za-z_][A-Za-z_0-9]*(-[A-Za-z_0-9]+)*/,/^$/];
lexer.conditions = {"INITIAL":{"rules":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41],"inclusive":true}};return lexer;})()
parser.lexer = lexer;
return parser;
})();
if (typeof require !== 'undefined' && typeof exports !== 'undefined') {
exports.parser = syntax;
exports.parse = function () { return syntax.parse.apply(syntax, arguments); }
exports.main = function commonjsMain(args) {
    if (!args[1])
        throw new Error('Usage: '+args[0]+' FILE');
    if (typeof process !== 'undefined') {
        var source = require('fs').readFileSync(require('path').join(process.cwd(), args[1]), "utf8");
    } else {
        var cwd = require("file").path(require("file").cwd());
        var source = cwd.join(args[1]).read({charset: "utf-8"});
    }
    return exports.parser.parse(source);
}
if (typeof module !== 'undefined' && require.main === module) {
  exports.main(typeof process !== 'undefined' ? process.argv.slice(1) : require("system").args);
}
}