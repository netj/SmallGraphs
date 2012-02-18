#!/usr/bin/env bash
set -eu
Self=`readlink -f "$0"`
Base=`dirname "$Self"`

cd "$Base"

sgm=$1; shift

./sgm-qgraph2dot <"$sgm" >test.dot
dot -Tpng -otest.png test.dot

#open test.png
#gvim +"set ft=json fdm=indent fdl=1" "$sgm"
