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
        {$$ = {walk:$2};}
    | SUBGRAPH NAME '=' '{' subgraph '}'
        {$$ = {subgraph:[$NAME, $subgraph]};}
    | LET NAME '=' object
        {$$ = {let:[$NAME, $object]};}
    | LOOK VARREF FOR attributes
        {name=$VARREF.substring(1); $$ = {look:[name, $attributes]};}
    | AGGREGATE VARREF optional_attributeAggregations
        {name=$VARREF.substring(1); $$ = {aggregate:[name, $optional_attributeAggregations]};}
    | ORDER BY orderings
        {$$ = {orderby:$orderings};}
    ;

walk
    : stepObject
        {$$ = [$stepObject];}
    | stepObject '-' stepLink '->' walk
        {$$ = [$stepObject,$stepLink].concat($walk);}
    ;

stepObject
    : NAME optional_alias optional_constraint
        {$$ = {objectType:$1}; if($2)$$.alias=$2; if($3)$$.constraint=$3;}
    | VARREF optional_constraint
        {name=$VARREF.substring(1); $$ = {objectRef:name}; if($2)$$.constraint=$2;}
    ;

object
    : NAME optional_constraint
        {$$ = {objectType:$1}; if($2)$$.constraint=$2;}
    ;

stepLink
    : NAME optional_alias optional_constraint
        {$$ = {linkType:$1}; if($2)$$.alias=$2; if($3)$$.constraint=$3;}
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
        /* TODO */
    ;

attributes
    : ATTRNAME
        {$$ = [$ATTRNAME.substring(1)];}
    | ATTRNAME ',' attributes
        {$$ = [$ATTRNAME.substring(1)].concat($attributes);}
    ;

optional_attributeAggregations
    :
        {$$ = [];}
    | WITH attributeAggregations
        {$$ = $attributeAggregations;}
    ;
attributeAggregations
    : attributeAggregation
        {$$ = [$attributeAggregation];}
    | attributeAggregation ',' attributeAggregations
        {$$ = [$attributeAggregation].concat($attributeAggregations);}
    ;
attributeAggregation
    : ATTRNAME AS aggregation
        {$$ = [$ATTRNAME.substring(1), $aggregation];}
    ;
aggregation
    : COUNT | SUM | MIN | MAX
    ;

orderings
    : ordering
        {$$ = [$ordering];}
    | ordering ',' orderings
        {$$ = [$ordering].concat($orderings);}
    ;

ordering
    : VARREF order
        {$$ = [$VARREF.substring(1), null, $order];}
    | VARREF ATTRNAME order
        {$$ = [$VARREF.substring(1), $ATTRNAME.substring(1), $order];}
    ;

order
    : DESCENDING
    | ASCENDING
    ;

subgraph
    : declarations
        {$$ = $1;}
        /* TODO */
    ;

/*
vim:ft=yacc
*/
