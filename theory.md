# 이론 및 명령어 정리

> 미션 진행 중 학습한 개념과 명령어를 단계별로 기록.

---

## Step 1: SSH 보안 설정

### SSH란?

**SSH(Secure Shell)** 는 원격 서버에 암호화된 통신으로 접속하는 프로토콜이다.  
기본 포트는 22번이며, 변경하지 않으면 자동화된 공격(brute-force)의 주요 타겟이 된다.

### PermitRootLogin no

root는 시스템 최고 권한 계정이다. 직접 SSH 로그인을 허용하면 탈취 시 시스템 전체가 위험해진다.  
일반 계정으로 로그인 후 `sudo`로 권한을 상승시키는 것이 안전하다.

### 명령어

```bash
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
```
- `cp A B`: A를 B로 복사
- 설정 파일 수정 전 항상 `.bak` 백업을 만들어둔다. 실수 시 복구 가능.

```bash
sed -i 's/^#Port 22/Port 20022/' /etc/ssh/sshd_config
```
- `sed`: 파일 내용을 스트림으로 처리해 치환하는 도구 (Stream EDitor)
- `-i`: 파일을 직접 수정 (in-place). 없으면 화면에만 출력됨
- `s/찾을것/바꿀것/`: 치환 문법
- `^`: 줄의 시작을 의미. `^Port`는 "Port로 시작하는 줄"
- `#Port 22`(주석)와 `Port 22`(주석 없음) 두 경우를 모두 처리하기 위해 두 줄 실행

```bash
grep -E '^Port|^PermitRootLogin' /etc/ssh/sshd_config
```
- `grep`: 파일에서 패턴에 맞는 줄을 출력
- `-E`: 확장 정규표현식 사용
- `|`: OR 조건. 두 패턴 중 하나라도 맞으면 출력

```bash
service ssh restart
```
- 설정 파일을 수정해도 서비스를 재시작해야 적용됨
- `restart` = 중지 후 재시작 (설정 다시 읽어들임)

```bash
ss -tulnp | grep sshd
```
- `ss`: 소켓 상태 확인 명령어 (netstat의 현대적 대체)
- `-t`: TCP, `-u`: UDP, `-l`: LISTEN 상태, `-n`: 숫자 표시, `-p`: 프로세스 정보
- `| grep sshd`: sshd 관련 줄만 필터링

```bash
sshd -T | grep -E '^port|^permitrootlogin'
```
- `sshd -T`: SSH 데몬이 현재 실제로 적용 중인 설정값 전체 출력
- 파일을 보는 게 아니라 실제 동작 중인 값을 확인 → 더 신뢰할 수 있음

---

## Step 2: 방화벽 (UFW)

### 방화벽이란?

네트워크 트래픽을 규칙에 따라 허용/차단하는 보안 시스템.  
리눅스 커널 레벨 방화벽은 `iptables`이고, UFW는 이를 쉽게 관리하는 프론트엔드다.

### Default Deny 전략

```
기본: 모든 인바운드 차단
허용 포트만 명시적으로 열기
```

화이트리스트 방식. "필요한 것만 열고 나머지는 막는다"는 원칙이 서버 보안의 기본이다.

### 명령어

```bash
ufw default deny incoming
```
- 인바운드(외부 → 서버) 기본 정책을 "차단"으로 설정
- 이후 명시적으로 허용한 포트만 접속 가능

```bash
ufw default allow outgoing
```
- 아웃바운드(서버 → 외부) 기본 정책을 "허용"으로 설정
- 서버에서 외부로 나가는 트래픽은 제한 없음

```bash
ufw allow 20022/tcp
```
- TCP 20022번 포트 인바운드 허용
- `/tcp`를 지정하지 않으면 TCP+UDP 모두 열림

```bash
ufw enable
```
- 방화벽 활성화. 활성화 전까지 규칙이 적용되지 않음
- 실행 시 확인 메시지 → `y` 입력

```bash
ufw status verbose
```
- 현재 방화벽 상태 및 규칙 목록 출력
- `verbose`: 기본 정책(deny/allow)까지 함께 표시

### Docker 컨테이너에서 UFW 오류 및 해결

Docker 컨테이너는 호스트 OS의 커널을 공유하지만, 기본 설정에서 커널 네트워크 기능 접근이 제한된다.

| 에러 | 원인 |
|------|------|
| `Permission denied` (iptables) | 컨테이너에 `NET_ADMIN` 권한 없음 |
| `unable to initialize table 'filter'` | 커널 iptables 필터 테이블 접근 불가 |
| `Read-only file system` (sysctl) | 컨테이너에서 커널 파라미터 수정 불가 |

**NET_ADMIN이란?**

리눅스 커널의 네트워크 관련 작업을 수행할 수 있는 권한이다.
iptables/UFW는 커널 레벨에서 패킷을 필터링하기 때문에 NET_ADMIN 권한이 필요하다.

- Docker는 기본적으로 컨테이너가 호스트 네트워크를 건드리지 못하도록 이 권한을 제거함
- `NET_RAW`: raw 소켓 사용 권한. UFW가 내부적으로 사용

**해결 방법**: docker-compose.yml에 권한 명시적으로 추가

```yaml
cap_add:
  - NET_ADMIN
  - NET_RAW
```

컨테이너 재생성이 필요하므로 현재 작업 상태를 먼저 커밋해야 한다.

```bash
# 현재 컨테이너 상태를 이미지로 저장
docker commit linux-monitoring linux-monitoring:step1-done

# docker-compose.yml에서 build 대신 저장한 이미지 사용
# image: linux-monitoring:step1-done

# 컨테이너 재생성
docker compose down
docker compose up -d
```

실제 서버나 VM 환경에서는 이 문제가 발생하지 않는다.

---

## Step 3: 계정/그룹 관리

### 최소 권한 원칙 (Principle of Least Privilege)

각 계정은 자신의 역할에 필요한 최소한의 권한만 가져야 한다.  
이 미션에서는 역할별로 계정을 분리하고, 그룹으로 접근 권한을 제어한다.

| 그룹 | 역할 | 접근 가능 디렉토리 |
|------|------|--------------------|
| agent-common | 모든 에이전트 공통 | upload_files |
| agent-core | 관리자+개발자 | api_keys, /var/log/agent-app |

### 명령어

```bash
groupadd agent-common
```
- 새 그룹 생성. `/etc/group` 파일에 추가됨

```bash
useradd -m -s /bin/bash agent-admin
```
- `-m`: 홈 디렉토리 생성 (`/home/agent-admin`)
- `-s /bin/bash`: 기본 셸을 bash로 지정
- 지정하지 않으면 `/bin/sh` 또는 로그인 불가 셸이 설정될 수 있음

```bash
usermod -aG agent-common,agent-core agent-admin
```
- `usermod`: 사용자 계정 속성 수정
- `-a`: append (기존 그룹 유지하면서 추가). 이것 없이 `-G`만 쓰면 기존 그룹이 날아감
- `-G`: 보조 그룹 지정

```bash
id agent-admin
```
- 사용자의 UID, GID, 소속 그룹 전체 출력
- `uid=`, `gid=`, `groups=` 항목으로 확인

```bash
grep agent /etc/group
```
- `/etc/group`: 시스템의 그룹 정보 파일
- `그룹명:비밀번호:GID:소속사용자` 형식으로 저장됨

---

## Step 4: 디렉토리 권한 및 ACL

### 리눅스 기본 권한 (chmod/chown)

```
drwxr-x---  root  agent-core
 |||  |||  |||
 |||  |||  +-- others: 권한 없음
 |||  +++-- group: r-x (읽기+실행)
 +++-- owner: rwx (읽기+쓰기+실행)
```

| 숫자 | 권한 |
|------|------|
| 7 | rwx (읽기+쓰기+실행) |
| 6 | rw- (읽기+쓰기) |
| 5 | r-x (읽기+실행) |
| 4 | r-- (읽기만) |
| 0 | --- (권한 없음) |

### ACL이란?

기본 chmod는 소유자/그룹/기타 3가지 주체만 제어한다.  
**ACL(Access Control List)** 은 특정 사용자나 그룹에 대해 개별적으로 권한을 부여하는 확장 기능이다.

이번 미션은 디렉토리당 접근 그룹이 하나뿐이므로 standard chmod/chown으로 충분하다.  
setfacl이 필요한 경우는 한 디렉토리에 두 그룹이 **서로 다른 권한**을 가져야 할 때다.

### 명령어

```bash
chown root:agent-core /home/agent-admin/agent-app/api_keys
```
- `chown 소유자:그룹 경로`: 파일/디렉토리의 소유자와 그룹 변경

```bash
chmod 770 /home/agent-admin/agent-app/upload_files
```
- `770` = 소유자(rwx) + 그룹(rwx) + 기타(---)

```bash
ls -la /home/agent-admin/agent-app/
```
- `-l`: 상세 정보 (권한, 소유자, 그룹, 크기, 날짜)
- `-a`: 숨김 파일 포함
- ACL이 설정된 파일/디렉토리는 권한 끝에 `+` 표시됨 (예: `drwxrwx---+`)

---

## Step 5: 환경변수

### 환경변수란?

셸에서 프로세스에 전달되는 `이름=값` 쌍이다.  
앱의 설정값을 코드 안에 하드코딩하지 않고 환경변수로 관리하면, 환경(개발/운영)이 바뀌어도 코드 수정 없이 동작시킬 수 있다.

### /etc/profile.d/

이 디렉토리에 `.sh` 파일을 넣으면, 시스템의 모든 사용자가 로그인할 때 자동으로 실행된다.  
→ 시스템 전체에 환경변수를 적용하는 표준 방법.

### 명령어

```bash
tee /etc/profile.d/agent.sh > /dev/null <<'EOF'
...
EOF
```
- `tee`: 표준 입력을 받아 파일에 쓰는 명령어 (`> /dev/null`로 화면 출력은 숨김)
- `<<'EOF' ... EOF`: heredoc. 여러 줄 텍스트를 입력하는 방법. 따옴표를 붙이면 변수 치환 없이 그대로 입력됨

```bash
source /etc/profile.d/agent.sh
```
- `source` (또는 `.`): 파일을 현재 셸 세션에서 실행
- 단순히 실행하면 자식 프로세스에서 실행되어 현재 세션에 적용 안 됨

```bash
env | grep AGENT
```
- `env`: 현재 세션의 환경변수 전체 출력
- `| grep AGENT`: AGENT가 포함된 줄만 필터링

---

## Step 6: 파일 권한 (API 키)

### 민감한 파일 권한 관리

API 키는 유출되면 심각한 피해가 발생한다.  
`chmod 640`: 소유자(rw-) + 그룹(r--) + 기타(---) → 그룹은 읽기만, 기타는 접근 불가.

---

## Step 7: 앱 배포 및 실행

### Non-root 실행

앱을 root로 실행하면 취약점 발생 시 시스템 전체가 위험해진다.  
전용 계정(agent-admin)으로 실행해 피해 범위를 제한한다.

### 명령어

```bash
sudo -u agent-admin bash -c "source /etc/profile.d/agent.sh && /home/agent-admin/agent-app/agent-app &"
```
- `sudo -u 계정 명령어`: 특정 계정으로 명령 실행
- `bash -c "..."`: bash로 문자열 명령어 실행
- `source ... && 앱실행`: 환경변수 적용 후 앱 실행 (두 명령을 연결)
- `&`: 백그라운드 실행 (터미널을 점유하지 않음)

```bash
pgrep -a -f agent-app
```
- `pgrep`: 프로세스 이름으로 PID 검색
- `-a`: 전체 명령어 라인 표시
- `-f`: 프로세스 이름 전체(명령어 포함)에서 검색

---

## Step 8: monitor.sh (Shell 스크립트)

### 셸 스크립트 구조

```bash
#!/bin/bash
```
- **shebang**: 이 파일을 bash로 실행하라는 선언. 첫 번째 줄에 반드시 위치.

### 변수

```bash
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
```
- `$(명령어)`: 명령어 실행 결과를 변수에 대입
- `date "+포맷"`: 현재 날짜/시간을 지정 형식으로 출력

### 조건문

```bash
if [ -z "$APP_PID" ]; then
    exit 1
fi
```
- `[ -z "$변수" ]`: 변수가 비어있으면 참
- `exit 1`: 비정상 종료 (0 이외의 값은 오류)

### 리소스 수집 명령어

```bash
CPU=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d. -f1)
```
- `top -bn1`: 배치 모드(-b)로 1회(-n1) 실행. 화면 갱신 없이 출력
- `grep "Cpu(s)"`: CPU 정보 줄 추출
- `awk '{print $2}'`: 두 번째 필드(사용률) 추출
- `cut -d. -f1`: 소수점 기준으로 나눠 정수 부분만 가져옴

```bash
MEM=$(free | awk '/Mem:/ {printf "%.0f", $3/$2 * 100}')
```
- `free`: 메모리 사용량 출력
- `awk '/Mem:/ {...}'`: Mem: 줄에서 `$3(사용량)/$2(전체) * 100`으로 사용률 계산
- `printf "%.0f"`: 소수점 없이 정수로 출력

```bash
DISK=$(df / | awk 'NR==2 {print $5}' | tr -d '%')
```
- `df /`: 루트 파티션 디스크 사용량 출력
- `awk 'NR==2 {...}'`: 2번째 줄(헤더 제외 첫 번째 데이터)에서 5번째 필드(사용률%) 추출
- `tr -d '%'`: `%` 문자 제거 → 숫자만 남김

### 비교 및 파이프

```bash
[ "$CPU" -gt 20 ] && echo "[WARNING] ..."
```
- `[ A -gt B ]`: A가 B보다 크면 참 (greater than)
- `&&`: 앞 명령이 성공(참)이면 뒤 명령 실행

```bash
echo "..." >> "$LOG_FILE"
```
- `>>`: 파일에 **추가** (append). `>`는 덮어쓰기.

---

## Step 9: crontab (작업 스케줄러)

### cron이란?

리눅스의 시간 기반 작업 스케줄러.  
지정된 시간/주기에 명령어를 자동 실행한다.

### crontab 형식

```
*  *  *  *  *  실행할명령어
│  │  │  │  │
│  │  │  │  └── 요일 (0-7, 0과 7이 일요일)
│  │  │  └───── 월 (1-12)
│  │  └──────── 일 (1-31)
│  └─────────── 시 (0-23)
└────────────── 분 (0-59)

* = 모든 값 (매분/매시/매일...)
```

| 예시 | 의미 |
|------|------|
| `* * * * *` | 매분 실행 |
| `0 * * * *` | 매시 정각 실행 |
| `0 0 * * *` | 매일 자정 실행 |

### 명령어

```bash
sudo -u agent-admin crontab -l
```
- agent-admin 계정의 crontab 목록 확인
- `-l`: list

```bash
(sudo -u agent-admin crontab -l 2>/dev/null; echo "* * * * * ...") \
    | sudo -u agent-admin crontab -
```
- `crontab -l 2>/dev/null`: 기존 crontab 출력 (없어도 오류 무시)
- `; echo "..."`: 새 줄 추가
- `| crontab -`: 파이프로 받아서 crontab으로 등록 (`-`는 표준 입력에서 읽기)

```bash
service cron start
```
- Docker 컨테이너에서는 cron 서비스가 자동 시작 안 됨 → 수동으로 시작 필요

---

## Step 10: 로그 로테이션

### 왜 필요한가?

로그 파일이 계속 커지면 디스크 부족, 분석 어려움, 성능 저하가 발생한다.  
로그 로테이션으로 오래된 로그를 압축/삭제해 관리한다.

### logrotate 주요 옵션

| 옵션 | 의미 |
|------|------|
| `size 10M` | 10MB 초과 시 로테이션 |
| `rotate 10` | 최대 10개 파일 보관 |
| `compress` | gzip으로 압축 |
| `copytruncate` | 원본 복사 후 비움 (앱 재시작 불필요) |
| `missingok` | 파일 없어도 오류 아님 |
| `notifempty` | 빈 파일은 로테이션 안 함 |
| `dateext` | 파일명에 날짜 추가 |

```bash
logrotate -d /etc/logrotate.d/agent-monitor
```
- `-d`: dry-run 모드. 실제 실행하지 않고 동작 예상 결과만 출력
- 설정 검증용으로 사용

