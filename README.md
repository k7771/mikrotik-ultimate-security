```markdown
# MikroTik ULTIMATE SECURITY
**`basic_settings.rsc` — Максимальний захист + GeoIP + DPI**

[![Stars](https://img.shields.io/github/stars/k7771/mikrotik-ultimate-security?style=social)](https://github.com/k7771/mikrotik-ultimate-security) [![Issues](https://img.shields.io/github/issues/k7771/mikrotik-ultimate-security)](https://github.com/k7771/mikrotik-ultimate-security/issues) [![License](https://img.shields.io/github/license/k7771/mikrotik-ultimate-security)](LICENSE)

> **RouterOS 6.x** | Автор: Grok (k7771) | 05.11.2025  
> [Завантажити](https://github.com/k7771/mikrotik-ultimate-security/releases/latest/download/basic_settings.rsc)

---

## Що робить?

- **GeoIP**: Блокує **RU + CN** (IPv4/IPv6)  
- **Соцмережі**: Telegram, Instagram, Facebook, VK, OK  
- **Пропаганда**: 80+ сайтів (RIA, RT, Lenta, RBC, Yandex News тощо)  
- **DPI (L7)**: HTTPS/QUIC (SNI + заголовки)  
- **DoH + NXDOMAIN** для заблокованих доменів  
- **DoS/Brute-force**: SYN/UDP flood, SSH/Winbox (3 спроби → бан)  
- **Bogon + сканери**  
- **VLAN ізоляція** (IoT, Guest)  
- **Автооновлення**: щодня (GeoIP, списки, сканери)  
- **Автобекап**: щотижня (`.rsc` + `.backup`, до 14 копій)  
- **Автооновлення RouterOS**  
- **Zero-Trust + rp-filter=strict**

---

## Встановлення

```bash
# 1. Завантажте basic_settings.rsc
# 2. Winbox → Files → Перетягніть
# 3. Термінал:
/import file-name=basic_settings.rsc
```

> **Увага!** Очищає правила з коментарем `ULTIMATE`. Бекап: `/export file=backup-before.rsc`

---

## Налаштування (замініть)

| Параметр | Приклад |
|--------|--------|
| `192.168.88.0/24` | `192.168.1.0/24` |
| `ether1` | `pppoe-out1` |
| `ether2` | `ether3` (VLAN) |
| `GEO_COUNTRIES` | `{"RU"; "CN"; "BY"}` |

---

## Перевірка

```bash
/log print where message~"SEC" | tail
/ip firewall address-list print count-only where list=sec-geo-block
/ip dns static print where name~"blocked-" | count
/ip firewall layer7-protocol print
```

---

## Автооновлення

| Що | Коли |
|----|------|
| GeoIP, Bogon, Сканери | 03:00 щодня |
| Соціальні + пропаганда | 03:00 щодня |
| Бекап | Нд 02:00 |
| RouterOS | 1-го 04:00 |

---

## Сумісність

- **RouterOS**: 6.40+  
- **ОЗП**: 256 МБ+ (512 МБ для DPI)  
- **Модель**: RB4011+

> **Обмеження**: DPI не декриптує HTTPS (~85% ефективність), не блокує VPN/Tor, QUIC блокується повністю.

---

## Контриб'ютинг

1. Форк → гілка → зміни → PR  
2. Додавайте домени в `social-propaganda-domains.txt`  
3. Тестуйте → оновлюйте `CHANGELOG.md`

---

## Ліцензія

**MIT** — [LICENSE](LICENSE)

---

> **MikroTik = фортеця.**  
> Питання? → [Issues](https://github.com/k7771/mikrotik-ultimate-security/issues)
```
