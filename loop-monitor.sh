#!/bin/bash
# loop-monitor.sh - Ghi thoi gian hien tai vao /tmp/monitor.log moi 5 giay.
# Chay nen doc lap voi nohup de tiep tuc hoat dong khi ngat ket noi SSH/Terminal.
while true; do
    echo "System time: $(date)" >> /tmp/monitor.log
    sleep 5
done
