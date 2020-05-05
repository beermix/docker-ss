FROM alpine:edge

ARG TZ='Europe/Moscow'

ENV TZ ${TZ}
ENV SS_LIBEV_VERSION v3.3.4
ENV KCP_VERSION 20200409
ENV V2RAY_PLUGIN_VERSION v1.3.0
ENV SODIUM_DOWNLOAD_URL https://github.com/jedisct1/libsodium.git
ENV SS_DOWNLOAD_URL https://github.com/shadowsocks/shadowsocks-libev.git
ENV KCP_DOWNLOAD_URL https://github.com/xtaci/kcptun/releases/download/v${KCP_VERSION}/kcptun-linux-amd64-${KCP_VERSION}.tar.gz
ENV PLUGIN_OBFS_DOWNLOAD_URL https://github.com/shadowsocks/simple-obfs.git
ENV PLUGIN_V2RAY_DOWNLOAD_URL https://github.com/shadowsocks/v2ray-plugin/releases/download/${V2RAY_PLUGIN_VERSION}/v2ray-plugin-linux-amd64-${V2RAY_PLUGIN_VERSION}.tar.gz
ENV LINUX_HEADERS_DOWNLOAD_URL=http://dl-cdn.alpinelinux.org/alpine/v3.11/main/x86_64/linux-headers-4.19.36-r0.apk

RUN apk upgrade --update \
    && apk add bash tzdata rng-tools runit \
    && apk add --virtual .build-deps \
        autoconf \
        automake \
        build-base \
        curl \
        c-ares-dev \
        libev-dev \
        libtool \
        libcap \
        mbedtls-dev \
        mbedtls-static \
        pcre-dev \
        udns-dev \
        gawk \
        tar \
        sed \
        git \
        alpine-sdk \
        ca-certificates \
        cmake \
    && curl -sSL ${LINUX_HEADERS_DOWNLOAD_URL} > /linux-headers-4.19.36-r0.apk \
    && apk add --virtual .build-deps-kernel /linux-headers-4.19.36-r0.apk \
    && git clone --depth 1 ${SODIUM_DOWNLOAD_URL} -b stable \
    && (cd libsodium \
    && ./autogen.sh \
    && ./configure --prefix=/usr --enable-opt --enable-minimal --enable-static --enable-shared \
    && make install -j2) \
    && git clone --depth 1 --recursive ${SS_DOWNLOAD_URL} \
    && (cd shadowsocks-libev \
    && cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr -DWITH_DOC_HTML=0 -DWITH_DOC_MAN=0 -DWITH_EMBEDDED_SRC=1 -DWITH_SS_REDIR=0 -DWITH_STATIC=1 \
    && make -j2 && strip -s ./bin/ss-server && cp ./bin/ss-server /usr/bin/ss-server) \
    && git clone --depth 1 --recursive ${PLUGIN_OBFS_DOWNLOAD_URL} \
    && (cd simple-obfs \
    && ./autogen.sh \
    && ./configure --disable-documentation --disable-assert --disable-ssp \
    && make install -j2) \
    && curl -o v2ray_plugin.tar.gz -sSL ${PLUGIN_V2RAY_DOWNLOAD_URL} \
    && tar -zxf v2ray_plugin.tar.gz \
    && mv v2ray-plugin_linux_amd64 /usr/bin/v2ray-plugin \
    && curl -sSLO ${KCP_DOWNLOAD_URL} \
    && tar -zxf kcptun-linux-amd64-${KCP_VERSION}.tar.gz \
    && mv server_linux_amd64 /usr/bin/kcpserver \
    && mv client_linux_amd64 /usr/bin/kcpclient \
    && for binPath in `ls /usr/bin/ss-* /usr/local/bin/obfs-* /usr/bin/kcp* /usr/bin/v2ray*`; do \
            setcap CAP_NET_BIND_SERVICE=+eip $binPath; \
       done \
    && ln -sf /usr/share/zoneinfo/${TZ} /etc/localtime \
    && echo ${TZ} > /etc/timezone \
    && adduser -h /tmp -s /sbin/nologin -S -D -H shadowsocks \
    && adduser -h /tmp -s /sbin/nologin -S -D -H kcptun \
    && apk del .build-deps .build-deps-kernel \
    && apk add --no-cache \
      $(scanelf --needed --nobanner /usr/bin/ss-* /usr/local/bin/obfs-* \
      | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
      | sort -u) \
    && rm -rf /linux-headers-4.19.36-r0.apk \
        kcptun-linux-amd64-${KCP_VERSION}.tar.gz \
        shadowsocks-libev \
        simple-obfs \
        v2ray_plugin.tar.gz \
        /etc/service \
        /var/cache/apk/*

SHELL ["/bin/bash"]

ADD sysctl.conf /etc/sysctl.conf
COPY runit /etc/service
COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
