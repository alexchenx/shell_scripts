#!/bin/bash

tomcat_home=/data/app/tomcat7-api-8866
tomcat_name=tomcat7-api-8866
tomcat_port=8866

watchlog=$tomcat_home/logs/catalina.out
date=`date +%Y-%m-%d-%H:%M:%S`


flag=0

start() {
        status
        if [ $flag -eq 1 ]; then
                exit
        elif [ $flag -eq 2 ]; then
                stop
                $tomcat_home/bin/startup.sh
        else
                $tomcat_home/bin/startup.sh
        fi
}

stop() {
        status
        if [ $flag -ne 0 ]; then
                $tomcat_home/bin/shutdown.sh
                sleep 5

                status
                if [ $flag -ne 0 ]; then
                        echo "[$date] tomcat process not dead after shutdown.sh, let's kill it."
                        ps aux|grep $tomcat_name|grep -v grep|awk '{print $2}'|xargs kill -9
                        sleep 5
                        status
                        if [ $flag -eq 0 ]; then
                                echo "[$date] tomcat                            [ stoped ]"
                        else
                                echo "[$date] tomcat                            [ failed ]"

                        fi
                        echo "[$date] Clean work cache..."
                        rm -rf $tomcat_home/work/Catalina/*
                
                        echo "[$date] Clean cache done."
                fi
        fi
}

status() {
        count_listen=`netstat -natp|grep $tomcat_port|grep "LISTEN"|wc -l`
        count_ps=`ps aux|grep $tomcat_name|grep java|grep -v grep|wc -l`

        if [ $count_listen == 0 ] && [ $count_ps == 0 ]; then
                echo "[$date] tomcat is stopped."
                flag=0
        elif [ $count_listen == 1 ] && [ $count_ps -eq 1 ]; then
                echo "[$date] tomcat is running."
                flag=1
        elif [ $count_listen == 0 ] && [ $count_ps -ge 1 ]; then
                echo "[$date] tomcat port is closed, but process still running."
                flag=2
        fi
}

log() {
        echo "log file is: $watchlog"
        sleep 1
        tail -20f $watchlog
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
        status)
                status
                ;;
        log)
                log
                ;;
        *)
                echo $"Usage: $0 {start|stop|status|log|restart}"
esac
