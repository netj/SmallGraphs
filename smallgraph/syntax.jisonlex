digit                       [0-9]
esc                         "\\"
int                         "-"?(?:[0-9]|[1-9][0-9]+)
exp                         (?:[eE][-+]?[0-9]+)
frac                        (?:\.[0-9]+)
alpha                       [A-Za-z_]
alnum                       [A-Za-z_0-9]
QNAME                       {alpha}{alnum}*("-"{alnum}+)*

%%
\s+                                                          /* skip whitespace */
\/\/[^\n]*                                                   /* skip comment */
\#[^\n]*                                                     /* skip comment */
";"                                                          return ';';
","                                                          return ',';
"("                                                          return '(';
")"                                                          return ')';
"["                                                          return '[';
"]"                                                          return ']';
"="                                                          return '='
"!="                                                         return '!='
"<="                                                         return '<='
">="                                                         return '>='
"<"                                                          return '<'
">"                                                          return '>'
"{"                                                          return '{';
"}"                                                          return '}';
"->"                                                         return '->';
"-"                                                          return '-';
"walk"                                                       return 'WALK';
"subgraph"                                                   return 'SUBGRAPH';
"look"                                                       return 'LOOK';
"for"                                                        return 'FOR';
"let"                                                        return 'LET';
"aggregate"                                                  return 'AGGREGATE';
"with"                                                       return 'WITH';
"as"                                                         return 'AS';
"order"                                                      return 'ORDER';
"by"                                                         return 'BY';
"desc"                                                       return 'DESCENDING';
"asc"                                                        return 'ASCENDING';
"count"                                                      return 'COUNT';
"sum"                                                        return 'SUM';
"min"                                                        return 'MIN';
"max"                                                        return 'MAX';
\"(?:{esc}["bfnrt/{esc}]|{esc}"u"[a-fA-F0-9]{4}|[^"{esc}])*\"  yytext = yytext.substr(1,yyleng-2); return 'STRING_LIT';
{int}{frac}?{exp}?\b                                         return 'NUMBER_LIT';
\${alpha}{alnum}*("-"{alnum}+)*(\.{alpha}{alnum}*("-"{alnum}+)*)* return 'VARREF';
"@"({QNAME}":")?{QNAME}                                      return 'ATTRNAME';
({QNAME}":")?{QNAME}                                         return 'NAME';
<<EOF>>                                                      return 'EOF';

%%
/*
vim:ft=lex
*/
