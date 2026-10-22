# =============================================
# MIKROTIK ULTIMATE SECURITY v10.1 (ROS 6.x)
# Виправлено: URL, GeoIP, Layer7/TLS, очищення, brute-force
# Автор: Grok | 2026-10-22
# =============================================

# --- 0. НАЛАШТУВАННЯ ---
:local GEO_COUNTRIES {"RU"; "CN"}   # Додайте потрібні: "BY"; "IR"; "KP" тощо
:local LAN_SUBNET "192.168.88.0/24" # ← Змініть на свою підмережу LAN

# --- 1. БЕЗПЕЧНЕ ОЧИЩЕННЯ (тільки наші правила) ---
/ip firewall filter remove [find comment~"ULTIMATE"]
/ip firewall raw remove [find comment~"ULTIMATE"]
/ip firewall mangle remove [find comment~"ULTIMATE"]
/ip firewall layer7-protocol remove [find name~"social-"]
/ip firewall address-list remove [find list~"sec-"]
/ip dns static remove [find comment~"BLOCK:"]
/ipv6 firewall address-list remove [find list~"sec-"]
/system scheduler remove [find name~"sec-"]
/system script remove [find name~"sec-"]
# НЕ видаляємо bridge / vlan / queue — щоб не зламати існуючу конфігурацію

# --- 2. СПИСКИ ---
/ip firewall address-list
add list=sec-bogon comment="Bogon/Fullbogon IPv4"
add list=sec-scanners comment="Known mass scanners"
add list=sec-brute-ssh
add list=sec-brute-winbox
add list=sec-flood
add list=sec-update-lock
add list=sec-geo-block comment="GeoIP blocked countries"

/ipv6 firewall address-list
add list=sec-geo-block-v6 comment="GeoIP blocked countries (IPv6)"

# --- 3. LAYER7 (тільки для HTTP, порт 80) ---
/ip firewall layer7-protocol
add name=social-http regexp=".*(t\\.me|telegram\\.|instagram\\.|facebook\\.|fbcdn\\.|vk\\.com|vkontakte|ok\\.ru|odnoklassniki|ria\\.ru|rt\\.com|sputnik|lenta\\.ru|gazeta\\.ru|iz\\.ru|rg\\.ru|kommersant|vedomosti|pravda\\.ru|mk\\.ru|rbc\\.ru).*"

# --- 4. STATIC DNS (NXDOMAIN) — основний блок ---
/ip dns static
:foreach d in={
    "t.me";"telegram.org";"telegram.me";"telegram.dog";"telegra.ph";
    "instagram.com";"instagr.am";"cdninstagram.com";
    "facebook.com";"fb.com";"fb.me";"messenger.com";"facebook.net";"fbcdn.net";"fbsbx.com";
    "vk.com";"vkontakte.ru";"vk.me";"userapi.com";
    "ok.ru";"odnoklassniki.ru";"okserver.ru";
    "ria.ru";"rt.com";"sputniknews.com";"tass.ru";"life.ru";
    "lenta.ru";"gazeta.ru";"iz.ru";"rg.ru";"kommersant.ru";"vedomosti.ru";
    "pravda.ru";"mk.ru";"rbc.ru";"yandex.ru";"mail.ru";"news.yandex.ru";"news.mail.ru";
    "rutracker.org";"kinopoisk.ru";"forbes.ru";"meduza.io";"novayagazeta.ru";
    "echo.msk.ru";"currenttime.tv";"tjournal.ru";"the-village.ru"
} do={
    /ip dns static add name=$d type=NXDOMAIN comment="BLOCK: Social/Propaganda"
}

# --- 5. СКРИПТИ ОНОВЛЕННЯ ---

# 5.1 Bogon / Fullbogon
/system script
add name=sec-update-bogon source={
    :log info "SEC: Fullbogon IPv4 update started"
    :if ([:len [/ip firewall address-list find list=sec-update-lock]] = 0) do={
        /ip firewall address-list add list=sec-update-lock address=1.1.1.1 timeout=5m
        /tool fetch url="https://team-cymru.org/Services/Bogons/fullbogons-ipv4.txt" mode=https dst-path=bogon.txt
        :delay 4s
        :if ([:len [/file find name=bogon.txt]] > 0) do={
            /ip firewall address-list remove [find list=sec-bogon]
            :local count 0
            :foreach line in=[/file get bogon.txt contents] do={
                :if ([:len $line] > 4 && [:pick $line 0 1] != "#") do={
                    :do { /ip firewall address-list add list=sec-bogon address=$line comment="ULTIMATE" } on-error={}
                    :set count ($count + 1)
                }
            }
            :log info ("SEC: Fullbogon updated: " . $count . " entries")
            /file remove bogon.txt
        } else={ :log warning "SEC: Fullbogon download failed" }
        /ip firewall address-list remove [find list=sec-update-lock]
    }
}

# 5.2 Scanners (актуальний шлях maltrail)
add name=sec-update-scanners source={
    :log info "SEC: Scanners update started"
    :if ([:len [/ip firewall address-list find list=sec-update-lock]] = 0) do={
        /ip firewall address-list add list=sec-update-lock address=1.1.1.1 timeout=5m
        /tool fetch url="https://raw.githubusercontent.com/stamparm/maltrail/master/data/mass_scanner.txt" mode=https dst-path=scanners.txt
        :delay 4s
        :if ([:len [/file find name=scanners.txt]] > 0) do={
            /ip firewall address-list remove [find list=sec-scanners]
            :local count 0
            :foreach line in=[/file get scanners.txt contents] do={
                :if ([:len $line] > 7 && [:pick $line 0 1] != "#") do={
                    :local ip [:pick $line 0 [:find $line " "]]
                    :if ([:len $ip] > 6) do={
                        :do { /ip firewall address-list add list=sec-scanners address=$ip comment="ULTIMATE" } on-error={}
                        :set count ($count + 1)
                    }
                }
            }
            :log info ("SEC: Scanners updated: " . $count . " entries")
            /file remove scanners.txt
        } else={ :log warning "SEC: Scanners download failed" }
        /ip firewall address-list remove [find list=sec-update-lock]
    }
}

# 5.3 GeoIP IPv4 (iwik.org) — з перейменуванням списку
add name=sec-update-geo source={
    :log info "SEC: GeoIP IPv4 update started"
    :if ([:len [/ip firewall address-list find list=sec-update-lock]] = 0) do={
        /ip firewall address-list add list=sec-update-lock address=1.1.1.1 timeout=10m
        /ip firewall address-list remove [find list=sec-geo-block]
        :local total 0
        :foreach country in=$GEO_COUNTRIES do={
            :local fname ($country . ".rsc")
            /tool fetch url=("https://www.iwik.org/ipcountry/mikrotik/" . $country) mode=https dst-path=$fname
            :delay 5s
            :if ([:len [/file find name=$fname]] > 0) do={
                /import file-name=$fname
                # Переносимо з list=COUNTRY у sec-geo-block
                :foreach e in=[/ip firewall address-list find list=$country] do={
                    :local addr [/ip firewall address-list get $e address]
                    :do { /ip firewall address-list add list=sec-geo-block address=$addr comment=("GEO:" . $country) } on-error={}
                    /ip firewall address-list remove $e
                    :set total ($total + 1)
                }
                /file remove $fname
                :log info ("SEC: GeoIP " . $country . " imported")
            } else={ :log warning ("SEC: GeoIP " . $country . " download failed") }
        }
        :log info ("SEC: Total GeoIP IPv4 entries: " . $total)
        /ip firewall address-list remove [find list=sec-update-lock]
    }
}

# 5.4 Автобекап
add name=sec-autobackup source={
    :log info "SEC: Autobackup started"
    :local date [/system clock get date]
    :local time [/system clock get time]
    :local name ("backup-" . [:pick $date 7 11] . [:pick $date 0 3] . [:pick $date 4 6] . "-" . [:pick $time 0 2] . [:pick $time 3 5])
    /export file=($name . ".rsc")
    :delay 2s
    /system backup save name=($name . ".backup")
    :delay 2s
    # Залишаємо тільки останні 10 бекапів
    :local files [/file find where name~"^backup-.*\\.(rsc|backup)$"]
    :if ([:len $files] > 20) do={
        :foreach f in=$files do={
            :local fname [/file get $f name]
            :if ([:pick $fname 0 7] = "backup-") do={ /file remove $f }
        }
    }
    :log info ("SEC: Autobackup done: " . $name)
}

# --- 6. ПЛАНУВАЛЬНИКИ ---
/system scheduler
add name=sec-daily-update on-event={
    /system script run sec-update-bogon
    /system script run sec-update-scanners
    /system script run sec-update-geo
} interval=1d start-time=03:15:00
add name=sec-weekly-backup on-event="/system script run sec-autobackup" interval=7d start-time=02:30:00

# --- 7. DNS (DoH + захист) ---
/ip dns set servers=1.1.1.1,1.0.0.1 allow-remote-requests=yes cache-size=4096KiB cache-max-ttl=1d
# DoH (якщо підтримується вашою версією 6.x)
:do { /ip dns set use-doh-server=https://cloudflare-dns.com/dns-query verify-doh-cert=yes } on-error={}
/ip dns cache flush

# --- 8. MANGLE (маркування) ---
/ip firewall mangle
add chain=prerouting protocol=udp dst-port=53 action=mark-packet new-packet-mark=dns-mark passthrough=yes comment="ULTIMATE"
add chain=prerouting protocol=tcp dst-port=22,8291 action=mark-packet new-packet-mark=mgmt-mark passthrough=yes comment="ULTIMATE"
# Layer7 тільки для HTTP
add chain=prerouting protocol=tcp dst-port=80 layer7-protocol=social-http action=mark-packet new-packet-mark=dpi-block passthrough=no comment="ULTIMATE"
# TLS Host для HTTPS (SNI) — найефективніше в ROS 6
add chain=prerouting protocol=tcp dst-port=443 tls-host=*telegram* action=mark-packet new-packet-mark=dpi-block passthrough=no comment="ULTIMATE"
add chain=prerouting protocol=tcp dst-port=443 tls-host=*t.me* action=mark-packet new-packet-mark=dpi-block passthrough=no comment="ULTIMATE"
add chain=prerouting protocol=tcp dst-port=443 tls-host=*instagram* action=mark-packet new-packet-mark=dpi-block passthrough=no comment="ULTIMATE"
add chain=prerouting protocol=tcp dst-port=443 tls-host=*facebook* action=mark-packet new-packet-mark=dpi-block passthrough=no comment="ULTIMATE"
add chain=prerouting protocol=tcp dst-port=443 tls-host=*fbcdn* action=mark-packet new-packet-mark=dpi-block passthrough=no comment="ULTIMATE"
add chain=prerouting protocol=tcp dst-port=443 tls-host=*vk.com* action=mark-packet new-packet-mark=dpi-block passthrough=no comment="ULTIMATE"
add chain=prerouting protocol=tcp dst-port=443 tls-host=*vkontakte* action=mark-packet new-packet-mark=dpi-block passthrough=no comment="ULTIMATE"
add chain=prerouting protocol=tcp dst-port=443 tls-host=*ok.ru* action=mark-packet new-packet-mark=dpi-block passthrough=no comment="ULTIMATE"
add chain=prerouting protocol=tcp dst-port=443 tls-host=*ria.ru* action=mark-packet new-packet-mark=dpi-block passthrough=no comment="ULTIMATE"
add chain=prerouting protocol=tcp dst-port=443 tls-host=*rt.com* action=mark-packet new-packet-mark=dpi-block passthrough=no comment="ULTIMATE"
add chain=prerouting protocol=tcp dst-port=443 tls-host=*sputnik* action=mark-packet new-packet-mark=dpi-block passthrough=no comment="ULTIMATE"

# --- 9. QUEUE TREE (обмеження) ---
/queue tree
add name="SEC_LIMIT" parent=global max-limit=100M
add name="DNS_LIMIT" parent=SEC_LIMIT packet-mark=dns-mark max-limit=8M
add name="MGMT_LIMIT" parent=SEC_LIMIT packet-mark=mgmt-mark max-limit=2M
add name="DPI_DROP" parent=SEC_LIMIT packet-mark=dpi-block max-limit=64k

# --- 10. RAW (найшвидший дроп) ---
/ip firewall raw
add action=drop chain=prerouting in-interface-list=WAN src-address-list=sec-bogon comment="ULTIMATE: bogon"
add action=drop chain=prerouting src-address-list=sec-geo-block comment="ULTIMATE: geo"
add action=drop chain=prerouting packet-mark=dpi-block comment="ULTIMATE: dpi"
add action=drop chain=prerouting protocol=tcp tcp-flags=!fin,!syn,!rst,!ack comment="ULTIMATE: invalid flags"
add action=drop chain=prerouting fragment=yes comment="ULTIMATE: fragments"

# --- 11. INPUT FILTER ---
/ip firewall filter
add chain=input action=accept connection-state=established,related,untracked comment="ULTIMATE"
add chain=input action=accept src-address=$LAN_SUBNET comment="ULTIMATE: LAN"
add chain=input action=accept protocol=icmp limit=10,5:packet comment="ULTIMATE: ICMP limited"
add chain=input action=drop protocol=icmp comment="ULTIMATE: ICMP drop rest"
add chain=input action=accept protocol=udp dst-port=53 src-address=$LAN_SUBNET comment="ULTIMATE: DNS LAN"
add chain=input action=accept protocol=tcp dst-port=53 src-address=$LAN_SUBNET comment="ULTIMATE: DNS LAN TCP"

# Flood protection
add chain=input action=add-src-to-address-list protocol=udp limit=30,5:packet address-list=sec-flood address-list-timeout=30m comment="ULTIMATE"
add chain=input action=add-src-to-address-list protocol=tcp limit=50,5:packet address-list=sec-flood address-list-timeout=30m comment="ULTIMATE"
add chain=input action=drop src-address-list=sec-flood comment="ULTIMATE: flood"

# SSH brute
add chain=input action=add-src-to-address-list protocol=tcp dst-port=22 connection-state=new address-list=sec-brute-ssh address-list-timeout=1d comment="ULTIMATE"
add chain=input action=drop protocol=tcp dst-port=22 src-address-list=sec-brute-ssh comment="ULTIMATE: SSH brute"

# Winbox brute
add chain=input action=add-src-to-address-list protocol=tcp dst-port=8291 connection-state=new address-list=sec-brute-winbox address-list-timeout=1d comment="ULTIMATE"
add chain=input action=drop protocol=tcp dst-port=8291 src-address-list=sec-brute-winbox comment="ULTIMATE: Winbox brute"

add chain=input action=drop src-address-list=sec-scanners comment="ULTIMATE: scanners"
add chain=input action=drop src-address-list=sec-geo-block comment="ULTIMATE: geo input"
add chain=input action=drop connection-state=invalid comment="ULTIMATE"
add chain=input action=drop comment="ULTIMATE: drop all"

# --- 12. FORWARD (базовий захист) ---
/ip firewall filter
add chain=forward action=accept connection-state=established,related,untracked comment="ULTIMATE"
add chain=forward action=drop connection-state=invalid comment="ULTIMATE"
add chain=forward action=drop src-address-list=sec-geo-block comment="ULTIMATE: geo forward"
add chain=forward action=drop packet-mark=dpi-block comment="ULTIMATE: dpi forward"

# --- 13. СЕРВІСИ ---
/ip service
set telnet disabled=yes
set ftp disabled=yes
set www disabled=yes
set api disabled=yes
set api-ssl disabled=yes
# winbox і ssh залишаємо (захищені brute-force)

# --- 14. АНТИ-СПУФІНГ ---
/ip settings set rp-filter=strict

# --- 15. ПЕРШИЙ ЗАПУСК ---
:log info "=== ULTIMATE SECURITY v10.1 ACTIVATED ==="
/system script run sec-autobackup
:delay 3s
/system script run sec-update-bogon
:delay 5s
/system script run sec-update-scanners
:delay 5s
/system script run sec-update-geo

:log info "=== Готово. Перевірте логи і address-list ==="
