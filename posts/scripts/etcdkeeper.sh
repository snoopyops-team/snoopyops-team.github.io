#!/bin/bash
##################################
# Date:   2020/05/15 15:26
# Author: zhonghuak
# Email:  zhonghuak@opera.com
# 部署etcdkeeper
##################################

port=8100


### 判断是否为空
if [ x${port} == x'' ];then
    echo "端口不可为空"
    exit 255
fi

### 本机IP
IP=`ifconfig |grep 'inet '|awk {'print $2'}|grep -v '127.0.0.1'|cut -d: -f2`


### 下载安装
cd /usr/local/src/
wget "https://africa-sa-ops-tools.obs.af-south-1.myhuaweicloud.com/software/etcdkeeper.tar.gz"
tar -zxf etcdkeeper.tar.gz -C /opt/

cat > /etc/supervisord.d/etcdkeeper.ini << EOF
[program:etcdkeeper]
command=/opt/etcdkeeper/etcdkeeper -h ${IP} -p ${port}
process_name=%(program_name)s
directory=/opt/etcdkeeper/
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
stdout_logfile=/work/logs/supervisord/etcdkeeper.log
stderr_logfile_maxbytes=50MB
stderr_logfile_backups=10
stderr_logfile=/work/logs/supervisord/etcdkeeper.log
minfds=65535
minprocs=32700
EOF
# 创建日志目录
mkdir -p /work/logs/supervisord/
# 启动服务
supervisorctl update
supervisorctl status
