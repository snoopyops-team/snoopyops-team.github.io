#!/bin/bash
export node_hostname node_group node_env

node_hostname="ali-ng-okash-middle-rocketmq-prod-4"
node_group="fg-nigeria-microloan"
node_env="product"

cat > /etc/node.ini << EOF
[node]
hostname=${node_hostname}
group=${node_group}
env=${node_env}
EOF

JOIN_CONSUL_SERVER ()
{
  systemctl stop consul
  rm -rf /opt/consul/etc/consul.d/client/config.json
  rm -rf /opt/consul/data
  cat > /opt/consul/etc/consul.d/client/config.json << EOF
{
    "bootstrap": false,
    "bootstrap_expect": 0,
    "server": false,
    "domain": "consul",
    "dns_config": {
        "enable_truncate": true,
        "only_passing": true
    },
    "client_addr": "127.0.0.1",
    "start_join": [
],
    "datacenter": "${DATACENTER}",
    "data_dir": "/opt/consul/data",
    "encrypt": "1sJxUFk/8njXkz8Onp241w==",
    "leave_on_terminate": true,
    "rejoin_after_leave": true,
    "ui": true,
    "log_level": "INFO",
    "enable_syslog": true
}
EOF
  systemctl enable consul
  systemctl start consul
  consul_num=`ss -lnt | grep 8500 | wc -l`
  if [ ${consul_num} -ne 1 ];then
    sleep 2s
  fi
  if [ ${consul_num} -ne 1 ];then
    systemctl restart consul
  fi
  sleep 3s
  /opt/consul/bin/consul join ${CONSUL_SERVER_IP}
  mkdir -p /data/
  chown ${OWNER}.${OWNER} /data/
  mkdir -p /work/
  chown ${OWNER}.${OWNER} /work/
  chown -R ${OWNER}.${OWNER} /work/logs/supervisord/
}

### register node_exporter
REGISTER_NODE_EXPROTER ()
{
yum -y install jq
chown -R root.root /opt/node_exporter/
output=$(cat /opt/consul/data/node-id 2>/dev/null)
req=$?
if  [ ! -f /etc/node.ini ]; then
    echo "/etc/node.ini not mdkir"
    exit 255
else
    hostname=$(grep hostname /etc/node.ini | awk -F'=' '{print $NF}')
    group=$(grep group /etc/node.ini | awk -F'=' '{print $NF}')
    env=$(grep env /etc/node.ini |awk -F'=' '{print $NF}')
fi
port_num=$(netstat -lntup|grep 9100| wc -l)
if [ $req == 0 ];then
   if [ $port_num -eq 1 ] && [ -f /etc/node.ini ]; then
cat > /opt/node_exporter/node_exporter.json << EOF
{
  "id": "$hostname-node_exporter",
  "name": "node_exporter",
  "tags": [
	"host=$hostname",
        "group=$group",
        "env=$env"

],
  "port": 9100,
  "checks":[{"http":"http://127.0.0.1:9100/metrics","interval":"15s"}]
}
EOF
echo -e  "#!/bin/bash\ncurl -s --request PUT --data @/opt/node_exporter/node_exporter.json http://127.0.0.1:8500/v1/agent/service/register" > /opt/node_exporter/register_node_exporter.sh
bash /opt/node_exporter/register_node_exporter.sh
num=$(curl -s  http://localhost:8500/v1/catalog/service/node_exporter|jq '.[].ServiceID'|grep "$hostname"|wc -l)
result=$(curl -s  http://localhost:8500/v1/catalog/service/node_exporter|jq '.[].ServiceID'|grep "$hostname")
     if [ $num -eq 1 ]; then
echo $(curl -s  http://localhost:8500/v1/catalog/service/node_exporter|jq '.[].ServiceID' ) | tr " " "\n"
     else
       echo $result
     fi
   elif [ $port_num -eq 0 ]; then
       echo "node_exporter is down"

   elif  [ ! -f /etc/node.ini ]; then
       echo "/etc/node.ini is not mdkir"
  fi
else
   echo "please install consul agent first; you can't install node_exporter correctly now."
fi
}

### register process_exproter
REGISTER_PROCESS_EXPROTER ()
{
yum -y install jq
output=$(cat /opt/consul/data/node-id 2>/dev/null)
req=$?
if  [ ! -f /etc/node.ini ]; then
    echo "/etc/node.ini is not touch"
    exit 255
else
    hostname=$(grep hostname /etc/node.ini | awk -F'=' '{print $NF}')
    group=$(grep group /etc/node.ini | awk -F'=' '{print $NF}')
    env=$(grep env /etc/node.ini |awk -F'=' '{print $NF}')
fi
port_num=$(netstat -lntup|grep 9256| wc -l)
if [ $req == 0 ];then
   if [ $port_num -eq 1 ] && [ -f /etc/node.ini ]; then
cat > /usr/local/process-exporter/process_exporter.json << EOF
{
  "id": "$hostname-process_exporter",
  "name": "process_exporter",
  "tags": [
	"host=$hostname",
        "group=$group",
        "env=$env"

],
  "port": 9256,
  "checks":[{"http":"http://127.0.0.1:9256/metrics","interval":"15s"}]
}
EOF
echo -e  "#!/bin/bash\ncurl -s --request PUT --data @/usr/local/process-exporter/process_exporter.json http://127.0.0.1:8500/v1/agent/service/register" > /usr/local/process-exporter/register_process_exporter.sh
bash /usr/local/process-exporter/register_process_exporter.sh
num=$(curl -s  http://localhost:8500/v1/catalog/service/process_exporter|jq '.[].ServiceID'|grep "$hostname"|wc -l)
result=$(curl -s  http://localhost:8500/v1/catalog/service/process_exporter|jq '.[].ServiceID'|grep "$hostname")
     if [ $num -eq 1 ]; then
       echo $(curl -s  http://localhost:8500/v1/catalog/service/process_exporter|jq '.[].ServiceID' ) | tr " " "\n"
     else
       echo $result
     fi
   elif [ $port_num -eq 0 ]; then
       echo "process_exporter is down"

   elif  [ ! -f /etc/node.ini ]; then
       echo "/etc/node.ini is not touch"
  fi
else
   echo "please install consul agent first; you can't install process_exporter correctly now."
fi
}

IP=`ip addr | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | awk -F/ '{ print $1}' | awk -F. '{ print $1"."$2}'`
IP3=`ip addr | grep inet | grep -v 127.0.0.1 | grep -v inet6 | awk '{print $2}' | awk -F/ '{ print $1}' | awk -F. '{ print $1"."$2"."$3}'`

if [ $IP == "10.106" ];then
        # indonesia aws
	CONSUL_SERVER_IP='10.106.3.213'
	OWNER='nginx'
	DATACENTER='singapore'
	JOIN_CONSUL_SERVER
elif [ $IP == "10.116" ];then
  # ali-ng-okash
  #CONSUL_SERVER_IP='10.125.1.3'
  CONSUL_SERVER_IP='10.116.2.220'
  OWNER='sdev'
  DATACENTER='ali-ng-okash-new'
  JOIN_CONSUL_SERVER
elif [ $IP == "10.134" ];then
  # ali-africa-public
  CONSUL_SERVER_IP='10.134.1.186'
  OWNER='sdev'
  DATACENTER='ali-africa-public'
  JOIN_CONSUL_SERVER
elif [ $IP == "10.136" ];then
  # ali-ng-kk
  CONSUL_SERVER_IP='10.136.0.188'
  OWNER='sdev'
  DATACENTER='ali-ng-kk'
  JOIN_CONSUL_SERVER
elif [ $IP == "10.139" ];then
  # ali-ng-ec
  CONSUL_SERVER_IP='10.139.7.184'
  OWNER='sdev'
  DATACENTER='ali-ng-ec'
  JOIN_CONSUL_SERVER

else
	echo "This IP segment is not add the script~.Please contact add !!!"
	exit 255
fi
REGISTER_NODE_EXPROTER
REGISTER_PROCESS_EXPROTER
