#!/bin/bash
set -e

# Uruchomienie coraza-spoa w tle (z podaną konfiguracją)
# UWAGA: Opcje uruchomieniowe mogą być modyfikowane zgodnie z dokumentacją SPOA
/usr/bin/coraza-spoa -config /etc/coraza-spoa/config.yaml &

# Uruchomienie HAProxy w trybie pierwszoplanowym (-db wyłącza demona)
exec haproxy -f /etc/haproxy/haproxy.cfg -db
