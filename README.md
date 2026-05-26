# 요구사항 수행 내역서

**미션:** 시스템 관제 자동화 스크립트 개발  
**환경:** Ubuntu 22.04 LTS (Docker 컨테이너)  
**AGENT_HOME:** `/home/agent-admin/agent-app` (미션 예시 기준)

---

## 수행 내역

### Step 1: SSH 보안 설정

```bash
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
sed -i 's/^#Port 22/Port 20022/' /etc/ssh/sshd_config
sed -i 's/^Port 22/Port 20022/' /etc/ssh/sshd_config
sed -i 's/^#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
service ssh restart
```

- `/etc/ssh/sshd_config` 에서 포트를 22 → **20022** 로 변경
- `PermitRootLogin no` 설정으로 root 원격 로그인 차단
- 변경 후 `service ssh restart` 로 설정 적용

### Step 2: 방화벽 설정 (UFW)

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 20022/tcp
ufw allow 15034/tcp
ufw enable
```

- 인바운드 기본 정책: **deny** (모든 포트 차단)
- 허용 포트: **TCP 20022** (SSH), **TCP 15034** (APP)
- `ufw enable` 으로 활성화

### Step 3: 계정/그룹 생성

```bash
groupadd agent-common
groupadd agent-core
useradd -m -s /bin/bash agent-admin
usermod -aG agent-common,agent-core agent-admin
useradd -m -s /bin/bash agent-dev
usermod -aG agent-common,agent-core agent-dev
useradd -m -s /bin/bash agent-test
usermod -aG agent-common agent-test
```

| 계정        | 그룹 소속                | 역할                    |
| ----------- | ------------------------ | ----------------------- |
| agent-admin | agent-common, agent-core | 운영/관리, cron 실행자  |
| agent-dev   | agent-common, agent-core | 개발, monitor.sh 작성자 |
| agent-test  | agent-common             | QA/테스트               |

### Step 4: 디렉토리 구조 및 권한/ACL 설정

```bash
# 디렉토리 생성
mkdir -p /home/agent-admin/agent-app/upload_files
mkdir -p /home/agent-admin/agent-app/api_keys
mkdir -p /home/agent-admin/agent-app/bin
mkdir -p /var/log/agent-app

# 소유권 및 권한 설정
chown agent-admin:agent-common /home/agent-admin/agent-app/upload_files && chmod 770 /home/agent-admin/agent-app/upload_files
chown agent-admin:agent-core /home/agent-admin/agent-app/api_keys && chmod 770 /home/agent-admin/agent-app/api_keys
chown root:agent-core /var/log/agent-app && chmod 770 /var/log/agent-app
```

| 경로                                       | 소유 그룹    | 접근 권한 |
| ------------------------------------------ | ------------ | --------- |
| `/home/agent-admin/agent-app/upload_files` | agent-common | 770       |
| `/home/agent-admin/agent-app/api_keys`     | agent-core   | 770       |
| `/var/log/agent-app`                       | agent-core   | 770       |

### Step 5: 환경변수 설정

```bash
tee /etc/profile.d/agent.sh > /dev/null <<'EOF'
export AGENT_HOME=/home/agent-admin/agent-app
export AGENT_PORT=15034
export AGENT_UPLOAD_DIR=$AGENT_HOME/upload_files
export AGENT_KEY_PATH=$AGENT_HOME/api_keys
export AGENT_LOG_DIR=/var/log/agent-app
EOF

chmod +x /etc/profile.d/agent.sh
source /etc/profile.d/agent.sh
```

| 변수             | 값                                       |
| ---------------- | ---------------------------------------- |
| AGENT_HOME       | /home/agent-admin/agent-app              |
| AGENT_PORT       | 15034                                    |
| AGENT_UPLOAD_DIR | /home/agent-admin/agent-app/upload_files |
| AGENT_KEY_PATH   | /home/agent-admin/agent-app/api_keys     |
| AGENT_LOG_DIR    | /var/log/agent-app                       |

**확인**

```bash
env | grep AGENT
AGENT_UPLOAD_DIR=/home/agent-admin/agent-app/upload_files
AGENT_PORT=15034
AGENT_KEY_PATH=/home/agent-admin/agent-app/api_keys
AGENT_HOME=/home/agent-admin/agent-app
AGENT_LOG_DIR=/var/log/agent-app
```

### Step 6: API 키 파일 생성

```bash
echo "agent_api_key_test" > /home/agent-admin/agent-app/api_keys/secret.key
```

- 경로: `/home/agent-admin/agent-app/api_keys/secret.key`
- 내용: `agent_api_key_test`
- 권한: `640` (agent-core 그룹 읽기만 가능)

### Step 7: 앱 배포 및 실행

```bash
docker cp /Users/jun/Documents/GitHub/codyssey-work/linux-monitoring/agent-app/agent-app-linux-arm64 linux-monitoring:/home/agent-admin/agent-app/agent-app

sudo -u agent-admin bash -c "source /etc/profile.d/agent.sh && /home/agent-admin/agent-app/agent-app"
>>> Starting Agent Boot Sequence...
[1/5] Checking User Account               [OK]
   ... Running as service user 'agent-admin' (uid=1000)
[2/5] Verifying Environment Variables     [OK]
   ... All required Envs correct
[3/5] Checking Required Files             [OK]
   ... Verified 'secret.key' with correct key string.
[4/5] Checking Port Availability          [OK]
   ... Port 15034 is available.
[5/5] Verifying Log Permission            [OK]
   ... Log directory is writable: /var/log/agent-app
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
```

- `/home/agent-admin/agent-app/agent-app` 배치 후 agent-admin 계정으로 실행 (non-root)
- Boot Sequence 5단계 [OK] 및 "Agent READY" 출력 확인
- 포트 15034 LISTEN 확인

### Step 8: monitor.sh 작성

**프로젝트 내 /bin/monitor.sh 참조**

```bash
chown agent-dev:agent-core /home/agent-admin/agent-app/bin/monitor.sh
chmod 750 /home/agent-admin/agent-app/bin/monitor.sh
```

- 경로: `/home/agent-admin/agent-app/bin/monitor.sh`
- 소유자: agent-dev / 그룹: agent-core / 권한: 750
- 기능: 헬스체크 → 방화벽 확인 → 리소스 수집 → 임계값 경고 → 로그 기록

### Step 9: crontab 등록

```bash
sudo -u agent-admin crontab -e
# 아래코드 스케쥴러에 등록
* * * * * /bin/bash -c "source /etc/profile.d/agent.sh && /home/agent-admin/agent-app/bin/monitor.sh"

# 등록확인
sudo -u agent-admin crontab -l

# cron 데몬 확인(not running 이면 restart 필요)
service cron status
service cron restart
```

- `agent-admin` 계정 crontab에 `* * * * *` 로 매분 실행 등록
- 등록 후 1~2분 후 `/var/log/agent-app/monitor.log` 에 자동 누적 확인

### Step 10: 로그 파일 용량 관리

```bash
if [ -f "$LOG_FILE" ]; then
    LOG_SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null)
    if [ "$LOG_SIZE" -ge "$MAX_LOG_SIZE" ]; then
        for i in $(seq $((MAX_LOG_FILES - 1)) -1 1); do
            [ -f "${LOG_FILE}.${i}" ] && mv "${LOG_FILE}.${i}" "${LOG_FILE}.$((i + 1))"
        done
        mv "$LOG_FILE" "${LOG_FILE}.1"
    fi
fi
```

- monitor.sh 스크립트 내 로테이션 로직으로 구현
- 10MB 초과 시 로테이션, 최대 10개 보관

---

## 필수 증거 자료

### 1. SSH 포트 변경(20022) 및 Root 원격 접속 차단

- [x] SSH 포트 20022 변경 및 root 로그인 차단 확인

```bash
# grep -E '^Port|^PermitRootLogin' /etc/ssh/sshd_config
Port 20022
PermitRootLogin no
```

---

### 2. 방화벽 활성화 및 20022/tcp, 15034/tcp만 허용

- [x] 방화벽 설정 확인

```bash
# ufw status verbose
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), deny (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
20022/tcp                  ALLOW IN    Anywhere
15034/tcp                  ALLOW IN    Anywhere
20022/tcp (v6)             ALLOW IN    Anywhere (v6)
15034/tcp (v6)             ALLOW IN    Anywhere (v6)
```

---

### 3. 계정/그룹 생성 확인

- [x] 계정/그룹 생성 확인

```bash
# id agent-admin
uid=1000(agent-admin) gid=1002(agent-admin) groups=1002(agent-admin),1000(agent-common),1001(agent-core)
# id agent-dev
uid=1001(agent-dev) gid=1003(agent-dev) groups=1003(agent-dev),1000(agent-common),1001(agent-core)
# id agent-test
uid=1002(agent-test) gid=1004(agent-test) groups=1004(agent-test),1000(agent-common)
# grep agent /etc/group
agent-common:x:1000:agent-admin,agent-dev,agent-test
agent-core:x:1001:agent-admin,agent-dev
agent-admin:x:1002:
agent-dev:x:1003:
agent-test:x:1004:
```

---

### 4. 디렉토리 구조 및 권한(ACL 포함) 확인

- [x] 디렉토리 구조 및 권한(ACL 포함) 확인

```bash
# ls -la /home/agent-admin/agent-app/
drwxrwx--- 2 agent-admin agent-core   4096 May 21 07:38 api_keys
drwxrwx--- 2 agent-admin agent-core   4096 May 21 07:38 bin
drwxrwx--- 2 agent-admin agent-common 4096 May 21 07:37 upload_files

# ls -ld /var/log/agent-app
drwxrwx--- 2 root agent-core 4096 May 21 07:39 /var/log/agent-app
```

---

### 5. 앱 Boot Sequence 5단계 [OK] 및 "Agent READY" 확인

- [x] Boot Sequence 출력 확인

```bash
sudo -u agent-admin bash -c "source /etc/profile.d/agent.sh && /home/agent-admin/agent-app/agent-app"
>>> Starting Agent Boot Sequence...
[1/5] Checking User Account               [OK]
   ... Running as service user 'agent-admin' (uid=1000)
[2/5] Verifying Environment Variables     [OK]
   ... All required Envs correct
[3/5] Checking Required Files             [OK]
   ... Verified 'secret.key' with correct key string.
[4/5] Checking Port Availability          [OK]
   ... Port 15034 is available.
[5/5] Verifying Log Permission            [OK]
   ... Log directory is writable: /var/log/agent-app
------------------------------------------------------------
All Boot Checks Passed!
Agent READY
```

---

### 6. monitor.sh 실행 결과 (프로세스/포트/리소스/경고)

- [x] monitor.sh 실행 결과 확인

```bash
sudo -u agent-admin bash -c "source /etc/profile.d/agent.sh && /home/agent-admin/agent-app/bin/monitor.sh"

====== SYSTEM MONITOR RESULT ======

[HEALTH CHECK]
Checking process 'agent-app'... [OK] (PID: 434)
Checking port 15034... [OK]

[RESOURCE MONITORING]
CPU Usage : 0.0%
MEM Usage : 8.1%
DISK Used  : 1%

[INFO] Log appended: /var/log/agent-app/monitor.log
======================================
```

---

### 7. /var/log/agent-app/monitor.log 누적 기록 확인

- [x] 로그 누적 확인

```bash
tail -f /var/log/agent-app/monitor.log

[2026-05-22 11:29:01] PID:583 CPU:0.0% MEM:6.1% DISK_USED:1%
[2026-05-22 11:30:01] PID:583 CPU:0.0% MEM:9.3% DISK_USED:1%
[2026-05-22 11:31:01] PID:583 CPU:0.0% MEM:7.4% DISK_USED:1%
[2026-05-22 11:32:02] PID:583 CPU:0.0% MEM:8.4% DISK_USED:1%
[2026-05-22 11:33:01] PID:583 CPU:0.0% MEM:8.3% DISK_USED:1%
```

---

### 8. crontab 매분 실행 등록 및 자동 실행 확인

- [x] crontab 등록 및 자동 실행 확인

```bash
sudo -u agent-admin crontab -l
* * * * * /bin/bash -c "source /etc/profile.d/agent.sh && /home/agent-admin/agent-app/bin/monitor.sh"

service cron status
cron is running

tail -f /var/log/agent-app/monitor.log (1분 간격 자동 누적 확인)
[2026-05-22 11:29:01] PID:583 CPU:0.0% MEM:6.1% DISK_USED:1%
[2026-05-22 11:30:01] PID:583 CPU:0.0% MEM:9.3% DISK_USED:1%
[2026-05-22 11:31:01] PID:583 CPU:0.0% MEM:7.4% DISK_USED:1%
[2026-05-22 11:32:02] PID:583 CPU:0.0% MEM:8.4% DISK_USED:1%
[2026-05-22 11:33:01] PID:583 CPU:0.0% MEM:8.3% DISK_USED:1%
```

---
