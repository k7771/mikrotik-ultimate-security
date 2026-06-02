# =============================================
# MIKROTIK ULTIMATE SECURITY v11.0 for RouterOS 7+
# GeoIP (IPv4+IPv6) + SOCIAL/PROPAGANDA BLOCK + TLS SNI + QUIC
# Блокує: Telegram, Instagram, Facebook, VK, OK, РФ пропаганда
# Автор: Grok | Оновлено: 2026-06
# =============================================

# --- 0. НАЛАШТУВАННЯ ---
:local GEO_COUNTRIES {"RU"; "CN"}  # Додай: "BY"; "IR"; "KP" тощо

# --- 1. ОЧИЩЕННЯ ---
/ip firewall filter remove [find comment\~"ULTIMATE"]
/ip firewall raw remove [find comment\~"ULTIMATE"]
/ip firewall mangle remove [find comment\~"ULTIMATE"]
/ip firewall layer7-protocol remove [find]
/ip firewall address-list remove [find list\~"sec-"]
/ip dns static remove [find comment\~"BLOCK:"]
/ipv6 firewall address-list remove [find list\~"sec-"]
/system scheduler remove [find name\~"sec-"]
/system script remove [find name\~"sec-"]
/queue tree remove [find]
/interface bridge port remove [find where bridge=bridge-lan]

:log info "ULTIMATE SECURITY v11.0 - Очищення завершено"

# --- 2. ADDRESS LISTS ---
/ip firewall address-list
add list=sec-bogon comment="Bogon IPv4"
add list=sec-scanners comment="Known scanners"
add list=sec-brute-ssh
add list=sec-brute-winbox
add list=sec-brute-web
add list=sec-flood
add list=sec-update-lock
add list=sec-geo-block comment="GeoIP blocked (IPv4)"
add list=sec-blocked-social comment="Blocked social/propaganda"

/ipv6 firewall address-list
add list=sec-geo-block-v6 comment="GeoIP blocked (IPv6)"

# --- 3. STATIC DNS BLOCK (швидкий NXDOMAIN) ---
/ip dns static
add name="t.me" type=NXDOMAIN comment="BLOCK: Telegram"
add name="telegram.org" type=NXDOMAIN comment="BLOCK: Telegram"
add name="instagram.com" type=NXDOMAIN comment="BLOCK: Instagram"
add name="facebook.com" type=NXDOMAIN comment="BLOCK: Facebook"
add name="fb.com" type=NXDOMAIN comment="BLOCK: Facebook"
add name="vk.com" type=NXDOMAIN comment="BLOCK: VK"
add name="ok.ru" type=NXDOMAIN comment="BLOCK: OK"
add name="ria.ru" type=NXDOMAIN comment="BLOCK: Propaganda"
add name="rt.com" type=NXDOMAIN comment="BLOCK: Propaganda"
# ... (можна розширити)

# --- 4. СКРИПТИ ОНОВЛЕННЯ ---

# 4.1 Bogon
/system script add name=sec-update-bogon source={
    :log info "SEC: Bogon update started"
    :if ([/ip firewall address-list find list=sec-update-lock] = "") do={
        /ip firewall address-list add list=sec-update-lock address=1.1.1.1
        /tool fetch url="https://www.team-cymru.org/Services/Bogons/bogon-bn-agg.txt" mode=https dst-path=bogon.txt keep-result=no
        :delay 5s
        :if ([/file find name=bogon.txt] != "") do={
            /ip firewall address-list remove [find list=sec-bogon]
            :local count 0
            :foreach line in=[/file get [/file find name=bogon.txt] contents] do={
                :if ([:len $line] > 0 && [:pick $line 0 1] != "#") do={
                    /ip firewall address-list add list=sec-bogon address=$line
                    :set count ($count + 1)
                }
            }
            :log info "SEC: Bogon updated ($count entries)"
            /file remove bogon.txt
        }
        /ip firewall address-list remove [find list=sec-update-lock]
    }
}

# 4.2 Scanners
/system script add name=sec-update-scanners source={
    :log info "SEC: Scanners update started"
    :if ([/ip firewall address-list find list=sec-update-lock] = "") do={
        /ip firewall address-list add list=sec-update-lock address=1.1.1.1
        /tool fetch url="https://raw.githubusercontent.com/stamparm/maltrail/master/trails/static/scanners.txt" mode=https dst-path=scanners.txt keep-result=no
        :delay 5s
        :if ([/file find name=scanners.txt] != "") do={
            /ip firewall address-list remove [find list=sec-scanners]
            :local count 0
            :foreach line in=[/file get [/file find name=scanners.txt] contents] do={
                :if ([:len $line] > 0 && [:pick $line 0 1] != "#") do={
                    /ip firewall address-list add list=sec-scanners address=$line
                    :set count ($count + 1)
                }
            }
            :log info "SEC: Scanners updated ($count entries)"
            /file remove scanners.txt
        }
        /ip firewall address-list remove [find list=sec-update-lock]
    }
}

# 4.3 GeoIP
/system script add name=sec-update-geo source={
    :log info "SEC: GeoIP update started"
    :if ([/ip firewall address-list find list=sec-update-lock] = "") do={
        /ip firewall address-list add list=sec-update-lock address=1.1.1.1
        /ip firewall address-list remove [find list=sec-geo-block]
        /ipv6 firewall address-list remove [find list=sec-geo-block-v6]

        :local totalV4 0; :local totalV6 0
        :foreach country in=$GEO_COUNTRIES do={
            :local urlV4 ("https://www.iwik.org/ipcountry/mikrotik/" . $country)
            /tool fetch url=$urlV4 mode=https dst-path=($country."-v4.rsc") keep-result=no
            :delay 4s
            :if ([/file find name=($country."-v4.rsc")] != "") do={
                /import file-name=($country."-v4.rsc")
                :set totalV4 ([/ip firewall address-list print count-only where list=sec-geo-block])
                /file remove ($country."-v4.rsc")
            }

            :local urlV6 ("https://www.iwik.org/ipcountry/mikrotik/" . $country . "-ipv6.rsc")
            /tool fetch url=$urlV6 mode=https dst-path=($country."-v6.rsc") keep-result=no
            :delay 4s
            :if ([/file find name=($country."-v6.rsc")] != "") do={
                /import file-name=($country."-v6.rsc")
                :set totalV6 ([/ipv6 firewall address-list print count-only where list=sec-geo-block-v6])
                /file remove ($country."-v6.rsc")
            }
        }
        :log info "SEC: GeoIP updated - $totalV4 IPv4 + $totalV6 IPv6"
        /ip firewall address-list remove [find list=sec-update-lock]
    }
}

# 4.4 Social + Propaganda (через DNS + address-list)
# (можна замінити на зовнішній список)

# 4.5 Autobackup
/system script add name=sec-autobackup source={
    :log info "SEC: Autobackup started"
    :local name ("backup-".[:pick [/system clock get date] 7 11].[:pick [/system clock get date] 4 6].[:pick [/system clock get date] 0 3]."-".[:pick [/system clock get time] 0 2].[:pick [/system clock get time] 3 5])
    /export terse file=($name.".rsc")
    /system backup save name=($name.".backup")
    :log info "SEC: Backup created: $name"
}

# --- 5. SCHEDULER ---
/system scheduler
add name=sec-daily-update interval=1d start-time=03:10:00 on-event="/system script run sec-update-bogon; /system script run sec-update-scanners; /system script run sec-update-geo"
add name=sec-weekly-backup interval=7d start-time=02:00:00 on-event="/system script run sec-autobackup"

# --- 6. DNS ---
/ip dns set servers=1.1.1.1,1.0.0.1 use-doh-server=https://cloudflare-dns.com/dns-query verify-doh-cert=yes allow-remote-requests=yes

# --- 7. MANGLE (для логів/маркування) ---
/ip firewall mangle
add chain=prerouting action=mark-packet new-packet-mark=dpi-social passthrough=no protocol=tcp dst-port=443 tls-host=\~"(t\\.me|telegram|instagram|facebook|fb|vk|ok\\.ru|rt\\.com|ria\\.ru|sputniknews)" comment="ULTIMATE: Social TLS mark"

# --- 8. RAW (найшвидший захист) ---
/ip firewall raw
add action=drop chain=prerouting src-address-list=sec-bogon comment="ULTIMATE: Drop Bogon"
add action=drop chain=prerouting fragment=yes comment="ULTIMATE: Drop fragments"
add action=drop chain=prerouting protocol=tcp tcp-flags=!syn,!ack,!rst,!fin comment="ULTIMATE: Invalid TCP flags"
add action=drop chain=prerouting src-address-list=sec-geo-block comment="ULTIMATE: Geo Block IPv4"
add action=drop chain=prerouting protocol=udp dst-port=443 content="t.me|telegram|instagram|facebook|vk.com|ok.ru" comment="ULTIMATE: QUIC Social Block"
add action=drop chain=prerouting dst-port=443 protocol=udp tls-host=\~"(telegram|instagram|facebook|vk|ok)" comment="ULTIMATE: QUIC TLS Block"  ;# v7.15+

# --- 9. FILTER INPUT ---
/ip firewall filter
add chain=input action=accept connection-state=established,related,untracked comment="ULTIMATE: Accept established"
add chain=input action=accept src-address=192.168.0.0/16 comment="ULTIMATE: LAN access"
add chain=input action=accept protocol=icmp limit=5,5:packet
add chain=input action=drop protocol=icmp
add chain=input action=accept protocol=udp dst-port=53 src-address=192.168.0.0/16
add chain=input action=accept protocol=tcp dst-port=53 src-address=192.168.0.0/16

# Brute-force protection
add chain=input action=add-src-to-address-list protocol=tcp dst-port=22,8291 connection-state=new address-list=sec-brute-ssh address-list-timeout=1h
add chain=input action=drop src-address-list=sec-brute-ssh

add chain=input action=drop src-address-list=sec-scanners
add chain=input action=drop src-address-list=sec-geo-block
add chain=input action=drop connection-state=invalid
add chain=input action=drop comment="ULTIMATE: Drop all other input"

# --- 10. FILTER FORWARD (блокування контенту) ---
/ip firewall filter
add chain=forward action=drop protocol=tcp dst-port=443 tls-host=\~"(t\\.me|telegram|instagram|facebook|fb|vk\\.com|ok\\.ru|rt\\.com|ria\\.ru|sputnik)" comment="ULTIMATE: Block Social TLS"
add chain=forward action=drop protocol=udp dst-port=443 content="t.me|telegram|instagram|facebook|vk|ok.ru" comment="ULTIMATE: Block QUIC Social"
add chain=forward action=drop dst-address-list=sec-blocked-social comment="ULTIMATE: Block Social IP"

# --- 11. ВИМКНЕННЯ СЕРВІСІВ ---
/ip service set telnet,ftp,www,api,api-ssl disabled=yes
/ip settings set rp-filter=strict

:log info "=== ULTIMATE SECURITY v11.0 for ROS7+ УСПІШНО ЗАВАНТАЖЕНО ==="
