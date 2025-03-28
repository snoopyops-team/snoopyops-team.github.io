#!/bin/bash

###安装
cd /usr/local/src
wget https://github.com/ncabatoff/process-exporter/releases/download/v0.7.10/process-exporter-0.7.10.linux-amd64.tar.gz
tar xf process-exporter-0.7.10.linux-amd64.tar.gz -C /usr/local/
ln -s /usr/local/process-exporter-0.7.10.linux-amd64/ /usr/local/process-exporter

## 拷贝配置文件
cat > /usr/local/process-exporter/process-all.yaml << \EOF
process_names:
  - name: "{{.Comm}}"
    cmdline:
    - '.+'
EOF

cat > /etc/systemd/system/process_exporter.service << \EOF
[Unit]
Description=Process_exporter daemon
After=network.target

[Service]
ExecStart=/usr/local/process-exporter/process-exporter -config.path /usr/local/process-exporter/process-all.yaml
User=root
Group=root
PrivateTmp=True

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload && systemctl enable process_exporter.service && systemctl start process_exporter.service && systemctl status process_exporter.service
