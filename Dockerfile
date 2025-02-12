# Używamy Ubuntu 22.04 jako obrazu bazowego
FROM ubuntu:22.04

# Ustawienie nieinteraktywnego trybu instalacji
ENV DEBIAN_FRONTEND=noninteractive

# Aktualizacja systemu i instalacja niezbędnych pakietów
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
      gcc \
      make \
      build-essential \
      autoconf \
      automake \
      libtool \
      libcurl4-openssl-dev \
      liblua5.3-dev \
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
      lua5.3 \
      libmaxminddb-dev \
      libxml2-dev \
      libjansson-dev

# Pobranie i instalacja ModSecurity v3 (WAF)
RUN cd /opt && \
    git clone --depth 1 -b v3/master --single-branch https://github.com/SpiderLabs/ModSecurity && \
    cd ModSecurity && \
    git submodule init && \
    git submodule update && \
    ./build.sh && \
    ./configure && \
    make && \
    make install

# Pobranie i instalacja HAProxy z obsługą LUA
RUN cd /opt && \
    wget http://www.haproxy.org/download/2.6/src/haproxy-2.6.6.tar.gz && \
    tar xzf haproxy-2.6.6.tar.gz && \
    cd haproxy-2.6.6 && \
    make TARGET=linux-glibc USE_OPENSSL=1 USE_ZLIB=1 USE_PCRE=1 USE_LUA=1 LUA_LIB=/usr/lib/x86_64-linux-gnu/ LUA_INC=/usr/include/lua5.3/ && \
    make install

# Konfiguracja ModSecurity:
# - kopiujemy przykładowy plik konfiguracyjny,
# - kopiujemy mapowanie znaków (unicode.mapping),
# - włączamy tryb "On" (zamiast DetectionOnly)
RUN mkdir /etc/modsecurity && \
    cp /usr/local/modsecurity/etc/modsecurity.conf-recommended /etc/modsecurity/modsecurity.conf && \
    cp /opt/ModSecurity/unicode.mapping /etc/modsecurity/ && \
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/modsecurity/modsecurity.conf

# Pobranie OWASP CRS (Core Rule Set)
RUN cd /opt && \
    git clone --depth 1 https://github.com/coreruleset/coreruleset.git && \
    mv coreruleset /etc/modsecurity/crs && \
    cp /etc/modsecurity/crs/crs-setup.conf.example /etc/modsecurity/crs/crs-setup.conf

# Utworzenie łączonej konfiguracji dla ModSecurity (dla przykładowej integracji)
RUN echo 'Include /etc/modsecurity/modsecurity.conf' > /etc/modsecurity/haproxy-modsecurity.conf && \
    echo 'Include /etc/modsecurity/crs/crs-setup.conf' >> /etc/modsecurity/haproxy-modsecurity.conf && \
    echo 'Include /etc/modsecurity/crs/rules/*.conf' >> /etc/modsecurity/haproxy-modsecurity.conf

# Utworzenie katalogu na logi ModSecurity
RUN mkdir /var/log/modsecurity && \
    chown -R nobody /var/log/modsecurity

# Skopiowanie konfiguracji HAProxy
COPY haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg

# Skopiowanie skryptu LUA, który symuluje wywołanie WAF (ModSecurity)
COPY modsecurity.lua /usr/local/etc/haproxy/modsecurity.lua

# Otwieramy porty 80 i 443
EXPOSE 80 443

# Uruchomienie HAProxy w trybie pierwszoplanowym (foreground)
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg", "-db"]
