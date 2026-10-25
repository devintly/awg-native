#!/bin/bash

set -e

SCRIPT_LANG=""
IFACE="awg"
CONF_DIR="/etc/amnezia/amneziawg"
CONF_FILE="${CONF_DIR}/${IFACE}.conf"
UNIT="awg-quick@${IFACE}"

function select_language {
    echo -e "\n\e[1;35m╭─────────────────────────────────────╮"
    echo -e "│      \e[1;36m   A W G - N A T I V E         \e[1;35m│"
    echo -e "│      \e[1;31mUNINSTALLER\e[2;37m  AmneziaWG 3.1  \e[1;35m│"
    echo -e "\e[1;35m╰─────────────────────────────────────╯\e[0m"
    echo ""
    echo -e "\e[1;34mSelect language / Выберите язык:\e[0m"
    echo -e "\e[1;32m1)\e[0m English"
    echo -e "\e[1;32m2)\e[0m Русский"
    echo ""

    while true; do
        read -r -p "Choice / Выбор [1-2]: " choice
        case $choice in
            1) SCRIPT_LANG="en"; break ;;
            2) SCRIPT_LANG="ru"; break ;;
            *) echo -e "\e[1;31mInvalid choice / Неверный выбор\e[0m" ;;
        esac
    done

    clear
    echo -e "\n\e[1;35m╭─────────────────────────────────────╮"
    echo -e "│      \e[1;36m   A W G - N A T I V E         \e[1;35m│"
    echo -e "│      \e[1;31mUNINSTALLER\e[2;37m  AmneziaWG 3.1  \e[1;35m│"
    echo -e "\e[1;35m╰─────────────────────────────────────╯\e[0m"
    sleep 1
}

function msg {
    local key="$1"
    case "$SCRIPT_LANG" in
        "ru")
            case "$key" in
                "root_required") echo "Скрипт должен быть запущен от root." ;;
                "stopping") echo "Отключаем интерфейс awg..." ;;
                "removing_watchdog") echo "Удаляем watchdog, kill-switch и cron..." ;;
                "removing_packages") echo "Удаляем пакеты AmneziaWG..." ;;
                "awg_kept") echo "Найдены другие конфигурации AmneziaWG — пакеты и репозиторий не удаляются." ;;
                "uninstall_complete") echo "Удаление завершено." ;;
                *) echo "$key" ;;
            esac
            ;;
        *)
            case "$key" in
                "root_required") echo "Script must be run as root." ;;
                "stopping") echo "Stopping the awg interface..." ;;
                "removing_watchdog") echo "Removing watchdog, kill-switch and cron..." ;;
                "removing_packages") echo "Removing AmneziaWG packages..." ;;
                "awg_kept") echo "Other AmneziaWG configurations found — packages and the repository are kept." ;;
                "uninstall_complete") echo "Uninstallation completed." ;;
                *) echo "$key" ;;
            esac
            ;;
    esac
}

function info {
    echo -e "\e[1;33m[INFO]\e[0m $1"
}

function warn {
    echo -e "\e[1;31m[WARN]\e[0m $1"
}

function completed {
    echo -e "\e[1;32m[COMPLETED]\e[0m $1"
}

if [[ $EUID -ne 0 ]]; then
    warn "This script must be run as root / Скрипт должен быть запущен от root."
    exit 1
fi

if [[ -n "${AWG_LANG:-}" ]]; then
    case "$AWG_LANG" in
        ru|RU|ru_RU) SCRIPT_LANG="ru" ;;
        *) SCRIPT_LANG="en" ;;
    esac
elif [[ -t 0 ]]; then
    select_language
else
    SCRIPT_LANG="en"
fi

info "$(msg "stopping")"
systemctl disable --now "$UNIT" &>/dev/null || true
if ip link show "$IFACE" &>/dev/null; then
    awg-quick down "$IFACE" &>/dev/null || ip link delete "$IFACE" &>/dev/null || true
fi

### ExecStop службы вызывает скрипт из /opt/awg-native, поэтому останавливаем её до удаления каталога.
info "$(msg "removing_watchdog")"
rm -f /etc/cron.d/awg-native
systemctl disable --now awg-native-killswitch.service &>/dev/null || true
nft delete table inet awg_native &>/dev/null || true

rm -f /etc/systemd/system/awg-native-killswitch.service
rm -f /etc/systemd/system/awg-quick@awg.service.d/awg-native-killswitch.conf
rm -f /etc/systemd/system/nftables.service.d/awg-native-killswitch.conf
rmdir /etc/systemd/system/awg-quick@awg.service.d /etc/systemd/system/nftables.service.d &>/dev/null || true

systemctl daemon-reload &>/dev/null || true
systemctl reset-failed "$UNIT" awg-native-killswitch.service &>/dev/null || true

rm -rf /opt/awg-native
rm -f /usr/local/bin/awg-native
rm -f "$CONF_FILE"
rmdir "$CONF_DIR" /etc/amnezia &>/dev/null || true

info "$(msg "removing_packages")"
other_conf=false
if [[ -d "$CONF_DIR" ]]; then
    shopt -s nullglob
    leftover=("$CONF_DIR"/*.conf)
    shopt -u nullglob
    if (( ${#leftover[@]} > 0 )); then
        other_conf=true
    fi
fi

if [[ "$other_conf" == true ]]; then
    info "$(msg "awg_kept")"
else
    DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y \
        amneziawg amneziawg-dkms amneziawg-tools amneziawg-linux-kmod &>/dev/null || true
    rm -f /etc/apt/sources.list.d/amnezia-ppa.list
    rm -f /etc/apt/keyrings/amnezia-ppa.gpg
fi

completed "$(msg "uninstall_complete")"
