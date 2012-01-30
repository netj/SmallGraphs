#!/usr/bin/env bash
# green-marl/match.sh -- Run SmallGraph query with Green-Marl
# Usage: green-marl/match.sh  QUERY_IN_CXX  GRAPH
# 
# QUERY_IN_CXX is a C++ file which implements the following function:
#     #include "match.h"
#     extern "C" {
#     
#     SmallGraphQuery *query() {
#         ...
#     }
#     
#     }
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-01-29
set -eu

Self=`readlink -f "$0"`
Base=`dirname "$Self"`

case `uname` in
    Darwin)
        CXX=clang
        ;;
    *)
        CXX=g++
        ;;
esac


# check arguments
usage() { sed -ne '2,/^#$/ s/^# //p'; exit 1; }
[ $# -eq 2 ] || usage
# This script needs the SmallGraph query compiled into C++ code
QUERY_CC=$1; shift
# and the graph on which it is to be matched
GRAPH=$1; shift

# we need a temporary directory to work in
tmp=`mktemp -d /tmp/smallgraph-greenmarl.XXXXXX`
trap "rm -rf $tmp" EXIT

# link with other precompiled code
"$CXX" -o $tmp/gm_run_sgq -g -Wall -fopenmp "$QUERY_CC" "$Base"/libsmallgraph.so

# run query on given graph
$tmp/gm_run_sgq "$GRAPH"
