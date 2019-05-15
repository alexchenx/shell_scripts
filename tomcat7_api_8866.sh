#!/bin/bash

tomcat_home=/data/app/tomcat7-api-8866
tomcat_port=8866

log=$tomcat_home/logs/catalina.out
if [ ! -f ${log} ]; then
        log=$tomcat_home/logs/catalina.`date +%Y-%m-%d`.out
fi
date=`date +%Y-%m-%d\ %H:%M:%S`

# flag value explain:
# 0. tomcat is stopped.
# 1. tomcat is running.
# 2. tomcat is running, but process count more than 1
# 3. tomcat port is closed, but process still running.
flag=0

start() {
        status
        if [ ${flag} -eq 0 ]; then
                ${tomcat_home}/bin/startup.sh
        elif [ ${flag} -eq 1 ]; then
                exit
        elif [ ${flag} -eq 2 ]; then
                exit
        elif [ ${flag} -eq 3 ]; then
                stop
                ${tomcat_home}/bin/startup.sh
        fi
}

stop() {
        status
        if [ ${flag} -ne 0 ]; then
                ${tomcat_home}/bin/shutdown.sh
                sleep 5

                status
                if [ ${flag} -ne 0 ]; then
                        echo "[${date}] tomcat process still running after shutdown.sh, let's kill it."
                        ps aux|grep ${tomcat_home}|grep -v grep|awk '{print $2}'|xargs kill -9
                        sleep 3
                        status
                fi
                if [ ${flag} -eq 0 ]; then
                        echo "[${date}] Clean work cache..."
                        rm -rf $tomcat_home/work/Catalina/*
                        echo "[${date}] Clean cache done."
                        echo "[${date}] tomcat                            [ stopped ]"
                else
                        echo "[${date}] tomcat                            [ failed ]"
                fi
        fi
}

status() {
        count_listen=`netstat -natp|grep ":${tomcat_port}"|grep "LISTEN"|wc -l`
        count_ps=`ps aux|grep "${tomcat_home}"|grep java|grep -v grep|wc -l`

        if [ ${count_listen} == 0 ] && [ ${count_ps} == 0 ]; then
                echo "[${date}] tomcat is stopped."
                flag=0
        elif [ ${count_listen} == 1 ] && [ ${count_ps} -eq 1 ]; then
                echo "[${date}] tomcat is running."
                flag=1
        elif [ ${count_listen} == 1 ] && [ ${count_ps} -ge 1 ]; then
                echo "[{$date}] tomcat is running, but process count more than 1, now is ${count_ps}."
                flag=2
        elif [ ${count_listen} == 0 ] && [ ${count_ps} -ge 1 ]; then
                echo "[${date}] tomcat port is closed, but process still running."
                flag=3
        fi
}

log() {
        echo "log file is: ${log}"
        sleep 1
        tail -20f ${log}
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
