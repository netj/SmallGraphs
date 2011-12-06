digit                       [0-9]
esc                         "\\"
int                         "-"?(?:[0-9]|[1-9][0-9]+)
exp                         (?:[eE][-+]?[0-9]+)
frac                        (?:\.[0-9]+)

%%
\s+                                                          /* skip whitespace */
\/\/[^\n]*                                                   /* skip comment */
\#[^\n]*                                                     /* skip comment */
";"                                                          return ';';
"("                                                          return '(';
")"                                                          return ')';
"["                                                          return '[';
"]"                                                          return ']';
"->"                                                         return '->';
"-"                                                          return '-';
"walk"                                                       return 'WALK';
"subgraph"                                                   return 'SUBGRAPH';
"attribute"                                                  return 'ATTRIBUTE';
"aggregate"                                                  return 'AGGREGATE';
"as"                                                         return 'AS';
"count"                                                      return 'COUNT';
"sum"                                                        return '';
\"(?:{esc}["bfnrt/{esc}]|{esc}"u"[a-fA-F0-9]{4}|[^"{esc}])*\"  yytext = yytext.substr(1,yyleng-2); return 'STRING_LIT';
{int}{frac}?{exp}?\b                                         return 'NUMBER_LIT';
\$[A-Za-z_][A-Za-z_0-9]*                                     return 'VARREF';
[A-Za-z_][A-Za-z_0-9]*                                       return 'NAME';
"="                                                          return '='
<<EOF>>                                                      return 'EOF';

%%
/*
vim:ft=lex
*/
