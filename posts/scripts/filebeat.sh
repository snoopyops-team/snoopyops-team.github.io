#!/bin/bash
# rm -rf /opt/filebeat*

cd /usr/local/src
wget https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.8.1-linux-x86_64.tar.gz
tar -zxf filebeat-7.8.1-linux-x86_64.tar.gz -C /opt/
rm -rf /usr/bin/filebeat
ln -s /opt/filebeat-7.8.1-linux-x86_64/ /opt/filebeat
ln -s /opt/filebeat/filebeat /usr/bin/filebeat

###判断是否是systemctl管理,
if hash systemctl 2> /dev/null; then
    if [ -d /usr/lib/systemd/system ];then
    cat > /usr/lib/systemd/system/filebeat.service << \EOF
[Unit]
Description=Filebeat sends log files to Logstash or directly to Elasticsearch.
Documentation=https://www.elastic.co/products/beats/filebeat
Wants=network-online.target
After=network-online.target

[Service]

Environment="BEAT_CONFIG_OPTS=-c /opt/filebeat/beat-kafka.yml"
Environment="BEAT_PATH_OPTS=-path.home /opt/filebeat -path.config /opt/filebeat -path.data /opt/filebeat/data -path.logs /opt/filebeat/logs"
ExecStart=/opt/filebeat/filebeat $BEAT_LOG_OPTS $BEAT_CONFIG_OPTS $BEAT_PATH_OPTS
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    else
        cat > /lib/systemd/system/filebeat.service << \EOF
[Unit]
Description=Filebeat sends log files to Logstash or directly to Elasticsearch.
Documentation=https://www.elastic.co/products/beats/filebeat
Wants=network-online.target
After=network-online.target

[Service]

Environment="BEAT_CONFIG_OPTS=-c /opt/filebeat/beat-kafka.yml"
Environment="BEAT_PATH_OPTS=-path.home /opt/filebeat -path.config /opt/filebeat -path.data /opt/filebeat/data -path.logs /opt/filebeat/logs"
ExecStart=/opt/filebeat/filebeat $BEAT_LOG_OPTS $BEAT_CONFIG_OPTS $BEAT_PATH_OPTS
Restart=always

[Install]
WantedBy=multi-user.target
EOF
    fi
	systemctl daemon-reload && systemctl enable filebeat.service 
	sleep 5s
	systemctl start filebeat.service && systemctl status filebeat.service
else
	cat > /etc/init.d/filebeat << \EOF
#!/bin/bash
#
# filebeat          filebeat shipper
#
# chkconfig: 2345 98 02
# description: Starts and stops a single filebeat instance on this system
#

### BEGIN INIT INFO
# Provides:          filebeat
# Required-Start:    $local_fs $network $syslog
# Required-Stop:     $local_fs $network $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Filebeat sends log files to Logstash or directly to Elasticsearch.
# Description:       Filebeat is a shipper part of the Elastic Beats
#                    family. Please see: https://www.elastic.co/products/beats
### END INIT INFO


PATH=/usr/bin:/sbin:/bin:/usr/sbin
export PATH
agent="/opt/filebeat/filebeat"
args="-c /opt/filebeat/beat-kafka.yml -path.home /opt/filebeat -path.config /opt/filebeat -path.data /opt/filebeat/data -path.logs /opt/filebeat/logs"
start() {
    pid=`ps -ef |grep /opt/filebeat/data |grep -v grep |awk '{print $2}'`
    if [ ! "$pid" ];then
        echo "Starting filebeat: "
        $agent $args &
        if [ $? == '0' ];then
            echo "start filebeat ok"
        else
            echo "start filebeat failed"
        fi
    else
        echo "filebeat is still running!"
        exit
    fi
}
stop() {
    echo -n $"Stopping filebeat: "
    pid=`ps -ef |grep /opt/filebeat/data |grep -v grep |awk '{print $2}'`
    if [ ! "$pid" ];then
echo "filebeat is not running"
    else
        kill $pid
echo "stop filebeat ok"
    fi
}
restart() {
    stop
    start
}
status(){
    pid=`ps -ef |grep /opt/filebeat/data |grep -v grep |awk '{print $2}'`
    if [ ! "$pid" ];then
        echo "filebeat is not running"
    else
        echo "filebeat is running"
    fi
}
case "$1" in
    start)
        start
    ;;
    stop)
        stop
    ;;
    restart)
        restart
    ;;
    status)
        status
    ;;
    *)
        echo $"Usage: $0 {start|stop|restart|status}"
        exit 1
esac
EOF
	chmod 755 /etc/init.d/filebeat
	update-rc.d filebeat defaults || chkconfig --add filebeat
	sleep 2
	#service filebeat start
fi

if [ -d /tmp/configs ];then
  cp -rf /tmp/configs /opt/filebeat/
else
  mkdir -p /opt/filebeat/configs/
fi


cat > /opt/filebeat/beat-kafka.yml << EOF
max_procs: 1
queue.mem:
  events: 256
  flush.min_events: 128
  flush.timeout: 5s

filebeat.config.inputs:
  enabled: true
  path: configs/*.yml

filebeat.inputs:

#================================ Outputs =====================================

#----------------------------- kafka output --------------------------------
output.kafka:
  enabled: true
  hosts: ["10.66.0.102:9092","10.66.1.100:9092","10.66.2.78:9092"]
  topic: 'elk-%{[log_topic]}'
  partition.round_robin:
    reachable_only: false
  required_acks: 1
  compression: gzip
  max_message_bytes: 1000000

#================================ Procesors =====================================

processors:
- rename:
    when:
      equals:
        log_type: "nginx_access_log"
    fields:
       - from: "host.name"
         to: "hostname"
- rename:
    when:
      has_fields: ['json.url']
    fields:
       - from: "json.url"
         to: "json.request_url"
- drop_fields:
    fields: [ "host", "agent", "input", "ecs", "log.offset" ]
EOF