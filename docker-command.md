# Docker 명령어 모음

## 컨테이너 최초 빌드 및 실행

```bash
# 이미지 빌드 + 컨테이너 생성 및 실행
docker compose up -d --build

# 접속 (bash)
docker exec -it linux-monitoring bash

# 접속 (SSH) — root 비밀번호: root1234
ssh root@localhost
```

---

## 일시 중단 / 재개 (작업 내용 보존)

```bash
# 오늘 작업 끝날 때 — 컨테이너 일시정지 (내용 보존)
docker compose stop

# 다음날 이어서 할 때
docker compose start
docker exec -it linux-monitoring bash
```

> `docker compose down` 은 컨테이너를 삭제하므로 작업 내용이 날아감. 사용 금지.

---

## 컨테이너 재시작 후 서비스 복구

컨테이너를 stop/start 하면 내부 서비스가 꺼진 상태로 돌아옴.
접속 후 아래 명령어로 서비스를 다시 시작:

```bash
service ssh start
service cron start

# 앱도 실행 중이어야 monitor.sh 가 정상 동작함
source /etc/profile.d/agent.sh
python3 /opt/agent/agent_app.py &
```

---

## 다른 컴퓨터로 이식하기

### 방법 A — 파일로 저장 (USB / 구글드라이브)

**현재 컴퓨터에서 저장:**
```bash
# 현재 컨테이너 상태를 이미지로 커밋
docker commit linux-monitoring linux-monitoring:saved

# 이미지를 .tar 파일로 내보내기
docker save linux-monitoring:saved -o linux-monitoring.tar
```

**다른 컴퓨터에서 불러오기:**
```bash
# .tar 파일을 이미지로 불러오기
docker load -i linux-monitoring.tar

# 컨테이너 실행
docker run -d --name linux-monitoring \
  -p 22:22 -p 20022:20022 -p 15034:15034 \
  linux-monitoring:saved /usr/sbin/sshd -D

# 접속
docker exec -it linux-monitoring bash
```

---

### 방법 B — Docker Hub 활용 (인터넷 사용 가능 시)

**현재 컴퓨터에서 업로드:**
```bash
docker login

docker commit linux-monitoring 도커허브ID/linux-monitoring:saved
docker push 도커허브ID/linux-monitoring:saved
```

**다른 컴퓨터에서 내려받기:**
```bash
docker pull 도커허브ID/linux-monitoring:saved

docker run -d --name linux-monitoring \
  -p 22:22 -p 20022:20022 -p 15034:15034 \
  도커허브ID/linux-monitoring:saved /usr/sbin/sshd -D

docker exec -it linux-monitoring bash
```

---

## 단계별 체크포인트 저장 (권장)

실수했을 때 되돌아올 수 있도록 주요 단계 완료 시마다 커밋:

```bash
docker commit linux-monitoring linux-monitoring:step3-done
docker commit linux-monitoring linux-monitoring:step7-done
docker commit linux-monitoring linux-monitoring:final
```

---

## 기타 유용한 명령어

```bash
# 현재 실행 중인 컨테이너 확인
docker ps

# 저장된 이미지 목록 확인
docker images

# 컨테이너 로그 확인
docker logs linux-monitoring

# 컨테이너 완전 삭제 (처음부터 다시 시작할 때만)
docker compose down
docker compose up -d --build
```
