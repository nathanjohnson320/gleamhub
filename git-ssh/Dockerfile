FROM alpine:3.20

RUN apk add --no-cache \
    openssh \
    git \
    curl \
    ca-certificates \
  && adduser -D -h /home/git -s /bin/sh git \
  && mkdir -p /data/repos /var/run/sshd /home/git \
  && chown git:git /data/repos /home/git

COPY authorized-keys.sh git-shell.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/authorized-keys.sh /usr/local/bin/git-shell.sh

COPY sshd_config /etc/ssh/sshd_config

RUN ssh-keygen -A

EXPOSE 22

CMD ["/usr/sbin/sshd", "-D", "-e"]
