#!/bin/bash

mongo_home=/data/app/mongodb3.2/mongodb-linux-x86_64-amazon-3.2.21
mongo_config=/data/app/mongodb3.2/etc/mongodb.conf
mongo_pid=/data/app/mongodb3.2/mongodb.pid

start() {
        echo "never" > /sys/kernel/mm/transparent_hugepage/enabled
        echo "never" > /sys/kernel/mm/transparent_hugepage/defrag
        su - mongo -c "$mongo_home/bin/mongod -f $mongo_config"
}

stop() {
        su - mongo -c "cat $mongo_pid | xargs kill -2"
}

case "$1" in
        start)
                start
                ;;
        stop)
                stop
                ;;
        restart)
                stop
                start
                ;;
        *)
                echo $"Usage: $0 {start|stop|restart}"
                exit 2
esac
