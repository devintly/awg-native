**🇺🇸 [English version](./README.md)**

Скрипт ставит клиент **AmneziaWG 3.1** так же, как нативный интерфейс WireGuard: `awg-quick` поднимает интерфейс `awg`, `Table = off` не трогает маршрут по умолчанию сервера, и трафик попадает в туннель только когда программа сама выбрала этот интерфейс.

⚠️ Только **Debian/Ubuntu** и ядро **6.7 или новее** (Ubuntu 24.04, Ubuntu 26.04, Debian 13). Профиль 3.1 требует `HeaderProtectionKey` и `S1`–`S4` не меньше 12.

Нужен готовый клиентский `.conf` с сервера или из приложения AmneziaWG. Скрипт не ставит сервер и не принимает ссылку `vpn://`.

Он делает следующее:

- Ставит `amneziawg` (модуль ядра и `awg` / `awg-quick`) из PPA Amnezia и проверяет, что модуль принимает профиль 3.1
- Приводит клиентский профиль к схеме привязки интерфейса и сохраняет его в `/etc/amnezia/amneziawg/awg.conf`
- Оставляет как есть `Jc`, `Jmin`, `Jmax`, `S1`–`S4`, `H1`–`H4`, `I1`–`I5`, `HeaderProtectionKey` и `ContentPaddingAddition`
- Убирает DNS и `PreUp`/`PostUp`/`PreDown`/`PostDown`, ставит `Table = off` и `AllowedIPs = 0.0.0.0/0`, добавляет `PersistentKeepalive = 25`, если у пира его не было, и убирает IPv6 из `Address`
- Включает автозапуск, watchdog и fail-closed kill-switch для метки `51888`

`Table = off` оставляет SSH на обычном маршруте сервера. `AllowedIPs = 0.0.0.0/0` при этом позволяет интерфейсу шифровать IPv4, который отправили именно через `awg`.

---

## Установка

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/devintly/awg-native/main/install.sh)
```

Установщик спрашивает путь к клиентскому `.conf` либо принимает вставку. Вставка заканчивается строкой, в которой только `END`.

Без вопросов:

```bash
sudo AWG_LANG=ru AWG_CONF_FILE=/root/client.conf AWG_WATCHDOG_MINUTES=5 bash install.sh
```

`AWG_WATCHDOG_MINUTES` — `5`, `10`, `15` или `30`.

## Xray

<details>
  <summary>Outbound</summary>

```json
{
  "tag": "awg-out",
  "protocol": "freedom",
  "settings": {
    "domainStrategy": "ForceIPv4"
  },
  "streamSettings": {
    "sockopt": {
      "interface": "awg",
      "mark": 51888,
      "tcpFastOpen": true
    }
  }
}
```
</details>

<details>
  <summary>Правило маршрутизации</summary>

```json
{
  "type": "field",
  "domain": [
    "netflix.com",
    "youtube.com",
    "twitter.com"
  ],
  "inboundTag": [
    "Node-1",
    "Node-2"
  ],
  "outboundTag": "awg-out"
}
```
</details>

## Kill-switch

`awg-native-killswitch.service` отбрасывает локально созданные пакеты с меткой `51888`, если выбранный для них выходной интерфейс — не `awg`. Пока `awg` лежит, помеченный трафик не уходит в обычное подключение сервера.

Метка та же, что в outbound Xray:

```json
"sockopt": {
  "interface": "awg",
  "mark": 51888
}
```

Без `mark` kill-switch для этого outbound не действует. Служба ведёт только свою цепочку nftables и восстанавливает её после штатного reload nftables. После ручного `nft flush ruleset` верните правило так:

```bash
systemctl reload nftables
```

```bash
systemctl status awg-native-killswitch.service
nft list chain inet awg_native awg_native_killswitch
```

## Интерфейс

| Действие | Команда |
|---|---|
| Статус и проверка выхода | `awg-native` |
| Статус службы | `systemctl status awg-quick@awg` |
| Состояние туннеля | `awg show awg` |
| Остановить | `systemctl stop awg-quick@awg` |
| Запустить | `systemctl start awg-quick@awg` |
| Перезапустить | `systemctl restart awg-quick@awg` |
| Выключить автозапуск | `systemctl disable awg-quick@awg` |
| Включить автозапуск | `systemctl enable awg-quick@awg` |

У `awg-native` также есть `start`, `stop`, `restart`, `check` и `log`.

## Удаление

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/devintly/awg-native/main/uninstall.sh)
```

Другие файлы в `/etc/amnezia/amneziawg/` не удаляются. Если они есть, пакеты Amnezia остаются. Убираются только `awg.conf` и юниты этого установщика.

## Лицензия

MIT. См. [LICENSE](LICENSE).

Схема привязки интерфейса (без маршрута по умолчанию, метка, fail-closed kill-switch) взята из [warp-native](https://github.com/distillium/warp-native) автора [distillium](https://github.com/distillium).
