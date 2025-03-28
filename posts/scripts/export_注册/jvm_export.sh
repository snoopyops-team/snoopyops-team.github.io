#!/bin/bash
#Defining variable
#set -x
source /etc/profile

mkdir -p /usr/local/src

# 参数配置
HTTPPORT=
JMXPORT=


######################### Add jmx_exporter  ##########################
function REGISTER_JVM_EXPORTER ()
{
mkdir -p /usr/local/prometheus/jmx_exporter
cd /usr/local/prometheus/jmx_exporter
if [ ! -f /usr/local/prometheus/jmx_exporter/jmx_prometheus_javaagent-0.12.0.jar ];then
        wget https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/0.12.0/jmx_prometheus_javaagent-0.12.0.jar
        # cp -rf ${SCRIPT_PATH}jmx_exporter/jmx_prometheus_javaagent-0.12.0.jar /usr/local/prometheus/jmx_exporter/jmx_prometheus_javaagent-0.12.0.jar
    echo "wget jmx_prometheus_javaagent-0.12.0.jar"
fi
if [ ! -f /usr/local/prometheus/jmx_exporter/jmx_exporter.yml ];then
        #cp -rf ${SCRIPT_PATH}jmx_exporter/jmx_exporter.yml /usr/local/prometheus/jmx_exporter/jmx_exporter.yml
        cat > /usr/local/prometheus/jmx_exporter/jmx_exporter.yml << EOF
lowercaseOutputLabelNames: true
lowercaseOutputName: true
whitelistObjectNames: ["java.lang:type=OperatingSystem"]
blacklistObjectNames: []
rules:
  - pattern: 'java.lang<type=OperatingSystem><>(committed_virtual_memory|free_physical_memory|free_swap_space|total_physical_memory|total_swap_space)_size:'
    name: os_$1_bytes
    type: GAUGE
    attrNameSnakeCase: true
  - pattern: 'java.lang<type=OperatingSystem><>((?!process_cpu_time)\w+):'
    name: os_$1
    type: GAUGE
    attrNameSnakeCase: true
EOF
    echo "生成 jmx_exporter.yml"
fi
JUMPSERVER_NAME=`cat /etc/node.ini | grep hostname | awk -F= '{ print $2 }'`
GROUP_NAME=`cat /etc/node.ini | grep group | awk -F= '{ print $2 }'`
cat > /usr/local/prometheus/jmx_exporter/jvm_exporter_${HTTPPORT}_${JMXPORT}.json << EOF
{
  "id": "${JUMPSERVER_NAME}-jvm_exporter:${HTTPPORT}",
  "name": "jvm_exporter",
  "tags": [
    "host=${JUMPSERVER_NAME}",
    "group=${GROUP_NAME}",
    "env=product",
    "java_port=${HTTPPORT}"
],
  "port": ${JMXPORT},
  "checks":[{"http":"http://127.0.0.1:${JMXPORT}/metrics","interval":"15s"}]
}
EOF
cat > /usr/local/prometheus/jmx_exporter/register_jvm_exporter_${HTTPPORT}_${JMXPORT}.sh << EOF
#!/bin/bash
curl -s --request PUT --data @/usr/local/prometheus/jmx_exporter/jvm_exporter_${HTTPPORT}_${JMXPORT}.json http://127.0.0.1:8500/v1/agent/service/register
EOF
/bin/bash /usr/local/prometheus/jmx_exporter/register_jvm_exporter_${HTTPPORT}_${JMXPORT}.sh
echo "Tomcat port ${HTTPPORT}'s jmx_port ${JMXPORT} register successfully!!"
echo "This instance had monitored java port:"
curl -s  http://localhost:8500/v1/catalog/service/jvm_exporter|jq '.[].ServiceID'| grep ${JUMPSERVER_NAME} | tr "\"" " "
}

REGISTER_JVM_EXPORTER
