#!/bin/bash
##################################
# 2m2s部署rocketmq集群
# 需要先安装jdk环境
# broker-b-s
##################################

# 配置参数
CLUSTERNAME=okash-middle-prod
ip_1=10.116.2.224
ip_2=10.116.2.225

# ### 判断是否安装java
hash java
JAVA_RET=$?
if [ ${JAVA_RET} -ne 0 ];then
    echo "The deploy is failed~~~"
    echo "please deploy java!!!!!"
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
wget https://archive.apache.org/dist/rocketmq/4.7.1/rocketmq-all-4.7.1-bin-release.zip
unzip rocketmq-all-4.7.1-bin-release.zip -d /work/
ln -s /work/rocketmq-all-4.7.1-bin-release/ /work/rocketmq
cd /work/rocketmq && mkdir logs &&  mkdir -pv store/{commitlog,consumequeue,index}
cd /work/rocketmq/conf && sed -i 's#${user.home}#/work/rocketmq#g' *.xml

cd /work/rocketmq/bin
sed -i 's@-Xms8g -Xmx8g -Xmn4g@-Xms4g -Xmx4g -Xmn1g@g' runbroker.sh

sleep 30s
# 创建日志目录
mkdir -p /work/logs/supervisord/
cat > /work/rocketmq/conf/2m-2s-async/broker-b-s.properties << EOF
brokerClusterName=${CLUSTERNAME}
brokerName=broker-b
brokerId=1
namesrvAddr=${ip_1}:9876;${ip_2}:9876
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
fileReservedTime=48
brokerRole=SLAVE
flushDiskType=ASYNC_FLUSH
EOF
#部署supervisorctl 配置文件
cat > /etc/supervisord.d/rocketmq-broker.ini << EOF
[program:rocketmq-broker]
command=sh bin/mqbroker -c /work/rocketmq/conf/2m-2s-async/broker-b-s.properties
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