/*
 * SmallGraphs Query Language
 * Author: Jaeho.Shin@Stanford.EDU
 * Created: 2011-12-05
 * 
 * Derived from https://github.com/zaach/orderly.js/blob/master/lib/grammar.y
 */

%{
%}

%%

smallgraph
    : declarations EOF
        {return $1;}
    ;

declarations
    : declaration ';' declarations
        {$$ = [$1].concat($3);}
    |
        {$$ = [];}
    ;

declaration
    : WALK walk
        {$$ = $2;}
    | SUBGRAPH NAME '{' subgraph '}'
        {$$ = $2;}
    | ATTRIBUTE attribute
        {$$ = $2;}
    | NODE NAME '=' object
        {$$ = $2;}
    ;

walk
    : stepObject
        {$$ = [$1];}
    | stepObject '-' stepLink '->' walk
        {$$ = [$1,$3].concat($5);}
    ;

stepObject
    : NAME optional_alias optional_constraint
        {$$ = {objectType:$1}; if($2)$$.alias=$2; if($3)$$.constraint=$3;}
    | VARREF optional_constraint
        {$$ = {alias:$1.substring(1)}; if($2)$$.constraint=$2;}
    ;

stepLink
    : NAME optional_constraint
        {$$ = {linkType:$1}; if($2)$$.constraint=$2;}
    ;

optional_alias
    : '(' NAME ')'
        {$$ = $2;}
    |
        {$$ = null;}
    ;

optional_constraint
    :
        {$$ = null;}
    ;

subgraph
    : 
    ;

attribute
    :
    ;

/*
vim:ft=yacc
*/
