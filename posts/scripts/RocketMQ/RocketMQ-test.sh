#!/bin/bash
##################################
# Date:   2021/04/26 10:27
# Author: zhonghuak
# Email:  kangzhonghua@mobimagic.com
# 单机部署rocketmq单master
##################################

source /etc/profile

PORT=8081
CLUSTERNAME=hwei-ng-em-mp-test-1

# ### 判断是否已经安装rocketmq
# [ -d /work/rocketmq ] && echo "rocketmq is alreday exists" && exit 1

# ### 判断是否安装java
hash java
JAVA_RET=$?
if [ ${JAVA_RET} -ne 0 ];then
    echo "The deploy is failed~~~"
    echo "please deploy java!!!!!"
    exit 255
fi


### 判断是否为空
if [ x${CLUSTERNAME} == x'' ];then
    echo "集群名字不可为空"
    exit 255
fi

IP=`ifconfig |grep 'inet '|awk {'print $2'}|grep -v '127.0.0.1'|cut -d: -f2`

#删除旧的环境
# rm -rf /etc/supervisord.d/*
# supervisorctl update
# cd /work/rocketmq/bin && sh mqshutdown broker
# cd /work/rocketmq/bin && sh mqshutdown namesrv
# sleep 2s
# rm -rf /work/rocketmq*
# rm -rf /work/rocketmq-externals

# 下载软件，并修改家目录为/work/rocketmq
cd /usr/local/src/
wget https://africa-sa-ops-tools.obs.af-south-1.myhuaweicloud.com/software/rocketmq-all-4.7.1-bin-release.zip
unzip rocketmq-all-4.7.1-bin-release.zip -d /work/
ln -s /work/rocketmq-all-4.7.1-bin-release/ /work/rocketmq
cd /work/rocketmq && mkdir logs &&  mkdir -pv store/{commitlog,consumequeue,index}
cd /work/rocketmq/conf && sed -i 's#${user.home}#/work/rocketmq#g' *.xml

#测试环境修改启动参数，使用较少内存

cd /work/rocketmq/bin
sed -i 's@-Xms4g -Xmx4g -Xmn2g@-Xms256m -Xmx256m -Xmn128m@g' runserver.sh
sed -i 's@-Xms8g -Xmx8g -Xmn4g@-Xms256m -Xmx256m -Xmn128m@g' runbroker.sh
sed -i 's@-Xms1g -Xmx1g -Xmn256m@-Xms256m -Xmx256m -Xmn128m@g' tools.sh

# 部署namesrv
cat > /etc/supervisord.d/rocketmq-namesrv.ini << EOF
[program:rocketmq-namesrv]
command=sh bin/mqnamesrv
process_name=%(program_name)s
directory=/work/rocketmq/
numprocs=1
startsecs=5
stopsignal=TERM
stopwaitsecs=15
autostart=true
autorestart=true
redirect_stderr=true
user=root
group=root
redirect_stderr=true
stdout_logfile_maxbytes=50MB   ; max # logfile bytes b4 rotation (default 50MB)
stdout_logfile_backups=10 ; # of stdout logfile backups (default 10)
stdout_logfile=/work/logs/supervisord/rocketmq-namesrv.log
stderr_logfile_maxbytes=50MB
stderr_logfile_backups=10
stderr_logfile=/work/logs/supervisord/rocketmq-namesrv.log
minfds=65535
minprocs=32700
environment=JAVA_HOME=${JAVA_HOME}
EOF

mkdir -p /work/logs/supervisord

supervisorctl update
sleep 5s
# 部署broker
mv /work/rocketmq/conf/broker.conf /work/rocketmq/conf/broker.conf.default

cat > /work/rocketmq/conf/broker.conf << EOF
brokerClusterName=${CLUSTERNAME}
brokerName=broker-a
brokerId=0
namesrvAddr=${IP}:9876
defaultTopicQueueNums=4
deleteWhen=04
fileReservedTime=120
mapedFileSizeCommitLog=1073741824
mapedFileSizeConsumeQueue=300000
diskMaxUsedSpaceRatio=88
storePathRootDir=/work/rocketmq/store
storePathCommitLog=/work/rocketmq/store/commitlog
storePathConsumeQueue=/work/rocketmq/store/consumequeue
storePathIndex=/work/rocketmq/store/index
storeCheckpoint=/work/rocketmq/store/checkpoint
abortFile=/work/rocketmq/store/abort
maxMessageSize=65536
brokerRole=ASYNC_MASTER
flushDiskType=ASYNC_FLUSH
EOF

cat > /etc/supervisord.d/rocketmq-broker.ini << EOF
[program:rocketmq-broker]
command=sh bin/mqbroker -c /work/rocketmq/conf/broker.conf
process_name=%(program_name)s
directory=/work/rocketmq/
numprocs=1
startsecs=5
stopsignal=TERM
stopwaitsecs=15
autostart=true
autorestart=true
redirect_stderr=true
user=root
group=root
redirect_stderr=true
stdout_logfile_maxbytes=50MB   ; max # logfile bytes b4 rotation (default 50MB)
stdout_logfile_backups=10 ; # of stdout logfile backups (default 10)
stdout_logfile=/work/logs/supervisord/rocketmq-broker.log
stderr_logfile_maxbytes=50MB
stderr_logfile_backups=10
stderr_logfile=/work/logs/supervisord/rocketmq-broker.log
minfds=65535
minprocs=32700
environment=JAVA_HOME=${JAVA_HOME}
EOF

supervisorctl update

# 安装maven
RET=0
hash mvn || RET=$?

if [ $RET != 0 ];then
    cd /usr/local/src/
    wget https://africa-sa-ops-tools.obs.af-south-1.myhuaweicloud.com/software/apache-maven-3.3.9-bin.tar.gz
    tar -xvf  apache-maven-3.3.9-bin.tar.gz -C /opt
    cd /opt/
    ln -s apache-maven-3.3.9 apache-maven
fi

cat >> /etc/profile << \EOF
export MAVEN_HOME=/opt/apache-maven
export PATH=${PATH}:${MAVEN_HOME}/bin
EOF

set +x
source /etc/profile
set -x

RET=0
hash mvn || RET=$?

if [ $RET != 0 ];then
    echo "mvn deploy is failed ,check please!!!!"
    exit 255
else
    mvn -v
fi



# 部署rocketmq-console
RET=0
cd /usr/local/src && git clone https://github.com/apache/rocketmq-externals.git
cd /usr/local/src/rocketmq-externals && git checkout 2c07ce598199e051d2dfc75800308096c941bab7
mv /usr/local/src/rocketmq-externals/ /work/
cd /work/rocketmq-externals/rocketmq-console/src/main/resources/ 
cp logback.xml logback.xml.default

# 写入新的logback.xml 将日志写到指定目录下
cat > /work/rocketmq-externals/rocketmq-console/src/main/resources/logback.xml << "EOF"
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
        <appender name="STDOUT" class="ch.qos.logback.core.ConsoleAppender">
                <encoder charset="UTF-8">
                        <pattern>[%d{yyyy-MM-dd HH:mm:ss.SSS}] %5p %m%n</pattern>
                </encoder>
        </appender>

        <appender name="FILE"
                class="ch.qos.logback.core.rolling.RollingFileAppender">
                <file>${user.home}/logs/consolelogs/rocketmq-console.log</file>
                <append>true</append>
                <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
                        <fileNamePattern>${user.home}/logs/consolelogs/rocketmq-console-%d{yyyy-MM-dd}.%i.log
                        </fileNamePattern>
                        <timeBasedFileNamingAndTriggeringPolicy
                                class="ch.qos.logback.core.rolling.SizeAndTimeBasedFNATP">
                                <maxFileSize>104857600</maxFileSize>
                        </timeBasedFileNamingAndTriggeringPolicy>
                        <MaxHistory>10</MaxHistory>
                </rollingPolicy>
                <encoder>
                        <pattern>[%d{yyyy-MM-dd HH:mm:ss.SSS}] %5p %m%n</pattern>
                        <charset class="java.nio.charset.Charset">UTF-8</charset>
                </encoder>
        </appender>

    <appender name="RocketmqClientAppender"
            class="ch.qos.logback.core.rolling.RollingFileAppender">
                <file>${user.home}/logs/consolelogs/rocketmq_client.log</file>
                <append>true</append>
                <rollingPolicy class="ch.qos.logback.core.rolling.TimeBasedRollingPolicy">
                        <fileNamePattern>${user.home}/logs/consolelogs/rocketmq_client.%d{yyyyMMdd}.%i.log</fileNamePattern>
                        <timeBasedFileNamingAndTriggeringPolicy
                                        class="ch.qos.logback.core.rolling.SizeAndTimeBasedFNATP">
                                <maxFileSize>104857600</maxFileSize>
                        </timeBasedFileNamingAndTriggeringPolicy>
                        <MaxHistory>10</MaxHistory>
                </rollingPolicy>
                <encoder>
                        <pattern>[%d{yyyy-MM-dd HH:mm:ss.SSS}] %5p %m%n</pattern>
                        <charset class="java.nio.charset.Charset">UTF-8</charset>
                </encoder>
        </appender>

        <logger name="RocketmqClient" additivity="false">
                <level value="warn" />
                <appender-ref ref="RocketmqClientAppender"/>
        </logger>

        <root level="INFO">
                <appender-ref ref="STDOUT" />
                <appender-ref ref="FILE" />
        </root>

</configuration> 
EOF
sed -i 's#${user.home}#/work/rocketmq#g' logback.xml
cd /work/rocketmq-externals/rocketmq-console/ && mvn clean package -Dmaven.test.skip=true


RET=$?

if [ $RET != 0 ];then
    echo "rocketmq-console compile is failed ,check please!!!!"
    exit 255
else
    echo "rocketmq-console compile is success!!!"
fi

CONSOLE_JAR=`cd /work/rocketmq-externals/rocketmq-console/target;ls *.jar`

cat > /etc/supervisord.d/rocketmq-console.ini << EOF
[program:rocketmq-console]
command=${JAVA_HOME}/bin/java -Drocketmq.client.logUseSlf4j=true -jar ${CONSOLE_JAR} --server.port=${PORT} --rocketmq.config.namesrvAddr=${IP}:9876 
process_name=%(program_name)s
directory=/work/rocketmq-externals/rocketmq-console/target/
numprocs=1
startsecs=5
stopsignal=TERM
stopwaitsecs=15
autostart=true
autorestart=true
redirect_stderr=true
user=root
group=root
redirect_stderr=true
stdout_logfile_maxbytes=50MB   ; max # logfile bytes b4 rotation (default 50MB)
stdout_logfile_backups=10 ; # of stdout logfile backups (default 10)
stdout_logfile=/work/logs/supervisord/rocketmq-console.log
stderr_logfile_maxbytes=50MB
stderr_logfile_backups=10
stderr_logfile=/work/logs/supervisord/rocketmq-console.log
minfds=65535
minprocs=32700
environment=JAVA_HOME=${JAVA_HOME}
EOF

supervisorctl update
sleep 10s
supervisorctl status
