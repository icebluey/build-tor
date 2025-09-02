# Tor
Fresh [geoip](https://github.com/icebluey/torgeoip) files.
```
cd /usr/share/tor/ && rm -vf geoip geoip6 geoip-plus-asn geoip6-plus-asn && wget https://github.com/icebluey/torgeoip/releases/latest/download/geoip.tar.xz && tar -xof geoip.tar.xz && sleep 1 && rm -vf geoip.tar* asn.txt version && systemctl restart tor
```

```
curl -x "socks5://127.0.0.1:9050" https://ipinfo.io 2>/dev/null | jq .
```
