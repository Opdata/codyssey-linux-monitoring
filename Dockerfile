FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openssh-server \
    python3 \
    python3-pip \
    ufw \
    acl \
    cron \
    sudo \
    vim \
    net-tools \
    iproute2 \
    procps \
    lsof \
    logrotate \
    gzip \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd \
    && echo 'root:root1234' | chpasswd

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
