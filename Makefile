# Makefile for SmallGraphs
# Author: Jaeho.Shin@Stanford.EDU
# Created: 2011-12-08

BUILD_DEPS := \
    coffee-script \
    jison \
    #
GRAPHD_DEPS := \
    mysql \
    #

.PHONY: all check-builddeps graphd
# build everything
all: check-builddeps
	cd smallgraph && jison syntax.jison{,lex}
	coffee -c .

# check builddeps
check-builddeps:
	@type npm jison coffee >/dev/null || { \
	    echo "Please install node.js from http://nodejs.org/#download"; \
	    echo " and the following node packages with \`npm install -g ...\`:"; \
	    for pkg in $(BUILD_DEPS); do echo " $$pkg"; done; \
	    }

# run graphd
graphd: graphd/node_modules
	cd graphd && coffee graphd.coffee

# install graphd dependencies locally
graphd/node_modules:
	mkdir -p $@
	cd graphd && npm install $(GRAPHD_DEPS)

