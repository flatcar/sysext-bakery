#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the haproxy from git, checkout the tag (e.g., for v3.0.0), build a static binary and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "The build process requires docker"
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

if ! command -v docker &>/dev/null; then
  echo Missing docker in path
  exit 1
fi

SUFFIX=
if  [ "${ARCH}" = "x86-64" ] || [ "${ARCH}" = "x86_64" ]; then
  ARCH=amd64
elif [ "${ARCH}" = "aarch64" ] || [ "${ARCH}" = "arm64" ]; then
  ARCH="arm64"
  SUFFIX="v8"
fi
IMG=docker.io/"${ARCH}${SUFFIX}"/alpine:3.19
mkdir -p "${SYSEXTNAME}"
cat >"${SYSEXTNAME}"/build.sh <<EOF
#!/bin/sh
set -euo pipefail
apk --no-cache add \
        binutils \
        file \
        clang \
        file-dev \
        gcc \
        glib \
        glib-dev \
        ipset \
        ipset-dev \
        iptables \
        iptables-dev \
        libmagic-static \
        libmnl-dev \
        libnftnl-dev \
        libnl3-static \
        libnl3-dev \
        lld \
        lua5.4 \
        lua5.4-dev \
        lua5.4-libs \
        make \
        musl-dev \
        net-snmp-dev \
        openssl \
        openssl-dev \
        openssl-libs-static \
        pcre2 \
        pcre2-dev \
        zlib \
        zlib-dev \
        zlib-static \
        autoconf \
        automake zlib-static  alpine-sdk linux-headers libmnl-static git
cd /opt
git clone https://github.com/haproxy/haproxy.git
    cd /opt/haproxy && git checkout $VERSION && \
    make -j $(nproc) TARGET=linux-musl \
    USE_PTHREAD_EMULATION=1 USE_PCRE2=1 USE_OPENSSL=1 USE_SYSTEMD=1 USE_ZLIB=1 USE_LUA=1 \
    USE_CRYPT_H=1 USE_LINUX_TPROXY=1 USE_GETADDRINFO=1 PREFIX=/usr LUA_LIB_NAME=lua5.4 LUA_LDFLAGS='-L/usr/lib/lua5.4 -l:liblua.a' \
    CFLAGS='-static -s' LDFLAGS='-static -lc -ldl' THREAD_LDFLAGS='-lpthread' V=1 && \
    make PREFIX=/usr DESTDIR=/install_root install && \
    find /install_root && \
    rm -rf /install_root/usr/share && \
    rm -rf /install_root/usr/doc && \
    rm -rf /install_root/etc/sysconfig && \
    chown \$(stat -c %u:%g /install_root/build.sh) /install_root -R
EOF
chmod +x "${SYSEXTNAME}"/build.sh
docker run -v "${PWD}/${SYSEXTNAME}":/install_root/  --rm "${IMG}" /bin/sh -c /install_root/build.sh
mkdir -p  "${SYSEXTNAME}"/usr/lib/systemd/system/
cat > "${SYSEXTNAME}"/usr/lib/systemd/system/haproxy.service <<-'EOF'
[Unit]
Description=HAProxy Load Balancer
After=network-online.target
Wants=network-online.target

[Service]
ConfigurationDirectory=haproxy/conf.d
Environment="CONFIG=/etc/haproxy/haproxy.cfg" "PIDFILE=/var/run/haproxy.pid"
EnvironmentFile=-/usr/etc/sysconfig/haproxy
EnvironmentFile=-/etc/sysconfig/haproxy
ExecStartPre=/usr/sbin/haproxy -f $CONFIG -f $CONFIGURATION_DIRECTORY -c -q $OPTIONS
ExecStart=/usr/sbin/haproxy -Ws -f $CONFIG -f $CONFIGURATION_DIRECTORY -p $PIDFILE $OPTIONS
ExecReload=/usr/sbin/haproxy -f $CONFIG -f $CONFIGURATION_DIRECTORY -c -q $OPTIONS
ExecReload=/bin/kill -USR2 $MAINPID
SuccessExitStatus=143
KillMode=mixed
Type=notify

[Install]
WantedBy=multi-user.target
EOF

mkdir -p  "${SYSEXTNAME}"/usr/etc/sysconfig
cat > "${SYSEXTNAME}"/usr/etc/sysconfig/haproxy <<-'EOF'
# Add extra options to the haproxy daemon here. This can be useful for
# specifying multiple configuration files with multiple -f options.
# See haproxy(1) for a complete list of options.
OPTIONS=""
EOF

mkdir -p  "${SYSEXTNAME}"/usr/etc/haproxy/conf.d
cat > "${SYSEXTNAME}"/usr/etc/haproxy/haproxy.cfg.sample <<-'EOF'
#---------------------------------------------------------------------
# Example configuration for a possible web application.  See the
# full configuration options online.
#
#   https://www.haproxy.org/download/1.8/doc/configuration.txt
#
#---------------------------------------------------------------------

#---------------------------------------------------------------------
# Global settings
#---------------------------------------------------------------------
global
    # to have these messages end up in /var/log/haproxy.log you will
    # need to:
    #
    # 1) configure syslog to accept network log events.  This is done
    #    by adding the '-r' option to the SYSLOGD_OPTIONS in
    #    /etc/sysconfig/syslog
    #
    # 2) configure local2 events to go to the /var/log/haproxy.log
    #   file. A line like the following can be added to
    #   /etc/sysconfig/syslog
    #
    #    local2.*                       /var/log/haproxy.log
    #
    log         stdout format raw local0

    pidfile     /var/run/haproxy.pid
    maxconn     4000
    daemon

    # turn on stats unix socket
    stats socket /var/run/haproxy.stats mode 660 level admin
    stats timeout 5m

    # utilize system-wide crypto-policies
    ssl-default-bind-ciphers PROFILE=SYSTEM
    ssl-default-server-ciphers PROFILE=SYSTEM

#---------------------------------------------------------------------
# common defaults that all the 'listen' and 'backend' sections will
# use if not designated in their block
#---------------------------------------------------------------------
defaults
    mode                    http
    log                     global
    option                  httplog
    option                  dontlognull
    option http-server-close
    option forwardfor       except 127.0.0.0/8
    option                  redispatch
    retries                 3
    timeout http-request    10s
    timeout queue           1m
    timeout connect         10s
    timeout client          1m
    timeout server          1m
    timeout http-keep-alive 10s
    timeout check           10s
    maxconn                 3000

#---------------------------------------------------------------------
# main frontend which proxys to the backends
#---------------------------------------------------------------------
frontend main
    bind *:5000
    acl url_static       path_beg       -i /static /images /javascript /stylesheets
    acl url_static       path_end       -i .jpg .gif .png .css .js

    use_backend static          if url_static
    default_backend             app

#---------------------------------------------------------------------
# static backend for serving up images, stylesheets and such
#---------------------------------------------------------------------
backend static
    balance     roundrobin
    server      static 127.0.0.1:4331 check

#---------------------------------------------------------------------
# round robin balancing between the various backends
#---------------------------------------------------------------------
backend app
    balance     roundrobin
    server  app1 127.0.0.1:5001 check
    server  app2 127.0.0.1:5002 check
    server  app3 127.0.0.1:5003 check
    server  app4 127.0.0.1:5004 check
EOF

mkdir -p "${SYSEXTNAME}"/usr/lib/systemd/system/haproxy.service.d
cat > "${SYSEXTNAME}"/usr/lib/systemd/system/haproxy.service.d/10-haproxy.conf <<-'EOF'
[Service]
ExecCondition=/bin/bash -c 'set -e; mkdir -p /etc/haproxy/conf.d/; if [[ ! -e /etc/haproxy/haproxy.cfg && -e /usr/etc/haproxy/haproxy.cfg.sample ]]; then cp /usr/etc/haproxy/haproxy.cfg.sample /etc/haproxy/haproxy.cfg; fi'
EOF

mkdir -p "${SYSEXTNAME}"/usr/lib/systemd/system/multi-user.target.d
{ echo "[Unit]"; echo "Upholds=haproxy.service"; } > "${SYSEXTNAME}/usr/lib/systemd/system/multi-user.target.d/10-haproxy.conf"
rm -f "${SYSEXTNAME}"/build.sh
RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"

