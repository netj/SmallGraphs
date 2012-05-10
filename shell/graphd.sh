#!/usr/bin/env bash
# graphd -- GraphD Command-Line Interface
# Usage: graphd COMMAND [ARG]...
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-05-08
set -eu

Self=$(readlink -f "$0")
Here=$(dirname "$Self")

# Setup some environment
export GRAPHD_HOME=${Here%/@BINDIR@}
export BINDIR="$GRAPHD_HOME/@BINDIR@"
export LIBDIR="$GRAPHD_HOME/@LIBDIR@"
export JARDIR="$GRAPHD_HOME/@JARDIR@"
export NODEMODULESDIR="$GRAPHD_HOME/@NODEMODULESDIR@"
export TOOLSDIR="$GRAPHD_HOME/@TOOLSDIR@"
export GRAPHDDIR="$GRAPHD_HOME/@GRAPHDDIR@"
export SMALLGRAPHSDIR="$GRAPHD_HOME/@SMALLGRAPHSDIR@"
export RUNDIR="$GRAPHD_HOME/@DATADIR@"
export DOCDIR="$GRAPHD_HOME/@DOCDIR@"

export PATH="$TOOLSDIR:$PATH"
unset CDPATH
export NODE_PATH="$GRAPHD_HOME/node_modules${NODE_PATH:+:$NODE_PATH}"


# Process input arguments
[ $# -gt 0 ] || usage "$0" "No COMMAND given"
Cmd=$1; shift


# Check it is a valid command
exe=graphd-"$Cmd"
if type "$exe" &>/dev/null; then
    set -- "$exe" "$@"
else
    error "$Cmd: Unknown graphd command" || true
    echo "Try \`graphd help' for usage."
    false
fi


# Run given command under this environment
exec "$@"
