# Makefile for SmallGraphs
# Author: netj@cs.stanford.edu
# Created: 2011-12-08

export PATH := $(PWD)/node_modules/.bin:$(PATH)
export CDPATH :=

export BINDIR         := bin
export LIBDIR         := lib
export JARDIR         := $(LIBDIR)/java
export NODEMODULESDIR := $(LIBDIR)/node_modules
export TOOLSDIR       := tools
export GRAPHDDIR      := $(NODEMODULESDIR)/graphd
export SMALLGRAPHSDIR := smallgraphs
export RUNDIR         := run
export DOCDIR         := doc

#PACKAGEEXECUTES:=bin/graphd

STAGEDIR := @prefix@
include buildkit/modules.mk

polish: links
links:
	mkdir -p $(STAGEDIR)/$(GRAPHDDIR)/public
	ln -s ../../../../smallgraphs $(STAGEDIR)/$(GRAPHDDIR)/public/

# TODO need to take this dependency into account somehow with BuildKit
shell/.module.build: Makefile

.PHONY: check-builddeps publish

build: check-builddeps

# check builddeps
check-builddeps:
	@npm install || { \
	    echo "You need node.js and npm to build GraphD and SmallGraphs"; \
	    false; \
	    } >&2 \
	    #

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

