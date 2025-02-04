
FROM ubuntu:22.04


ENV DEBIAN_FRONTEND=noninteractive


RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
    gcc \
    make \
    build-essential \
    autoconf \
    automake \
    libtool \
    libcurl4-openssl-dev \
    liblua5.4-dev \
    libfuzzy-dev \
    ssdeep \
    gettext \
    pkg-config \
    libgeoip-dev \
    libyajl-dev \
    doxygen \
    libpcre++-dev \
    libpcre2-16-0 \
    libpcre2-dev \
    libpcre2-posix3 \
    zlib1g \
    zlib1g-dev \
    wget \
    git \
    libssl-dev \
    libpcre3-dev \
    lua5.4 \
    libmaxminddb-dev \
    libxml2-dev \
    libjansson-dev

RUN cd /opt && \
    git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity && \
    cd ModSecurity && \
    git submodule init && \
    git submodule update && \
    ./build.sh && \
    ./configure && \
    make && \
    make install


RUN cd /opt && \
    wget https://www.haproxy.org/download/3.0/src/haproxy-3.0.8.tar.gz && \
    tar xzf haproxy-3.0.8.tar.gz && \
    cd haproxy-3.0.8 && \
    make  TARGET=linux-glibc USE_OPENSSL=1 USE_ZLIB=1 USE_PCRE=1 USE_LUA=1 LUA_LIB=/usr/lib/x86_64-linux-gnu/ LUA_INC=/usr/include/lua5.4/ && \
    make install


RUN mkdir /etc/modsecurity && \
    cp /opt/ModSecurity/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf && \
    cp /opt/ModSecurity/unicode.mapping /etc/modsecurity/ && \
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf


RUN cd /opt && \
    git clone --depth 1 https://github.com/coreruleset/coreruleset.git && \
    mv coreruleset /etc/modsecurity/crs && \
    cp /etc/modsecurity/crs/crs-setup.conf.example /etc/modsecurity/crs/crs-setup.conf


RUN echo 'Include /etc/modsecurity/modsecurity.conf' > /etc/modsecurity/haproxy-modsecurity.conf && \
    echo 'Include /etc/modsecurity/crs/crs-setup.conf' >> /etc/modsecurity/haproxy-modsecurity.conf && \
    echo 'Include /etc/modsecurity/crs/rules/*.conf' >> /etc/modsecurity/haproxy-modsecurity.conf


RUN mkdir /var/log/modsecurity && \
    chown -R nobody /var/log/modsecurity


COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg


EXPOSE 9999


CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg", "-db"]
