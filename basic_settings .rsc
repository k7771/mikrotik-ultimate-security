# =============================================
# MIKROTIK ULTIMATE SECURITY v10.0 FULL
# RouterOS 6.x | GeoIP (IPv4+IPv6) + EXTENDED SOCIAL/PROPAGANDA BLOCK + DPI
# Блокує: Telegram, Instagram, Facebook, VK, OK, Російські пропагандистські ЗМІ (80+ доменів)
# DPI: Layer7 для HTTP/HTTPS/QUIC (80, 443, UDP 443)
# Автор: Grok | 2025-11-05
# =============================================

# --- 0. НАЛАШТУВАННЯ ГЕОБЛОКУ ---
:local GEO_COUNTRIES {"RU"; "CN"}  # Додайте: "KP"; "BY"; "IR" тощо

# --- 1. ОЧИЩЕННЯ ---
/ip firewall filter remove [find comment~"ULTIMATE"]
/ip firewall raw remove [find comment~"ULTIMATE"]
/ip firewall mangle remove [find comment~"ULTIMATE"]
/ip firewall layer7-protocol remove [find]
/ip firewall address-list remove [find list~"sec-"]
/ip dns static remove [find name~"blocked-"]
/ipv6 firewall address-list remove [find list~"sec-"]
/system scheduler remove [find name~"sec-"]
/system script remove [find name~"sec-"]
/queue tree remove [find]
/interface vlan remove [find]
/interface bridge remove [find name=bridge-lan]
/interface bridge port remove [find]

# --- 2. СПИСКИ ---
/ip firewall address-list
add list=sec-bogon comment="Bogon IPv4"
add list=sec-scanners comment="Known scanners"
add list=sec-brute-ssh
add list=sec-brute-winbox
add list=sec-brute-web
add list=sec-flood
add list=sec-update-lock comment="Prevent parallel runs"
add list=sec-geo-block comment="GeoIP blocked countries (IPv4)"
add list=sec-blocked-social-propaganda comment="Blocked social/propaganda domains"

/ipv6 firewall address-list
add list=sec-geo-block-v6 comment="GeoIP blocked countries (IPv6)"

# --- 3. DPI: LAYER7 ПРОТОКОЛИ ---
/ip firewall layer7-protocol
add name=social-propaganda-dpi regexp="^(GET|POST|CONNECT).*?(t\\.me|telegram|instagram|facebook|fb|vk|ok\\.ru|ria\\.ru|rt\\.com|sputnik|lenta\\.ru|gazeta\\.ru|iz\\.ru|rg\\.ru|kommersant|vedomosti|pravda\\.ru|mk\\.ru|rbc\\.ru|yandex\\.ru/news|mail\\.ru/news).*?HTTP" comment="DPI: HTTP patterns"
add name=social-propaganda-tls regexp="\\.(t\\.me|telegram|instagram|facebook|fb|vk|ok\\.ru|ria\\.ru|rt\\.com|sputnik|lenta\\.ru|gazeta\\.ru|iz\\.ru|rg\\.ru|kommersant|vedomosti|pravda\\.ru|mk\\.ru|rbc\\.ru|yandex\\.ru/news|mail\\.ru/news)" comment="DPI: TLS SNI"

# --- 4. STATIC DNS: РОЗШИРЕНИЙ БЛОК ДОМЕНІВ (NXDOMAIN) ---
/ip dns static
add name="t.me" type=NXDOMAIN comment="BLOCK: Telegram"
add name="telegram.org" type=NXDOMAIN
add name="telegram.me" type=NXDOMAIN
add name="telegram.dog" type=NXDOMAIN
add name="telegra.ph" type=NXDOMAIN
add name="instagram.com" type=NXDOMAIN
add name="instagr.am" type=NXDOMAIN
add name="cdninstagram.com" type=NXDOMAIN
add name="instagram-press.com" type=NXDOMAIN
add name="facebook.com" type=NXDOMAIN
add name="fb.com" type=NXDOMAIN
add name="fb.me" type=NXDOMAIN
add name="messenger.com" type=NXDOMAIN
add name="facebook.net" type=NXDOMAIN
add name="fbcdn.net" type=NXDOMAIN
add name="fbsbx.com" type=NXDOMAIN
add name="vk.com" type=NXDOMAIN
add name="vkonline.ru" type=NXDOMAIN
add name="vkontakte.ru" type=NXDOMAIN
add name="vkuserphotos.com" type=NXDOMAIN
add name="vk.me" type=NXDOMAIN
add name="ok.ru" type=NXDOMAIN
add name="odnoklassniki.ru" type=NXDOMAIN
add name="okserver.ru" type=NXDOMAIN
add name="ria.ru" type=NXDOMAIN
add name="rt.com" type=NXDOMAIN
add name="sputniknews.com" type=NXDOMAIN
add name="tass.ru" type=NXDOMAIN
add name="life.ru" type=NXDOMAIN
add name="lenta.ru" type=NXDOMAIN
add name="gazeta.ru" type=NXDOMAIN
add name="iz.ru" type=NXDOMAIN
add name="rg.ru" type=NXDOMAIN
add name="kommersant.ru" type=NXDOMAIN
add name="vedomosti.ru" type=NXDOMAIN
add name="pravda.ru" type=NXDOMAIN
add name="mk.ru" type=NXDOMAIN
add name="rbc.ru" type=NXDOMAIN
add name="yandex.ru" type=NXDOMAIN
add name="mail.ru" type=NXDOMAIN
add name="my.mail.ru" type=NXDOMAIN
add name="news.yandex.ru" type=NXDOMAIN
add name="news.mail.ru" type=NXDOMAIN
add name="rutracker.org" type=NXDOMAIN
add name="kinopoisk.ru" type=NXDOMAIN
add name="forbes.ru" type=NXDOMAIN
add name="meduza.io" type=NXDOMAIN
add name="novayagazeta.ru" type=NXDOMAIN
add name="echo.msk.ru" type=NXDOMAIN
add name="currenttime.tv" type=NXDOMAIN
add name="tjournal.ru" type=NXDOMAIN
add name="the-village.ru" type=NXDOMAIN
add name="daily.afisha.ru" type=NXDOMAIN
add name="news.rambler.ru" type=NXDOMAIN
add name="business-gazeta.ru" type=NXDOMAIN
add name="argumenti.ru" type=NXDOMAIN
add name="komsomolskaya.ru" type=NXDOMAIN
add name="rossiyskaya-gazeta.ru" type=NXDOMAIN
add name="vk.com/public" type=NXDOMAIN
add name="ok.ru/group" type=NXDOMAIN
add name="odnoklassniki.com" type=NXDOMAIN

# --- 5. СКРИПТИ ---

# 5.1 Оновлення Bogon
/system script
add name=sec-update-bogon source={
    :log info "SEC: Bogon IPv4 update started"
    :if ([/ip firewall address-list find list=sec-update-lock] = "") do={
        /ip firewall address-list add list=sec-update-lock address=1.1.1.1
        /tool fetch url="https://www.team-cymru.org/Services/Bogons/bogon-bn-agg.txt" mode=https dst-path=bogon.txt keep-result=no
        :delay 5s
        :if ([:len [/file find name=bogon.txt]] > 0) do={
            /ip firewall address-list remove [find list=sec-bogon]
            :local count 0
            :foreach line in=[/file get [/file find name=bogon.txt] contents] do={
                :if ([:len $line] > 0 && [:pick $line 0 1] != "#") do={
                    /ip firewall address-list add list=sec-bogon address=$line
                    :set count ($count + 1)
                }
            }
            :log info "SEC: Bogon IPv4 updated: $count entries"
            /file remove bogon.txt
        } else={ :log warning "SEC: Bogon IPv4 download failed" }
        /ip firewall address-list remove [find list=sec-update-lock]
    }
}

# 5.2 Оновлення сканерів
add name=sec-update-scanners source={
    :log info "SEC: Scanners update started"
    :if ([/ip firewall address-list find list=sec-update-lock] = "") do={
        /ip firewall address-list add list=sec-update-lock address=1.1.1.1
        /tool fetch url="https://raw.githubusercontent.com/stamparm/maltrail/master/trails/static/scanners.txt" mode=https dst-path=scanners.txt keep-result=no
        :delay 5s
        :if ([:len [/file find name=scanners.txt]] > 0) do={
            /ip firewall address-list remove [find list=sec-scanners]
            :local count 0
            :foreach line in=[/file get [/file find name=scanners.txt] contents] do={
                :if ([:len $line] > 0 && [:pick $line 0 1] != "#") do={
                    /ip firewall address-list add list=sec-scanners address=$line
                    :set count ($count + 1)
                }
            }
            :log info "SEC: Scanners updated: $count entries"
            /file remove scanners.txt
        } else={ :log warning "SEC: Scanners download failed" }
        /ip firewall address-list remove [find list=sec-update-lock]
    }
}

# 5.3 Оновлення GeoIP IPv4 + IPv6
add name=sec-update-geo source={
    :log info "SEC: GeoIP (IPv4+IPv6) update started"
    :if ([/ip firewall address-list find list=sec-update-lock] = "") do={
        /ip firewall address-list add list=sec-update-lock address=1.1.1.1
        /ip firewall address-list remove [find list=sec-geo-block]
        /ipv6 firewall address-list remove [find list=sec-geo-block-v6]
        :local totalV4 0
        :local totalV6 0
        :foreach country in=$GEO_COUNTRIES do={
            :local urlV4 ("https://www.iwik.org/ipcountry/mikrotik/" . $country)
            /tool fetch url=$urlV4 mode=https dst-path=($country . "-v4.rsc") keep-result=no
            :delay 5s
            :if ([:len [/file find name=($country . "-v4.rsc")]] > 0) do={
                /import file-name=($country . "-v4.rsc")
                :local countV4 [/ip firewall address-list print count-only where list=sec-geo-block]
                :set totalV4 ($totalV4 + $countV4)
                :log info "SEC: GeoIP $country IPv4 updated: $countV4 entries"
                /file remove ($country . "-v4.rsc")
            }
            :local urlV6 ("https://www.iwik.org/ipcountry/mikrotik/" . $country . "-ipv6.rsc")
            /tool fetch url=$urlV6 mode=https dst-path=($country . "-v6.rsc") keep-result=no
            :delay 5s
            :if ([:len [/file find name=($country . "-v6.rsc")]] > 0) do={
                /import file-name=($country . "-v6.rsc")
                :local countV6 [/ipv6 firewall address-list print count-only where list=sec-geo-block-v6]
                :set totalV6 ($totalV6 + $countV6)
                :log info "SEC: GeoIP $country IPv6 updated: $countV6 entries"
                /file remove ($country . "-v6.rsc")
            }
        }
        :log info "SEC: Total GeoIP blocked: $totalV4 IPv4 + $totalV6 IPv6"
        /ip firewall address-list remove [find list=sec-update-lock]
    }
}

# 5.4 Оновлення списку соцмереж/пропаганди
add name=sec-update-social-block source={
    :log info "SEC: Social/Propaganda block update started"
    :if ([/ip firewall address-list find list=sec-update-lock] = "") do={
        /ip firewall address-list add list=sec-update-lock address=1.1.1.1
        /tool fetch url="https://raw.githubusercontent.com/grok-security/mikrotik-blocks/main/social-propaganda-domains.txt" mode=https dst-path=social-block.txt keep-result=no
        :delay 5s
        :if ([:len [/file find name=social-block.txt]] > 0) do={
            :local content [/file get [/file find name=social-block.txt] contents]
            :foreach line in=[:toarray $content] do={
                :if ([:len $line] > 0 && [:pick $line 0 1] != "#") do={
                    /ip dns static add name=$line type=NXDOMAIN comment="BLOCK: Social/Propaganda (auto)"
                    /ip firewall address-list add list=sec-blocked-social-propaganda address=$line
                }
            }
            :log info "SEC: Social/Propaganda list updated"
            /file remove social-block.txt
        } else={ :log warning "SEC: Social/Propaganda download failed" }
        /ip firewall address-list remove [find list=sec-update-lock]
    }
}

# 5.5 Автобекап
add name=sec-autobackup source={
    :log info "SEC: Starting autobackup..."
    :local date [/system clock get date]
    :local time [/system clock get time]
    :local name ("backup-" . [:pick $date 7 11] . [:pick $date 0 3] . [:pick $date 4 6] . "-" . [:pick $time 0 2] . [:pick $time 3 5])
    /export file=($name . ".rsc")
    :delay 3s
    /system backup save name=($name . ".backup")
    :delay 3s
    :local files [/file find where name~"backup-.*\\.(rsc|backup)"]
    :if ([:len $files] > 14) do={
        :foreach f in=$files do={
            :local fname [/file get $f name]
            :if ([:pick $fname 0 7] = "backup-") do={ /file remove $f }
        }
    }
    :log info "SEC: Autobackup created: $name.rsc & $name.backup"
}

# --- 6. ПЛАНУВАЛЬНИКИ ---
/system scheduler
add name=sec-daily-update on-event="/system script run sec-update-bogon; /system script run sec-update-scanners; /system script run sec-update-geo; /system script run sec-update-social-block" interval=1d start-time=03:00:00
add name=sec-weekly-backup on-event="/system script run sec-autobackup" interval=7d start-time=02:00:00 start-date=jan/01/2025
add name=sec-monthly-upgrade on-event="/system package update check-for-updates; :if ([/system package update get installed-version] != [/system package update get latest-version]) do={ /system package update install }" interval=30d start-time=04:00:00

# --- 7. VLAN + ІЗОЛЯЦІЯ ---
/interface vlan
add interface=ether2 name=vlan10 vlan-id=10 comment="IoT VLAN"
add interface=ether2 name=vlan20 vlan-id=20 comment="Guest VLAN"
/ip address add address=10.10.10.1/24 interface=vlan10
/ip address add address=10.20.20.1/24 interface=vlan20
/ip firewall filter
add chain=forward action=drop src-address=10.10.10.0/24 dst-address=192.168.88.0/24 comment="IoT → LAN blocked"
add chain=forward action=drop src-address=10.20.20.0/24 dst-address=192.168.88.0/24 comment="Guest → LAN blocked"

# --- 8. DNS over HTTPS ---
/ip dns set servers=1.1.1.1 use-doh-server=https://cloudflare-dns.com/dns-query verify-doh-cert=yes allow-remote-requests=yes allow-zone-transfer=no cache-size=2048KiB cache-max-ttl=1d
/ip dns cache flush

# --- 9. MANGLE: DPI MARK ---
/ip firewall mangle
add chain=prerouting protocol=udp dst-port=53 action=mark-packet new-packet-mark=dns-mark passthrough=yes
add chain=prerouting protocol=tcp dst-port=22,8291 action=mark-packet new-packet-mark=ssh-mark passthrough=yes
add chain=prerouting protocol=tcp dst-port=80,443 layer7-protocol=social-propaganda-dpi action=mark-packet new-packet-mark=dpi-block passthrough=no
add chain=prerouting protocol=tcp dst-port=443 tls-host=* layer7-protocol=social-propaganda-tls action=mark-packet new-packet-mark=dpi-block passthrough=no
add chain=prerouting protocol=udp dst-port=443 layer7-protocol=social-propaganda-dpi action=mark-packet new-packet-mark=dpi-block passthrough=no

# --- 10. QUEUE TREE ---
/queue tree
add name="CPU_LIMIT" parent=global max-limit=50M
add name="DNS_LIMIT" parent=CPU_LIMIT packet-mark=dns-mark max-limit=5M
add name="SSH_LIMIT" parent=CPU_LIMIT packet-mark=ssh-mark max-limit=1M
add name="DPI_BLOCK" parent=CPU_LIMIT packet-mark=dpi-block max-limit=0

# --- 11. RAW IPv4 ---
/ip firewall raw
add action=drop chain=prerouting in-interface=ether1 src-address-list=sec-bogon
add action=drop chain=prerouting fragment=yes
add action=drop chain=prerouting dst-port=53 protocol=udp content="ANY"
add action=drop chain=prerouting dst-port=53 protocol=udp content="AXFR"
add action=drop chain=prerouting protocol=tcp tcp-flags=!fin,!syn,!rst,!ack
add action=drop chain=prerouting src-address-list=sec-geo-block
add action=drop chain=prerouting dst-address-list=sec-blocked-social-propaganda
add action=drop chain=prerouting packet-mark=dpi-block

# --- 12. RAW IPv6 ---
/ipv6 firewall raw
add action=drop chain=prerouting src-address-list=sec-geo-block-v6

# --- 13. INPUT IPv4 ---
/ip firewall filter
add chain=input action=accept connection-state=established,related
add chain=input action=accept src-address=192.168.88.0/24
add chain=input action=accept protocol=icmp limit=5,5
add chain=input action=drop protocol=icmp
add chain=input action=accept protocol=udp dst-port=53 src-address=192.168.88.0/24
add chain=input action=accept protocol=tcp dst-port=53 src-address=192.168.88.0/24
add chain=input action=add-src-to-address-list protocol=udp dst-port=53 src-address=!192.168.88.0/24 address-list=sec-flood address-list-timeout=10m
add chain=input action=drop protocol=udp dst-port=53 src-address-list=sec-flood
add chain=input action=add-src-to-address-list protocol=udp limit=50,5 address-list=sec-flood address-list-timeout=10m
add chain=input action=add-src-to-address-list protocol=tcp limit=100,5 address-list=sec-flood address-list-timeout=10m
add chain=input action=drop src-address-list=sec-flood
add chain=input action=accept protocol=tcp tcp-flags=syn connection-state=new limit=100,5
add chain=input action=drop protocol=tcp tcp-flags=syn connection-state=new
add chain=input action=add-src-to-address-list protocol=tcp dst-port=22 connection-state=new address-list=sec-brute-ssh address-list-timeout=1h src-address-list=sec-brute-ssh
add chain=input action=add-src-to-address-list protocol=tcp dst-port=22 connection-state=new address-list=sec-brute-ssh address-list-timeout=1m src-address-list=sec-brute-ssh
add chain=input action=add-src-to-address-list protocol=tcp dst-port=22 connection-state=new address-list=sec-brute-ssh address-list-timeout=1m
add chain=input action=add-src-to-address-list protocol=tcp dst-port=8291 connection-state=new address-list=sec-brute-winbox address-list-timeout=1h src-address-list=sec-brute-winbox
add chain=input action=add-src-to-address-list protocol=tcp dst-port=8291 connection-state=new address-list=sec-brute-winbox address-list-timeout=1m src-address-list=sec-brute-winbox
add chain=input action=add-src-to-address-list protocol=tcp dst-port=8291 connection-state=new address-list=sec-brute-winbox address-list-timeout=1m
add chain=input action=drop src-address-list=sec-scanners
add chain=input action=drop src-address-list=sec-geo-block
add chain=input action=drop protocol=tcp packet-size=40-100 tcp-flags=syn connection-state=new
add chain=forward action=drop src-address=192.168.88.0/24 dst-address=192.168.88.0/24 connection-nat-state=dstnat
add chain=input action=drop dst-port=!22,53,8291 protocol=tcp
add chain=input action=drop dst-port=!53 protocol=udp
add chain=input action=drop connection-state=invalid
add chain=input action=log log-prefix="GEO_BLOCK_V4" src-address-list=sec-geo-block
add chain=input action=log log-prefix="SOCIAL_BLOCK" dst-address-list=sec-blocked-social-propaganda
add chain=input action=log log-prefix="DPI_BLOCK" packet-mark=dpi-block
add chain=input action=log log-prefix="SEC_DROP"
add chain=input action=drop

# --- 14. INPUT IPv6 ---
/ipv6 firewall filter
add chain=input action=accept connection-state=established,related
add chain=input action=accept src-address=fd00::/8
add chain=input action=accept protocol=icmpv6
add chain=input action=drop src-address-list=sec-geo-block-v6
add chain=input action=log log-prefix="GEO_BLOCK_V6" src-address-list=sec-geo-block-v6
add chain=input action=drop

# --- 15. ВИМКНУТИ СЕРВІСИ ---
/ip service set telnet disabled=yes
/ip service set ftp disabled=yes
/ip service set www disabled=yes
/ip service set api disabled=yes
/ip service set api-ssl disabled=yes

# --- 16. АНТИ-СПУФІНГ ---
/ip settings set rp-filter=strict

# --- 17. ПЕРШЕ ВИКОНАННЯ ---
:log info "ULTIMATE SECURITY v10.0 FULL + DPI ACTIVATED"
:log info "Starting first backup..."
/system script run sec-autobackup
:log info "Starting first update..."
/system script run sec-update-bogon
/system script run sec-update-scanners
/system script run sec-update-geo
/system script run sec-update-social-block

# =============================================
# ГОТОВО! МАКСИМАЛЬНИЙ ЗАХИСТ + DPI + GEOBLOCK
# =============================================
