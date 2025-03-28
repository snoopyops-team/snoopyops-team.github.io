#!/bin/bash

mkdir /data01/
wget https://africa-sa-ops-tools.obs.af-south-1.myhuaweicloud.com/software/jdk-8u221-linux-x64.tar.gz
tar -zxf jdk-8u221-linux-x64.tar.gz -C /data01/
cat >> /etc/profile << \EOF

#####set java environment######
export JAVA_HOME=/data01/jdk1.8.0_221
export JRE_HOME=$JAVA_HOME/jre
export PATH=$JAVA_HOME/bin:$PATH
export CLASSPATH=.:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar
EOF

source /etc/profile
java -version
