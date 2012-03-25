#!/usr/bin/env bash
set -eu

Self=`readlink -f "$0"`
Here=`dirname "$Self"`

cd "$Here"

# make sure UI is built
[ -d ../dist/smallgraphs ] || make -C ..

# prepare gh-pages/ directory
[ -d gh-pages ] || git clone --branch gh-pages git@github.com:netj/SmallGraphs.git gh-pages

# copy everything built here
rsync -avc --delete --exclude=/.git \
    ../dist/smallgraphs/. gh-pages/.

# add changes, commit
cd gh-pages
git add .
git add -u
git commit

# and push to github!
git push origin gh-pages
