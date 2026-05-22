# 요구사항 수행 내역서

> 각 단계 완료 후 명령어 출력을 아래 해당 섹션에 붙여넣으세요.

---

## 최종 체크리스트

- [ ] SSH 포트 20022 변경 및 root 로그인 차단 확인
- [ ] 방화벽(UFW 또는 firewalld) 설정: 20022/tcp, 15034/tcp 만 허용 확인
- [ ] 계정/그룹(agent-admin / agent-dev / agent-test, agent-common / agent-core) 생성 확인
- [ ] 디렉토리 구조 및 권한(ACL 포함) 설정 확인
- [ ] 앱 부팅 시 Boot Sequence 5단계 [OK] 및 "Agent READY" 출력 확인
- [ ] monitor.sh 실행 결과 (프로세스/포트/리소스/경고 출력) 확인
- [ ] /var/log/agent-app/monitor.log 누적 기록 확인
- [ ] crontab 매분 등록 및 자동 실행 확인

---

## Step 1: SSH 보안 설정

```
# ss -tlnp | grep 20022 출력 붙여넣기

```

```
# sudo sshd -T | grep -E "port|permitrootlogin" 출력 붙여넣기

```

---

## Step 2: 방화벽 설정

```
# sudo ufw status verbose 출력 붙여넣기

```

---

## Step 3: 그룹 및 사용자 생성

```
# id agent-admin 출력 붙여넣기

```

```
# id agent-dev 출력 붙여넣기

```

```
# id agent-test 출력 붙여넣기

```

```
# cat /etc/group | grep agent 출력 붙여넣기

```

---

## Step 4: 디렉토리 구조 및 권한

```
# ls -la /opt/agent/ 출력 붙여넣기

```

```
# ls -ld /var/log/agent-app 출력 붙여넣기

```

```
# getfacl /opt/agent/upload_files 출력 붙여넣기

```

```
# getfacl /opt/agent/api_keys 출력 붙여넣기

```

```
# getfacl /var/log/agent-app 출력 붙여넣기

```

---

## Step 5: 환경변수 설정

```
# env | grep AGENT 출력 붙여넣기

```

---

## Step 6: API 키 파일

```
# sudo cat /opt/agent/api_keys/t_secret.key 출력 붙여넣기

```

```
# ls -l /opt/agent/api_keys/t_secret.key 출력 붙여넣기

```

---

## Step 7: Python 앱 실행

```
# Boot Sequence 출력 붙여넣기 (Agent READY 까지)

```

```
# pgrep -a -f agent-app 출력 붙여넣기

```

```
# ss -tlnp | grep 15034 출력 붙여넣기

```

---

## Step 8: monitor.sh

```
# ls -l /opt/agent/bin/monitor.sh 출력 붙여넣기

```

```
# monitor.sh 실행 결과 붙여넣기

```

---

## Step 9: crontab 및 로그 누적 확인

```
# sudo -u agent-admin crontab -l 출력 붙여넣기

```

```
# tail -5 /var/log/agent-app/monitor.log 출력 붙여넣기 (1~2분 후)

```

---

## Step 10: 로그 로테이션

```
# logrotate 설정 확인 출력 붙여넣기

```

---

## Step 12 (Bonus): report.sh 실행 결과

```
# report.sh 실행 결과 붙여넣기

```

---

## Step 13 (Bonus): 로그 아카이브

```
# ls -l /opt/agent/bin/archive_logs.sh 출력 붙여넣기

```

```
# sudo -u agent-admin crontab -l 출력 붙여넣기

```

---

## monitor.sh 소스 코드

```bash
# /opt/agent/bin/monitor.sh 전체 내용 붙여넣기
# cat /opt/agent/bin/monitor.sh

```
