#!/bin/bash

LOG_FILE="/var/log/agent-app/monitor.log"
APP_NAME="agent-app"
APP_PORT=15034
MAX_LOG_SIZE=$((10 * 1024 * 1024))  # 10MB
MAX_LOG_FILES=10

echo "====== SYSTEM MONITOR RESULT ======"
echo ""
echo "[HEALTH CHECK]"

# 프로세스 확인
PID=$(pgrep -f "$APP_NAME" | head -1)
if [ -z "$PID" ]; then
    echo "Checking process '$APP_NAME'... [FAIL]"
    exit 1
fi
echo "Checking process '$APP_NAME'... [OK] (PID: $PID)"

# 포트 확인
if ! ss -tlnp | grep -q ":${APP_PORT}"; then
    echo "Checking port $APP_PORT... [FAIL]"
    exit 1
fi
echo "Checking port $APP_PORT... [OK]"

echo ""

# 방화벽 확인
UFW_STATUS=$(ufw status 2>/dev/null | head -1)
if echo "$UFW_STATUS" | grep -q "inactive"; then
    echo "[WARNING] Firewall is inactive"
fi

echo "[RESOURCE MONITORING]"

# CPU 사용률
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)
# MEM 사용률
MEM=$(free | awk '/Mem:/ {printf "%.1f", $3/$2 * 100}')
# DISK 사용률
DISK=$(df / | awk 'NR==2 {print $5}' | tr -d '%')

echo "CPU Usage : ${CPU}%"
echo "MEM Usage : ${MEM}%"
echo "DISK Used  : ${DISK}%"
echo ""

# 임계값 경고
CPU_INT=$(echo "$CPU" | cut -d'.' -f1)
MEM_INT=$(echo "$MEM" | cut -d'.' -f1)

if [ "$CPU_INT" -gt 20 ]; then
    echo "[WARNING] CPU threshold exceeded (${CPU}% > 20%)"
fi
if [ "$MEM_INT" -gt 10 ]; then
    echo "[WARNING] MEM threshold exceeded (${MEM}% > 10%)"
fi
if [ "$DISK" -gt 80 ]; then
    echo "[WARNING] DISK threshold exceeded (${DISK}% > 80%)"
fi

# 로그 용량 관리
if [ -f "$LOG_FILE" ]; then
    LOG_SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null)
    if [ "$LOG_SIZE" -ge "$MAX_LOG_SIZE" ]; then
        for i in $(seq $((MAX_LOG_FILES - 1)) -1 1); do
            [ -f "${LOG_FILE}.${i}" ] && mv "${LOG_FILE}.${i}" "${LOG_FILE}.$((i + 1))"
        done
        mv "$LOG_FILE" "${LOG_FILE}.1"
    fi
fi

# 로그 기록
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
echo "[${TIMESTAMP}] PID:${PID} CPU:${CPU}% MEM:${MEM}% DISK_USED:${DISK}%" >> "$LOG_FILE"
echo "[INFO] Log appended: $LOG_FILE"
echo "======================================"
