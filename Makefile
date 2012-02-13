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
	[ -d gh-pages ] || git clone --recursive --branch gh-pages git@github.com:netj/SmallGraphs.git gh-pages
	# copy everything built here
	rsync -avcR --delete --delete-excluded \
	    --exclude=*.{coffee,jison{,lex}} --exclude=jquery-ui/development-bundle/ \
	    {index.html,resource/,smallgraph/,jquery-ui/} \
	    gh-pages/
	# add some submodule git repos, and sync submodule version with the source
	$(call publish-submodule,d3,           git://github.com/mbostock/d3.git)
	$(call publish-submodule,jquery-svg,   git://github.com/apendleton/jquery-svg.git)
	$(call publish-submodule,jquery-cookie,git://github.com/carhartl/jquery-cookie.git)
	# commit and push to github!
	cd gh-pages && git add . && git add -u && git commit
	cd gh-pages && git push origin gh-pages
define publish-submodule
-cd gh-pages && [ -d $(1) ] || git submodule add $(2)
cd gh-pages/$(1) && git reset --hard $(shell cd $(1) >/dev/null && git rev-parse HEAD)
endef

