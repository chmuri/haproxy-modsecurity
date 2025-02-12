# Dockerfile dla HAProxy z Coraza-SPOA na Ubuntu 24.04

FROM ubuntu:24.04

# Ustawienie trybu nieinteraktywnego
ENV DEBIAN_FRONTEND=noninteractive

# Aktualizacja systemu i instalacja podstawowych pakietów
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y \
        pkg-config \
        make \
        gcc \
        git \
        curl \
        lsb-release \
        gnupg \
        golang-go

# Dodanie repozytorium HAProxy 3.0 i instalacja HAProxy
RUN curl -fsSL https://haproxy.debian.net/bernat.de.gpg | gpg --dearmor -o /usr/share/keyrings/haproxy-archive-keyring.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/haproxy-archive-keyring.gpg] http://haproxy.debian.net/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/haproxy.list && \
    apt-get update && \
    apt-get install -y haproxy

# Klonowanie i kompilacja Coraza-SPOA
RUN git clone https://github.com/corazawaf/coraza-spoa.git /opt/coraza-spoa && \
    cd /opt/coraza-spoa && \
    make

# Utworzenie grupy i użytkownika dla coraza-spoa
RUN addgroup --system coraza-spoa && \
    adduser --system --ingroup coraza-spoa --no-create-home --home /nonexistent --disabled-password coraza-spoa

# Utworzenie katalogów konfiguracyjnych oraz logów dla Coraza-SPOA
RUN mkdir -p /etc/coraza-spoa && \
    mkdir -p /var/log/coraza-spoa /var/log/coraza-spoa/audit && \
    touch /var/log/coraza-spoa/server.log /var/log/coraza-spoa/error.log /var/log/coraza-spoa/audit.log /var/log/coraza-spoa/debug.log

# Skopiowanie skompilowanego binarki Coraza-SPOA
RUN cp /opt/coraza-spoa/coraza-spoa_amd64 /usr/bin/coraza-spoa && \
    chmod 755 /usr/bin/coraza-spoa

# Utworzenie pliku konfiguracyjnego SPOA (config.yaml)
RUN bash -c 'cat << "EOF" > /etc/coraza-spoa/config.yaml
# The SPOA server bind address
bind: 127.0.0.1:9000

# Process request and response with this application if provided app name is not found.
# You can remove or comment out this config param if you don'\''t need "default_application" functionality.
default_application: haproxy_waf

applications:
  haproxy_waf:
    # Get the coraza.conf from https://github.com/corazawaf/coraza
    #
    # Download the OWASP CRS from https://github.com/coreruleset/coreruleset/releases
    # and copy crs-setup.conf & the rules, plugins directories to /etc/coraza-spoa
    directives: |
      Include /etc/coraza-spoa/coraza.conf
      Include /etc/coraza-spoa/crs-setup.conf
      Include /etc/coraza-spoa/plugins/*-config.conf
      Include /etc/coraza-spoa/plugins/*-before.conf
      Include /etc/coraza-spoa/rules/*.conf
      Include /etc/coraza-spoa/plugins/*-after.conf

    # HAProxy configured to send requests only, that means no cache required
    # NOTE: there are still some memory & caching issues, so use this with care
    no_response_check: true

    # The transaction cache lifetime in milliseconds (60000ms = 60s)
    transaction_ttl_ms: 60000
    # The maximum number of transactions which can be cached
    transaction_active_limit: 100000

    # The log level configuration, one of: debug/info/warn/error/panic/fatal
    log_level: info
    # The log file path
    log_file: /var/log/coraza-spoa/coraza-agent.log
EOF'

# Pobranie zalecanej konfiguracji Coraza i włączenie reguł
RUN curl -fsSL https://raw.githubusercontent.com/corazawaf/coraza/main/coraza.conf-recommended -o /etc/coraza-spoa/coraza.conf && \
    sed -i 's/SecRuleEngine DetectionOnly/SecRuleEngine On/' /etc/coraza-spoa/coraza.conf

# Klonowanie i kopiowanie OWASP CRS (Core Rule Set)
RUN mkdir -p /opt/coraza-crs && \
    cd /opt/coraza-crs && \
    git clone https://github.com/coreruleset/coreruleset.git && \
    cp coreruleset/crs-setup.conf.example /etc/coraza-spoa/crs-setup.conf && \
    cp -R coreruleset/rules /etc/coraza-spoa && \
    cp -R coreruleset/plugins /etc/coraza-spoa

# Ustawienie uprawnień dla konfiguracji Coraza-SPOA
RUN chown -R coraza-spoa:coraza-spoa /etc/coraza-spoa && \
    chmod 700 /etc/coraza-spoa && \
    chmod -R 600 /etc/coraza-spoa/* && \
    chmod 700 /etc/coraza-spoa/rules && \
    chmod 700 /etc/coraza-spoa/plugins

# Konfiguracja integracji HAProxy ze SPOA:
# Kopiujemy plik coraza.cfg (dostarczony w build context) do /etc/haproxy i modyfikujemy jego zawartość
COPY coraza.cfg /etc/haproxy/coraza.cfg
RUN sed -i 's/app=str(sample_app) id=unique-id src-ip=src/app=str(haproxy_waf) id=unique-id src-ip=src/' /etc/haproxy/coraza.cfg && \
    sed -i 's/app=str(sample_app) id=unique-id version=res.ver/app=str(haproxy_waf) id=unique-id version=res.ver/' /etc/haproxy/coraza.cfg && \
    sed -i 's|event on-http-response|event on-http-response\n|' /etc/haproxy/coraza.cfg && \
    chown haproxy /etc/haproxy/coraza.cfg && \
    chmod 600 /etc/haproxy/coraza.cfg

# Zamiana domyślnego pliku konfiguracyjnego HAProxy na nowy (haproxy.conf z build context)
RUN mv /etc/haproxy/haproxy.cfg /etc/haproxy/haproxy.cfg_orig
COPY haproxy.conf /etc/haproxy/haproxy.cfg
RUN sed -i -e '$a\' /etc/haproxy/haproxy.cfg

# Kopiujemy skrypt startowy, który uruchamia jednocześnie coraza-spoa i HAProxy
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Otwieramy port 80 (HAProxy będzie nasłuchiwać na tym porcie)
EXPOSE 80

# Domyślne polecenie uruchamiające skrypt startowy
CMD ["/start.sh"]
