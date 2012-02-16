#!/usr/bin/env bash
set -eu
Self=`readlink -f "$0"`
Base=`dirname "$Self"`

q=$1; shift
! [ -r "$q" ] || q=`cat "$q"`

cd "$Base"

curl -sS --get \
    http://localhost:53411/sgmtest/query \
    --data-urlencode q="$q" | tee test.sgm

./test-view-sgm.sh test.sgm
