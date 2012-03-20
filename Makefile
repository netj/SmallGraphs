# Makefile for SmallGraphs
# Author: Jaeho.Shin@Stanford.EDU
# Created: 2011-12-08

BUILD_DEPS := \
    coffee-script \
    jison \
    #
GRAPHD_DEPS := \
    mysql \
    underscore \
    #

.PHONY: all check-builddeps graphd
# build everything
all: check-builddeps
	cd smallgraph && jison syntax.jison{,lex}
	coffee -c .
	cd ./tools/rdfutil && mvn -q compile

# check builddeps
check-builddeps:
	@type npm jison coffee >/dev/null || { \
	    echo "Please install node.js from http://nodejs.org/#download"; \
	    echo " and the following node packages with \`npm install -g ...\`:"; \
	    for pkg in $(BUILD_DEPS); do echo " $$pkg"; done; \
	    }

# run graphd
graphd: all graphd/node_modules
	cd graphd && coffee graphd.coffee

# install graphd dependencies locally
graphd/node_modules:
	mkdir -p $@
	cd graphd && npm install $(GRAPHD_DEPS)
	ln -sfn ../../smallgraph $@/

publish: all
	# prepare gh-pages/ directory
	[ -d gh-pages ] || git clone --recursive --branch gh-pages . gh-pages
	cd gh-pages && git checkout gh-pages
	-cd gh-pages && git remote rm origin && git remote add origin git@github.com:netj/SmallGraphs.git
	# copy everything built here
	rsync -avR --delete --delete-excluded \
	    --exclude=*.{coffee,jison{,lex}} --exclude=jquery-ui/development-bundle/ \
	    index.html resource/ jquery-ui/ smallgraph/ \
	    gh-pages/
	# add some submodule git repos
	-cd gh-pages && [ -d d3            ] || git submodule add git://github.com/mbostock/d3.git
	-cd gh-pages && [ -d jquery-svg    ] || git submodule add git://github.com/apendleton/jquery-svg.git
	-cd gh-pages && [ -d jquery-cookie ] || git submodule add git://github.com/carhartl/jquery-cookie.git
	# TODO sync submodule version with the source
	# commit and push to github!
	cd gh-pages && git add . && git add -u && git commit
	cd gh-pages && git push origin gh-pages

