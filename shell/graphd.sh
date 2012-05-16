#!/usr/bin/env bash
# graphd -- GraphD Command-Line Interface
# Usage: graphd COMMAND [ARG]...
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2012-05-08
set -eu

if [ -z "${GRAPHD_HOME:-}" ]; then
    Self=$(readlink -f "$0" 2>/dev/null || {
        # XXX readlink -f is only available in GNU coreutils
        cd $(dirname -- "$0")
        n=$(basename -- "$0")
        if [ -L "$n" ]; then
            L=$(readlink "$n")
            if [ x"$L" = x"${L#/}" ]; then
                echo "$L"; exit
            else
                cd "$(dirname -- "$L")"
                n=$(basename -- "$L")
            fi
        fi
        echo "$(pwd -P)/$n"
    })
    Here=$(dirname "$Self")

    # Setup environment
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
fi


# Process input arguments
[ $# -gt 0 ] || usage "$0" "No COMMAND given"
Cmd=$1; shift


# Check if it's a valid command
exe=graphd-"$Cmd"
if type "$exe" &>/dev/null; then
    set -- "$exe" "$@"
elif backendExe=$(find-backend-specific "$exe"); then
    set -- "$backendExe" "$@"
else
    usage "$0" "$Cmd: invalid COMMAND"
fi


# Run given command under this environment
exec "$@"
