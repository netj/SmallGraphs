cd "`dirname "$0"`/.."
while sleep 0.1; do
    if make; then
        sh -c 'cd graphd;
        coffee graphd.coffee & pid=$! ;
        echo $pid >test.pid;
        wait $pid'
    else
        read
    fi
done
