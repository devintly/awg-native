**🇷🇺 [Русская версия](./README_ru.md)**

This script installs an **AmneziaWG 3.1** client the same way a native WireGuard interface is attached: `awg-quick` brings up interface `awg`, `Table = off` leaves the server default route alone, and traffic enters the tunnel only when a program binds to that interface.

⚠️ **Debian/Ubuntu** only, kernel **6.7 or newer** (Ubuntu 24.04, Ubuntu 26.04, Debian 13). The AmneziaWG 3.1 profile needs `HeaderProtectionKey` and `S1`–`S4` of at least 12.

You bring a client `.conf` exported from the AmneziaWG server or app. The script does not create a server and does not accept a `vpn://` link.

It does the following:

- Installs `amneziawg` (kernel module and `awg` / `awg-quick`) from the Amnezia PPA and checks that the module accepts a 3.1 profile
- Rewrites the client profile for interface binding and saves it to `/etc/amnezia/amneziawg/awg.conf`
- Keeps `Jc`, `Jmin`, `Jmax`, `S1`–`S4`, `H1`–`H4`, `I1`–`I5`, `HeaderProtectionKey` and `ContentPaddingAddition` as they are
- Removes DNS and `PreUp`/`PostUp`/`PreDown`/`PostDown`, sets `Table = off` and `AllowedIPs = 0.0.0.0/0`, adds `PersistentKeepalive = 25` when the peer has none, and drops IPv6 from `Address`
- Enables autostart, a watchdog, and a fail-closed kill-switch for mark `51888`

`Table = off` is what keeps SSH on the server's normal route. `AllowedIPs = 0.0.0.0/0` still lets the interface encrypt IPv4 that was sent out through `awg`.

---

## Install

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/devintly/awg-native/main/install.sh)
```

The installer asks for a path to the client `.conf`, or lets you paste it and finish with a line that contains only `END`.

Non-interactive:

```bash
sudo AWG_LANG=ru AWG_CONF_FILE=/root/client.conf AWG_WATCHDOG_MINUTES=5 bash install.sh
```

`AWG_WATCHDOG_MINUTES` is `5`, `10`, `15` or `30`.

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
  <summary>Routing rule</summary>

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

`awg-native-killswitch.service` drops locally generated packets marked `51888` when their selected output interface is not `awg`. Marked traffic cannot fall back to the server's ordinary connection while `awg` is down.

The mark is the one in the Xray outbound:

```json
"sockopt": {
  "interface": "awg",
  "mark": 51888
}
```

Removing `mark` turns the kill-switch off for that outbound. The service owns only its own nftables chain and restores it after a normal nftables reload. After a manual `nft flush ruleset`, restore it with:

```bash
systemctl reload nftables
```

```bash
systemctl status awg-native-killswitch.service
nft list chain inet awg_native awg_native_killswitch
```

## Interface

| Action | Command |
|---|---|
| Status and exit check | `awg-native` |
| Service status | `systemctl status awg-quick@awg` |
| Tunnel details | `awg show awg` |
| Stop | `systemctl stop awg-quick@awg` |
| Start | `systemctl start awg-quick@awg` |
| Restart | `systemctl restart awg-quick@awg` |
| Disable autostart | `systemctl disable awg-quick@awg` |
| Enable autostart | `systemctl enable awg-quick@awg` |

`awg-native` also accepts `start`, `stop`, `restart`, `check` and `log`.

## Remove

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/devintly/awg-native/main/uninstall.sh)
```

Other files in `/etc/amnezia/amneziawg/` are left in place, and in that case the Amnezia packages stay installed. Only `awg.conf` and the units created by this installer are removed.

## License

MIT. See [LICENSE](LICENSE).

The interface-binding scheme (no default route, fwmark, fail-closed kill-switch) comes from [warp-native](https://github.com/distillium/warp-native) by [distillium](https://github.com/distillium).
