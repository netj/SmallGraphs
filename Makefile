# Makefile for SmallGraphs
# Author: Jaeho.Shin@Stanford.EDU
# Created: 2011-12-08

export BINDIR         := bin
export LIBDIR         := lib
export NODEMODULESDIR := $(LIBDIR)/node_modules
export JARDIR         := $(LIBDIR)/java
export SMALLGRAPHSDIR := smallgraphs
export BIGGRAPHDIR    := biggraph
export TOOLSDIR       := tools
export DOCDIR         := doc

STAGEDIR := dist
include buildkit/modules.mk


BUILD_DEPS := \
    coffee-script \
    jison \
    requirejs \
    uglify-js \
    #

.PHONY: check-builddeps

all: check-builddeps

# check builddeps
check-builddeps:
	@type npm jison coffee >/dev/null || { \
	    echo "Please install node.js from http://nodejs.org/#download"; \
	    echo " and the following node packages with \`npm install -g ...\`:"; \
	    for pkg in $(BUILD_DEPS); do echo " $$pkg"; done; \
	    }

publish: all
	# prepare gh-pages/ directory
	[ -d gh-pages ] || git clone --recursive --branch gh-pages git@github.com:netj/SmallGraphs.git gh-pages
	# copy everything built here
	rsync -avcR --delete --delete-excluded \
	    --exclude=*.{coffee,jison{,lex}} --exclude=jquery-ui/development-bundle/ \
	    ui/{index.html,*.less,resource/,jquery-ui/} smallgraph/ \
	    gh-pages/
	# add some submodule git repos, and sync submodule version with the source
	$(call publish-submodule,less.js,      git://github.com/cloudhead/less.js.git)
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

