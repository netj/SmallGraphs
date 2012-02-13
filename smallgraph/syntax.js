/* Jison generated parser */
var syntax = (function(){
var parser = {trace: function trace() { },
yy: {},
symbols_: {"error":2,"smallgraph":3,"declarations":4,"EOF":5,"declaration":6,";":7,"WALK":8,"walk":9,"SUBGRAPH":10,"NAME":11,"=":12,"{":13,"subgraph":14,"}":15,"LET":16,"object":17,"LOOK":18,"VARREF":19,"FOR":20,"attributes":21,"AGGREGATE":22,"optional_constraint":23,"optional_attributeAggregations":24,"ORDER":25,"BY":26,"orderings":27,"stepObject":28,"-":29,"stepLink":30,"->":31,"optional_alias":32,"(":33,")":34,"[":35,"constraint_disjunctions":36,"]":37,"constraint":38,"rel":39,"expr":40,"!=":41,"<=":42,"<":43,">=":44,">":45,"NUMBER_LIT":46,"STRING_LIT":47,"attribute":48,",":49,"ATTRNAME":50,"WITH":51,"attributeAggregations":52,"attributeAggregation":53,"AS":54,"aggregation":55,"COUNT":56,"SUM":57,"MIN":58,"MAX":59,"ordering":60,"order":61,"DESCENDING":62,"ASCENDING":63,"$accept":0,"$end":1},
terminals_: {2:"error",5:"EOF",7:";",8:"WALK",10:"SUBGRAPH",11:"NAME",12:"=",13:"{",15:"}",16:"LET",18:"LOOK",19:"VARREF",20:"FOR",22:"AGGREGATE",25:"ORDER",26:"BY",29:"-",31:"->",33:"(",34:")",35:"[",37:"]",41:"!=",42:"<=",43:"<",44:">=",45:">",46:"NUMBER_LIT",47:"STRING_LIT",49:",",50:"ATTRNAME",51:"WITH",54:"AS",56:"COUNT",57:"SUM",58:"MIN",59:"MAX",62:"DESCENDING",63:"ASCENDING"},
productions_: [0,[3,2],[4,3],[4,0],[6,2],[6,6],[6,4],[6,4],[6,4],[6,3],[9,1],[9,5],[28,3],[28,2],[17,2],[30,3],[32,3],[32,0],[23,4],[23,0],[36,3],[36,1],[38,2],[39,1],[39,1],[39,1],[39,1],[39,1],[39,1],[40,1],[40,1],[21,3],[21,1],[48,2],[24,0],[24,2],[52,1],[52,3],[53,4],[55,1],[55,1],[55,1],[55,1],[27,1],[27,3],[60,2],[60,3],[61,1],[61,1],[14,1]],
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
case 8:name=$$[$0-2].substring(1); this.$ = {aggregate:[name, $$[$0], $$[$0-1]]};
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
table: [{3:1,4:2,5:[2,3],6:3,8:[1,4],10:[1,5],16:[1,6],18:[1,7],22:[1,8],25:[1,9]},{1:[3]},{5:[1,10]},{7:[1,11]},{9:12,11:[1,14],19:[1,15],28:13},{11:[1,16]},{11:[1,17]},{19:[1,18]},{19:[1,19]},{26:[1,20]},{1:[2,1]},{4:21,5:[2,3],6:3,8:[1,4],10:[1,5],15:[2,3],16:[1,6],18:[1,7],22:[1,8],25:[1,9]},{7:[2,4]},{7:[2,10],29:[1,22]},{7:[2,17],29:[2,17],32:23,33:[1,24],35:[2,17]},{7:[2,19],23:25,29:[2,19],35:[1,26]},{12:[1,27]},{12:[1,28]},{20:[1,29]},{7:[2,19],23:30,35:[1,26],51:[2,19]},{19:[1,33],27:31,60:32},{5:[2,2],15:[2,2]},{11:[1,35],30:34},{7:[2,19],23:36,29:[2,19],35:[1,26]},{11:[1,37]},{7:[2,13],29:[2,13]},{12:[1,41],36:38,38:39,39:40,41:[1,42],42:[1,43],43:[1,44],44:[1,45],45:[1,46]},{13:[1,47]},{11:[1,49],17:48},{21:50,48:51,50:[1,52]},{7:[2,34],24:53,51:[1,54]},{7:[2,9]},{7:[2,43],49:[1,55]},{50:[1,57],61:56,62:[1,58],63:[1,59]},{31:[1,60]},{31:[2,17],32:61,33:[1,24],35:[2,17]},{7:[2,12],29:[2,12]},{34:[1,62]},{37:[1,63]},{7:[1,64],37:[2,21]},{40:65,46:[1,66],47:[1,67]},{46:[2,23],47:[2,23]},{46:[2,24],47:[2,24]},{46:[2,25],47:[2,25]},{46:[2,26],47:[2,26]},{46:[2,27],47:[2,27]},{46:[2,28],47:[2,28]},{4:69,6:3,8:[1,4],10:[1,5],14:68,15:[2,3],16:[1,6],18:[1,7],22:[1,8],25:[1,9]},{7:[2,6]},{7:[2,19],23:70,35:[1,26]},{7:[2,7]},{7:[2,32],49:[1,71]},{7:[2,19],23:72,35:[1,26],49:[2,19]},{7:[2,8]},{50:[1,75],52:73,53:74},{19:[1,33],27:76,60:32},{7:[2,45],49:[2,45]},{61:77,62:[1,58],63:[1,59]},{7:[2,47],49:[2,47]},{7:[2,48],49:[2,48]},{9:78,11:[1,14],19:[1,15],28:13},{23:79,31:[2,19],35:[1,26]},{7:[2,16],29:[2,16],31:[2,16],35:[2,16]},{7:[2,19],23:80,29:[2,19],31:[2,19],35:[1,26],49:[2,19],51:[2,19]},{12:[1,41],36:81,38:39,39:40,41:[1,42],42:[1,43],43:[1,44],44:[1,45],45:[1,46]},{7:[2,22],37:[2,22]},{7:[2,29],37:[2,29]},{7:[2,30],37:[2,30]},{15:[1,82]},{15:[2,49]},{7:[2,14]},{21:83,48:51,50:[1,52]},{7:[2,33],49:[2,33]},{7:[2,35]},{7:[2,36],49:[1,84]},{54:[1,85]},{7:[2,44]},{7:[2,46],49:[2,46]},{7:[2,11]},{31:[2,15]},{7:[2,18],29:[2,18],31:[2,18],49:[2,18],51:[2,18]},{37:[2,20]},{7:[2,5]},{7:[2,31]},{50:[1,75],52:86,53:74},{55:87,56:[1,88],57:[1,89],58:[1,90],59:[1,91]},{7:[2,37]},{7:[2,19],23:92,35:[1,26],49:[2,19]},{7:[2,39],35:[2,39],49:[2,39]},{7:[2,40],35:[2,40],49:[2,40]},{7:[2,41],35:[2,41],49:[2,41]},{7:[2,42],35:[2,42],49:[2,42]},{7:[2,38],49:[2,38]}],
defaultActions: {10:[2,1],12:[2,4],31:[2,9],48:[2,6],50:[2,7],53:[2,8],69:[2,49],70:[2,14],73:[2,35],76:[2,44],78:[2,11],79:[2,15],81:[2,20],82:[2,5],83:[2,31],86:[2,37]},
parseError: function parseError(str, hash) {
    throw new Error(str);
},
parse: function parse(input) {
    var self = this,
        stack = [0],
        vstack = [null], // semantic value stack
        lstack = [], // location stack
        table = this.table,
        yytext = '',
        yylineno = 0,
        yyleng = 0,
        recovering = 0,
        TERROR = 2,
        EOF = 1;

    //this.reductionCount = this.shiftCount = 0;

    this.lexer.setInput(input);
    this.lexer.yy = this.yy;
    this.yy.lexer = this.lexer;
    if (typeof this.lexer.yylloc == 'undefined')
        this.lexer.yylloc = {};
    var yyloc = this.lexer.yylloc;
    lstack.push(yyloc);

    if (typeof this.yy.parseError === 'function')
        this.parseError = this.yy.parseError;

    function popStack (n) {
        stack.length = stack.length - 2*n;
        vstack.length = vstack.length - n;
        lstack.length = lstack.length - n;
    }

    function lex() {
        var token;
        token = self.lexer.lex() || 1; // $end = 1
        // if token isn't its numeric value, convert
        if (typeof token !== 'number') {
            token = self.symbols_[token] || token;
        }
        return token;
    }

    var symbol, preErrorSymbol, state, action, a, r, yyval={},p,len,newState, expected;
    while (true) {
        // retreive state number from top of stack
        state = stack[stack.length-1];

        // use default actions if available
        if (this.defaultActions[state]) {
            action = this.defaultActions[state];
        } else {
            if (symbol == null)
                symbol = lex();
            // read action for current state and first input
            action = table[state] && table[state][symbol];
        }

        // handle parse error
        _handle_error:
        if (typeof action === 'undefined' || !action.length || !action[0]) {

            if (!recovering) {
                // Report error
                expected = [];
                for (p in table[state]) if (this.terminals_[p] && p > 2) {
                    expected.push("'"+this.terminals_[p]+"'");
                }
                var errStr = '';
                if (this.lexer.showPosition) {
                    errStr = 'Parse error on line '+(yylineno+1)+":\n"+this.lexer.showPosition()+"\nExpecting "+expected.join(', ') + ", got '" + this.terminals_[symbol]+ "'";
                } else {
                    errStr = 'Parse error on line '+(yylineno+1)+": Unexpected " +
                                  (symbol == 1 /*EOF*/ ? "end of input" :
                                              ("'"+(this.terminals_[symbol] || symbol)+"'"));
                }
                this.parseError(errStr,
                    {text: this.lexer.match, token: this.terminals_[symbol] || symbol, line: this.lexer.yylineno, loc: yyloc, expected: expected});
            }

            // just recovered from another error
            if (recovering == 3) {
                if (symbol == EOF) {
                    throw new Error(errStr || 'Parsing halted.');
                }

                // discard current lookahead and grab another
                yyleng = this.lexer.yyleng;
                yytext = this.lexer.yytext;
                yylineno = this.lexer.yylineno;
                yyloc = this.lexer.yylloc;
                symbol = lex();
            }

            // try to recover from error
            while (1) {
                // check for error recovery rule in this state
                if ((TERROR.toString()) in table[state]) {
                    break;
                }
                if (state == 0) {
                    throw new Error(errStr || 'Parsing halted.');
                }
                popStack(1);
                state = stack[stack.length-1];
            }

            preErrorSymbol = symbol; // save the lookahead token
            symbol = TERROR;         // insert generic error symbol as new lookahead
            state = stack[stack.length-1];
            action = table[state] && table[state][TERROR];
            recovering = 3; // allow 3 real symbols to be shifted before reporting a new error
        }

        // this shouldn't happen, unless resolve defaults are off
        if (action[0] instanceof Array && action.length > 1) {
            throw new Error('Parse Error: multiple actions possible at state: '+state+', token: '+symbol);
        }

        switch (action[0]) {

            case 1: // shift
                //this.shiftCount++;

                stack.push(symbol);
                vstack.push(this.lexer.yytext);
                lstack.push(this.lexer.yylloc);
                stack.push(action[1]); // push state
                symbol = null;
                if (!preErrorSymbol) { // normal execution/no error
                    yyleng = this.lexer.yyleng;
                    yytext = this.lexer.yytext;
                    yylineno = this.lexer.yylineno;
                    yyloc = this.lexer.yylloc;
                    if (recovering > 0)
                        recovering--;
                } else { // error just occurred, resume old lookahead f/ before error
                    symbol = preErrorSymbol;
                    preErrorSymbol = null;
                }
                break;

            case 2: // reduce
                //this.reductionCount++;

                len = this.productions_[action[1]][1];

                // perform semantic action
                yyval.$ = vstack[vstack.length-len]; // default to $$ = $1
                // default location, uses first token for firsts, last for lasts
                yyval._$ = {
                    first_line: lstack[lstack.length-(len||1)].first_line,
                    last_line: lstack[lstack.length-1].last_line,
                    first_column: lstack[lstack.length-(len||1)].first_column,
                    last_column: lstack[lstack.length-1].last_column
                };
                r = this.performAction.call(yyval, yytext, yyleng, yylineno, this.yy, action[1], vstack, lstack);

                if (typeof r !== 'undefined') {
                    return r;
                }

                // pop off stack
                if (len) {
                    stack = stack.slice(0,-1*len*2);
                    vstack = vstack.slice(0, -1*len);
                    lstack = lstack.slice(0, -1*len);
                }

                stack.push(this.productions_[action[1]][0]);    // push nonterminal (reduce)
                vstack.push(yyval.$);
                lstack.push(yyval._$);
                // goto new state = table[STATE][NONTERMINAL]
                newState = table[stack[stack.length-2]][stack[stack.length-1]];
                stack.push(newState);
                break;

            case 3: // accept
                return true;
        }

    }

    return true;
}};

/* Jison generated lexer */
var lexer = (function(){
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
            tempMatch,
            index,
            col,
            lines;
        if (!this._more) {
            this.yytext = '';
            this.match = '';
        }
        var rules = this._currentRules();
        for (var i=0;i < rules.length; i++) {
            tempMatch = this._input.match(this.rules[rules[i]]);
            if (tempMatch && (!match || tempMatch[0].length > match[0].length)) {
                match = tempMatch;
                index = i;
                if (!this.options.flex) break;
            }
        }
        if (match) {
            lines = match[0].match(/\n.*/g);
            if (lines) this.yylineno += lines.length;
            this.yylloc = {first_line: this.yylloc.last_line,
                           last_line: this.yylineno+1,
                           first_column: this.yylloc.last_column,
                           last_column: lines ? lines[lines.length-1].length-1 : this.yylloc.last_column + match[0].length}
            this.yytext += match[0];
            this.match += match[0];
            this.yyleng = this.yytext.length;
            this._more = false;
            this._input = this._input.slice(match[0].length);
            this.matched += match[0];
            token = this.performAction.call(this, this.yy, this, rules[index],this.conditionStack[this.conditionStack.length-1]);
            if (token) return token;
            else return;
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
lexer.options = {};
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
case 4:return 49;
break;
case 5:return 33;
break;
case 6:return 34;
break;
case 7:return 35;
break;
case 8:return 37;
break;
case 9:return 12
break;
case 10:return 41
break;
case 11:return 42
break;
case 12:return 44
break;
case 13:return 43
break;
case 14:return 45
break;
case 15:return 13;
break;
case 16:return 15;
break;
case 17:return 31;
break;
case 18:return 29;
break;
case 19:return 8;
break;
case 20:return 10;
break;
case 21:return 18;
break;
case 22:return 20;
break;
case 23:return 16;
break;
case 24:return 22;
break;
case 25:return 51;
break;
case 26:return 54;
break;
case 27:return 25;
break;
case 28:return 26;
break;
case 29:return 62;
break;
case 30:return 63;
break;
case 31:return 56;
break;
case 32:return 57;
break;
case 33:return 58;
break;
case 34:return 59;
break;
case 35:yy_.yytext = yy_.yytext.substr(1,yy_.yyleng-2); return 47;
break;
case 36:return 46;
break;
case 37:return 19;
break;
case 38:return 50;
break;
case 39:return 11;
break;
case 40:return 5;
break;
}
};
lexer.rules = [/^\s+/,/^\/\/[^\n]*/,/^#[^\n]*/,/^;/,/^,/,/^\(/,/^\)/,/^\[/,/^\]/,/^=/,/^!=/,/^<=/,/^>=/,/^</,/^>/,/^\{/,/^\}/,/^->/,/^-/,/^walk\b/,/^subgraph\b/,/^look\b/,/^for\b/,/^let\b/,/^aggregate\b/,/^with\b/,/^as\b/,/^order\b/,/^by\b/,/^desc\b/,/^asc\b/,/^count\b/,/^sum\b/,/^min\b/,/^max\b/,/^"(?:\\["bfnrt/\\]|\\u[a-fA-F0-9]{4}|[^"\\])*"/,/^-?(?:[0-9]|[1-9][0-9]+)(?:\.[0-9]+)?(?:[eE][-+]?[0-9]+)?\b/,/^\$[A-Za-z_][A-Za-z_0-9]*(-[A-Za-z_0-9]+)*(\.[A-Za-z_][A-Za-z_0-9]*(-[A-Za-z_0-9]+)*)*/,/^@([A-Za-z_][A-Za-z_0-9]*(-[A-Za-z_0-9]+)*:)?[A-Za-z_][A-Za-z_0-9]*(-[A-Za-z_0-9]+)*/,/^([A-Za-z_][A-Za-z_0-9]*(-[A-Za-z_0-9]+)*:)?[A-Za-z_][A-Za-z_0-9]*(-[A-Za-z_0-9]+)*/,/^$/];
lexer.conditions = {"INITIAL":{"rules":[0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40],"inclusive":true}};

/*
vim:ft=lex
*/
;
return lexer;})()
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