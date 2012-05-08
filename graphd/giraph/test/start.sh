Self=`readlink -f "$0"`
Here=`dirname "$Self"`

export HADOOP_CONF_DIR="$Here"/hadoop.conf
export HADOOP_OPTS="-Djava.security.krb5.realm= -Djava.security.krb5.kdc="
while sleep 0.1; do
    if make -C "$Here/../../.."; then
        if ! pids=`cat /tmp/hadoop-$LOGNAME-*.pid` || ! ps $pids >/dev/null; then
            start-all.sh
        fi
        sh -c '
        SRCROOT="'"$Here"'"/../../..
        export NODE_PATH="$SRCROOT"/@prefix@/lib/node_modules
        cd "$SRCROOT"/examples/graphs
        node "$NODE_PATH"/graphd & pid=$!
        echo $pid >test.pid
        wait $pid
        '
    else
        read
    fi
done
