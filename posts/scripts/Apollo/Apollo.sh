#!/bin/bash
##################################
# Date:   2021/05/27 15:14
# Author: zhonghuak
# Email:  kangzhonghua@mobimagic.com
# 生产环境单机部署apollo
##################################

# 参数配置
DBURL=
PASSWORD=
# true or false
PUBIP=true


# ### 判断是否安装java
hash java
JAVA_RET=$?
if [ ${JAVA_RET} -ne 0 ];then
    echo "The deploy is failed~~~"
    echo "please deploy java!!!!!"
    exit 255
fi



# 下载并解压
cd /usr/local/src
wget https://github.com/ctripcorp/apollo/releases/download/v1.6.1/apollo-adminservice-1.6.1-github.zip
wget https://github.com/ctripcorp/apollo/releases/download/v1.6.1/apollo-configservice-1.6.1-github.zip
wget  https://github.com/ctripcorp/apollo/releases/download/v1.6.1/apollo-portal-1.6.1-github.zip

mkdir -p /opt/apollo/{apollo-adminservice,apollo-configservice,apollo-portal}
cd /usr/local/src
unzip apollo-adminservice-1.6.1-github.zip    -d  /opt/apollo/apollo-adminservice/
unzip apollo-configservice-1.6.1-github.zip  -d /opt/apollo/apollo-configservice/
unzip apollo-portal-1.6.1-github.zip  -d /opt/apollo/apollo-portal/

# 修改配置文件
cat > /opt/apollo/apollo-adminservice/config/application-github.properties << EOF
# DataSource
spring.datasource.url = jdbc:mysql://$DBURL:3306/ApolloConfigDB?characterEncoding=utf8
spring.datasource.username = apolloconfig
spring.datasource.password = $PASSWORD
EOF
cat > /opt/apollo/apollo-configservice/config/application-github.properties << EOF
# DataSource
spring.datasource.url = jdbc:mysql://$DBURL:3306/ApolloConfigDB?characterEncoding=utf8
spring.datasource.username = apolloconfig
spring.datasource.password = $PASSWORD


#apollo.eureka.server.enabled=true
#apollo.eureka.client.enabled=true
EOF
cat > /opt/apollo/apollo-portal/config/application-github.properties << EOF
# DataSource
spring.datasource.url = jdbc:mysql://$DBURL:3306/ApolloPortalDB?characterEncoding=utf8
spring.datasource.username = apolloportal
spring.datasource.password = $PASSWORD
EOF

sed -i 's@/opt/logs@/work/logs/apollo@g' /opt/apollo/apollo-adminservice/scripts/startup.sh
sed -i 's@#export JAVA_OPTS="-Xms2560m -Xmx2560m -Xss256k -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=384m -XX:NewSize=1536m -XX:MaxNewSize=1536m -XX:SurvivorRatio=8"@export JAVA_OPTS="-Xms2560m -Xmx2560m -Xss256k -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=384m -XX:NewSize=1536m -XX:MaxNewSize=1536m -XX:SurvivorRatio=8"@g' /opt/apollo/apollo-adminservice/scripts/startup.sh

sed -i 's@/opt/logs@/work/logs/apollo@g' /opt/apollo/apollo-configservice/scripts/startup.sh
sed -i 's@#export JAVA_OPTS="-Xms6144m -Xmx6144m -Xss256k -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=384m -XX:NewSize=4096m -XX:MaxNewSize=4096m -XX:SurvivorRatio=8"@export JAVA_OPTS="-Xms2048m -Xmx2048m -Xss256k -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=384m -XX:NewSize=1024m -XX:MaxNewSize=1024m -XX:SurvivorRatio=8"@g' /opt/apollo/apollo-configservice/scripts/startup.sh


#
if [ "${PUBIP}" = "true" ];then
    public_ip=`curl ifconfig.me`
    adminservice_old="Djava.security.egd=file:/dev/./urandom"
    adminservice_new="Djava.security.egd=file:/dev/./urandom -Deureka.instance.homePageUrl=http://${public_ip}:8090"
    sed -i "s@${adminservice_old}@${adminservice_new}@g" /opt/apollo/apollo-adminservice/scripts/startup.sh
    configservice_old="Djava.security.egd=file:/dev/./urandom"
    configservice_new="Djava.security.egd=file:/dev/./urandom -Deureka.instance.homePageUrl=http://${public_ip}:8080"
    sed -i "s@${configservice_old}@${configservice_new}@g" /opt/apollo/apollo-configservice/scripts/startup.sh
    
cat > /opt/apollo/apollo-portal/config/apollo-env.properties << EOF
pro.meta=http://${public_ip}:8080
EOF
fi


sed -i 's@/opt/logs@/work/logs/apollo@g' /opt/apollo/apollo-portal/scripts/startup.sh
sed -i 's@#export JAVA_OPTS="-Xms2560m -Xmx2560m -Xss256k -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=384m -XX:NewSize=1536m -XX:MaxNewSize=1536m -XX:SurvivorRatio=8"@export JAVA_OPTS="-Xms2560m -Xmx2560m -Xss256k -XX:MetaspaceSize=128m -XX:MaxMetaspaceSize=384m -XX:NewSize=1536m -XX:MaxNewSize=1536m -XX:SurvivorRatio=8"@g' /opt/apollo/apollo-portal/scripts/startup.sh

cat >> /var/spool/cron/root << EOF
# 定时清空apollo日志
10 23 20 * * > /tmp/apollo-configservice_optapolloapollo-configservice.log
12 23 20 * * > /tmp/apollo-portal_optapolloapollo-portal.log
14 23 20 * * > /tmp/apollo-adminservice_optapolloapollo-adminservice.log
EOF

mysql -h$DBURL -uapolloportal -p$PASSWORD ApolloPortalDB -e 'UPDATE ApolloPortalDB.ServerConfig SET ServerConfig.`Value`="dev,fat,uat,pro" WHERE `Key`="apollo.portal.envs";'


echo -e "请按照如下顺序启动apollo
/opt/apollo/apollo-adminservice/scripts/startup.sh
/opt/apollo/apollo-configservice/scripts/startup.sh
/opt/apollo/apollo-portal/scripts/startup.sh
访问账号:apollo,密码：admin"
