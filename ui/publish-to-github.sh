#!/usr/bin/env bash
set -eu

Self=`readlink -f "$0"`
Here=`dirname "$Self"`

cd "$Here"

# make sure UI is built
make -C ..

# prepare gh-pages/ directory
[ -d gh-pages ] || git clone --branch gh-pages git@github.com:netj/SmallGraphs.git gh-pages

# copy everything built here
rsync -avc --delete --exclude=/.git \
    ../@prefix@/smallgraphs/. gh-pages/.

# add changes, commit
cd gh-pages

grep -v "<base .*>" <index.html >index.html.fix
mv -f index.html.fix index.html

git add .
git add -u
git commit

# and push to github!
git push origin gh-pages
