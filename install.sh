#!/bin/bash

### Клиент AmneziaWG 3.1 в том же виде, что warp-native поднимал WireGuard:
### интерфейс без маршрута по умолчанию (Table = off), трафик только если
### приложение само выбрало интерфейс, fail-closed kill-switch по метке.

IFACE="awg"
CONF_DIR="/etc/amnezia/amneziawg"
CONF_FILE="${CONF_DIR}/${IFACE}.conf"
STATE_DIR="/opt/awg-native"
UNIT="awg-quick@${IFACE}"
MARK="51888"
PPA_LIST="/etc/apt/sources.list.d/amnezia-ppa.list"
PPA_KEYRING="/etc/apt/keyrings/amnezia-ppa.gpg"
PPA_KEY_ID="75C9DD72C799870E310542E24166F2C257290828"

SCRIPT_LANG=""
CONF_ARG=""
PREPARE_ERROR=""
PREPARE_DETAIL=""
PREPARE_STRIPPED_HOOKS=0

function select_language {
    echo -e "\n\e[1;35m╭─────────────────────────────────────╮"
    echo -e "│      \e[1;36m   A W G - N A T I V E         \e[1;35m│"
    echo -e "│     \e[2;37m      AmneziaWG 3.1            \e[1;35m│"
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
    echo -e "│     \e[2;37m      AmneziaWG 3.1            \e[1;35m│"
    echo -e "\e[1;35m╰─────────────────────────────────────╯\e[0m"
    sleep 1
}

function msg {
    local key="$1"
    case "$SCRIPT_LANG" in
        "ru")
            case "$key" in
                "root_required") echo "Этот скрипт должен быть запущен от имени root" ;;
                "unsupported_os") echo "Поддерживаются только Debian и Ubuntu." ;;
                "kernel_too_old") echo "Для AmneziaWG 3.1 нужно ядро 6.7 или новее. Сейчас" ;;
                "start_install") echo "Установка клиента AmneziaWG 3.1: интерфейс без перехвата маршрута по умолчанию" ;;
                "install_packages") echo "1. Репозиторий Amnezia, модуль ядра и awg-quick..." ;;
                "update_failed") echo "Не удалось обновить список пакетов." ;;
                "base_packages_failed") echo "Не удалось установить базовые пакеты (curl, gnupg, nftables)." ;;
                "repo_failed") echo "Не удалось подключить PPA Amnezia." ;;
                "awg_install_failed") echo "Не удалось установить amneziawg." ;;
                "tools_missing") echo "Пакет поставлен, но команд awg и awg-quick нет." ;;
                "awg_ok") echo "AmneziaWG установлен, модуль понимает профиль 3.1." ;;
                "module_failed") echo "Модуль ядра amneziawg не загрузился. Нужны заголовки текущего ядра и успешная сборка DKMS." ;;
                "probe_failed") echo "Установленные awg и модуль не принимают HeaderProtectionKey. Это не линия AmneziaWG 3.1." ;;
                "headers_missing") echo "Точные заголовки ядра не установились. Пробуем собрать модуль тем, что есть." ;;
                "ppa_fallback") echo "В PPA нет сьюта этого выпуска, используется noble." ;;
                "read_config") echo "2. Клиентский конфиг AmneziaWG 3.1..." ;;
                "conf_path_prompt") echo "Путь к .conf (Enter — вставить текст, последняя строка END): " ;;
                "conf_paste_prompt") echo "Вставьте конфиг. Строка из одного слова END завершает ввод." ;;
                "conf_not_found") echo "Файл конфигурации не найден." ;;
                "conf_empty") echo "Конфиг пустой." ;;
                "conf_required") echo "В неинтерактивном режиме передайте файл: AWG_CONF_FILE=/path/client.conf или первым аргументом." ;;
                "not_a_config") echo "Это не конфиг AmneziaWG: нужны секции [Interface] и [Peer]." ;;
                "vpn_uri") echo "Ссылка vpn:// не подходит. Экспортируйте клиентский профиль как файл .conf." ;;
                "server_config") echo "В [Interface] есть ListenPort — это серверный конфиг. Нужен клиентский профиль." ;;
                "missing_hpk") echo "Нет HeaderProtectionKey. Для AmneziaWG 3.1 этот ключ обязателен и должен совпадать с сервером." ;;
                "s_too_small") echo "S1–S4 должны быть не меньше 12: из них берётся nonce защиты заголовка." ;;
                "missing_address") echo "В Address не осталось IPv4. Скрипт поднимает туннель только по IPv4." ;;
                "missing_peer") echo "В конфиге нет секции [Peer]." ;;
                "missing_keys") echo "У пира должны быть PublicKey и Endpoint." ;;
                "config_ready") echo "Конфиг приведён к схеме интерфейса: Table = off, AllowedIPs = 0.0.0.0/0, без DNS." ;;
                "hooks_removed") echo "Строки PreUp/PostUp/PreDown/PostDown убраны: правила интерфейса задаёт этот установщик." ;;
                "saved_config") echo "Конфигурация сохранена в /etc/amnezia/amneziawg/awg.conf." ;;
                "connect") echo "3. Подключение интерфейса awg..." ;;
                "connect_failed") echo "Не удалось поднять интерфейс." ;;
                "connected") echo "Интерфейс awg поднят." ;;
                "check_status") echo "4. Проверка рукопожатия..." ;;
                "iface_missing") echo "Интерфейс awg не найден — туннель не работает." ;;
                "handshake_received") echo "Получен handshake →" ;;
                "tunnel_active") echo "Туннель поднят и обменивается пакетами." ;;
                "waiting_handshake") echo "Ожидание рукопожатия" ;;
                "handshake_pending") echo "Рукопожатия ещё нет — связь проверяется ниже." ;;
                "enable_autostart") echo "5. Автозапуск awg..." ;;
                "autostart_failed") echo "Не удалось включить автозапуск." ;;
                "autostart_enabled") echo "Автозапуск включён." ;;
                "setup_watchdog") echo "6. Watchdog и kill-switch..." ;;
                "watchdog_interval_prompt") echo "Интервал проверки watchdog:" ;;
                "watchdog_opt_5") echo "1) Каждые 5 минут (по умолчанию)" ;;
                "watchdog_opt_10") echo "2) Каждые 10 минут" ;;
                "watchdog_opt_15") echo "3) Каждые 15 минут" ;;
                "watchdog_opt_30") echo "4) Каждые 30 минут" ;;
                "watchdog_interval_set") echo "Интервал watchdog:" ;;
                "watchdog_created") echo "Watchdog: /opt/awg-native/awg-watchdog.sh" ;;
                "watchdog_cron_set") echo "Cron: /etc/cron.d/awg-native" ;;
                "watchdog_dir_failed") echo "Не удалось создать /opt/awg-native." ;;
                "killswitch_failed") echo "Не удалось включить kill-switch (проверьте nftables)." ;;
                "killswitch_enabled") echo "Fail-closed kill-switch включён (метка 51888 → только через awg)." ;;
                "setup_command") echo "7. Команда awg-native..." ;;
                "command_created") echo "Команда \e[1;32mawg-native\e[0m создана." ;;
                "installation_complete") echo "Клиент AmneziaWG 3.1 установлен." ;;
                "summary_header") echo "═══════════════ ИТОГ ═══════════════" ;;
                "summary_proto") echo "Профиль     :" ;;
                "summary_endpoint") echo "Endpoint    :" ;;
                "summary_tunnel_ip") echo "IP туннеля  :" ;;
                "summary_handshake") echo "Handshake   :" ;;
                "summary_seconds_ago") echo "сек. назад" ;;
                "summary_footer") echo "════════════════════════════════════" ;;
                "exit_header") echo "══════════ ВЫХОД ЧЕРЕЗ AWG ══════════" ;;
                "exit_avail") echo "доступен" ;;
                "exit_unavail") echo "недоступен" ;;
                "exit_unreachable") echo "Через туннель нет связи. Установка завершена — watchdog будет поднимать интерфейс. Проверка: awg-native check" ;;
                "disable_autostart") echo "Отключить автозапуск" ;;
                "enable_autostart_cmd") echo "Включить автозапуск" ;;
                "watchdog_config") echo "Настройки watchdog" ;;
                "rollback_start") echo "Установка не завершена — откатываем изменения..." ;;
                "rollback_done") echo "Изменения откачены." ;;
                "rollback_skipped") echo "Обнаружена предыдущая установка — автоматический откат не выполняется. Для удаления запустите uninstall.sh." ;;
                *) echo "$key" ;;
            esac
            ;;
        *)
            case "$key" in
                "root_required") echo "This script must be run as root" ;;
                "unsupported_os") echo "Only Debian and Ubuntu are supported." ;;
                "kernel_too_old") echo "AmneziaWG 3.1 needs kernel 6.7 or newer. Running" ;;
                "start_install") echo "Installing an AmneziaWG 3.1 client that does not take over the default route" ;;
                "install_packages") echo "1. Amnezia repository, kernel module and awg-quick..." ;;
                "update_failed") echo "Failed to update the package list." ;;
                "base_packages_failed") echo "Failed to install base packages (curl, gnupg, nftables)." ;;
                "repo_failed") echo "Failed to add the Amnezia PPA." ;;
                "awg_install_failed") echo "Failed to install amneziawg." ;;
                "tools_missing") echo "The package was installed, but awg and awg-quick are missing." ;;
                "awg_ok") echo "AmneziaWG is installed and the module accepts a 3.1 profile." ;;
                "module_failed") echo "The amneziawg kernel module did not load. The running kernel headers and a successful DKMS build are required." ;;
                "probe_failed") echo "The installed awg tools and module rejected HeaderProtectionKey. This is not the AmneziaWG 3.1 line." ;;
                "headers_missing") echo "Exact kernel headers were not installed. Continuing with whatever headers are already present." ;;
                "ppa_fallback") echo "The PPA has no suite for this release; using noble." ;;
                "read_config") echo "2. AmneziaWG 3.1 client configuration..." ;;
                "conf_path_prompt") echo "Path to the .conf (Enter to paste it; finish with a line that says END): " ;;
                "conf_paste_prompt") echo "Paste the configuration. A line containing only END ends the input." ;;
                "conf_not_found") echo "Configuration file not found." ;;
                "conf_empty") echo "The configuration is empty." ;;
                "conf_required") echo "Non-interactive mode needs a file: AWG_CONF_FILE=/path/client.conf or pass the path as the first argument." ;;
                "not_a_config") echo "This is not an AmneziaWG config: [Interface] and [Peer] are required." ;;
                "vpn_uri") echo "A vpn:// link cannot be used. Export the client profile as a .conf file." ;;
                "server_config") echo "[Interface] contains ListenPort, so this is a server config. A client profile is required." ;;
                "missing_hpk") echo "HeaderProtectionKey is missing. AmneziaWG 3.1 requires it, and it must match the server." ;;
                "s_too_small") echo "S1–S4 must be at least 12: those bytes are the header-protection nonce." ;;
                "missing_address") echo "No IPv4 address left in Address. This installer brings the tunnel up for IPv4 only." ;;
                "missing_peer") echo "The configuration has no [Peer] section." ;;
                "missing_keys") echo "Each peer needs a PublicKey and an Endpoint." ;;
                "config_ready") echo "Configuration adjusted for interface binding: Table = off, AllowedIPs = 0.0.0.0/0, DNS removed." ;;
                "hooks_removed") echo "PreUp/PostUp/PreDown/PostDown lines were removed; this installer owns the interface rules." ;;
                "saved_config") echo "Configuration saved to /etc/amnezia/amneziawg/awg.conf." ;;
                "connect") echo "3. Bringing up the awg interface..." ;;
                "connect_failed") echo "Failed to bring the interface up." ;;
                "connected") echo "Interface awg is up." ;;
                "check_status") echo "4. Checking the handshake..." ;;
                "iface_missing") echo "Interface awg was not found — the tunnel is not working." ;;
                "handshake_received") echo "Handshake received →" ;;
                "tunnel_active") echo "The tunnel is up and exchanging packets." ;;
                "waiting_handshake") echo "Waiting for a handshake" ;;
                "handshake_pending") echo "No handshake yet — connectivity is checked below." ;;
                "enable_autostart") echo "5. Enabling awg autostart..." ;;
                "autostart_failed") echo "Failed to enable autostart." ;;
                "autostart_enabled") echo "Autostart enabled." ;;
                "setup_watchdog") echo "6. Watchdog and kill-switch..." ;;
                "watchdog_interval_prompt") echo "Watchdog check interval:" ;;
                "watchdog_opt_5") echo "1) Every 5 minutes (default)" ;;
                "watchdog_opt_10") echo "2) Every 10 minutes" ;;
                "watchdog_opt_15") echo "3) Every 15 minutes" ;;
                "watchdog_opt_30") echo "4) Every 30 minutes" ;;
                "watchdog_interval_set") echo "Watchdog interval:" ;;
                "watchdog_created") echo "Watchdog: /opt/awg-native/awg-watchdog.sh" ;;
                "watchdog_cron_set") echo "Cron: /etc/cron.d/awg-native" ;;
                "watchdog_dir_failed") echo "Failed to create /opt/awg-native." ;;
                "killswitch_failed") echo "Failed to enable the kill-switch (check nftables)." ;;
                "killswitch_enabled") echo "Fail-closed kill-switch enabled (mark 51888 → awg only)." ;;
                "setup_command") echo "7. Creating the awg-native command..." ;;
                "command_created") echo "\e[1;32mawg-native\e[0m command created." ;;
                "installation_complete") echo "AmneziaWG 3.1 client installed." ;;
                "summary_header") echo "════════════════ SUMMARY ═══════════════" ;;
                "summary_proto") echo "Profile     :" ;;
                "summary_endpoint") echo "Endpoint    :" ;;
                "summary_tunnel_ip") echo "Tunnel IP   :" ;;
                "summary_handshake") echo "Handshake   :" ;;
                "summary_seconds_ago") echo "sec. ago" ;;
                "summary_footer") echo "════════════════════════════════════════" ;;
                "exit_header") echo "═══════════ AWG EXIT INFO ═══════════" ;;
                "exit_avail") echo "available" ;;
                "exit_unavail") echo "unavailable" ;;
                "exit_unreachable") echo "No connectivity through the tunnel. Installation finished — the watchdog will keep bringing it up. Check with: awg-native check" ;;
                "disable_autostart") echo "Disable autostart" ;;
                "enable_autostart_cmd") echo "Enable autostart" ;;
                "watchdog_config") echo "Watchdog config" ;;
                "rollback_start") echo "Installation did not complete — rolling back changes..." ;;
                "rollback_done") echo "Changes rolled back." ;;
                "rollback_skipped") echo "A previous installation was detected — automatic rollback is skipped. Run uninstall.sh for a full removal." ;;
                *) echo "$key" ;;
            esac
            ;;
    esac
}

function ok {
    echo -e "\e[1;32m[OK]\e[0m $1"
}

function warn {
    echo -e "\e[1;33m[WARN]\e[0m $1"
}

function fail {
    echo -e "\e[1;31m[FAIL]\e[0m $1"
}

function info {
    echo -e "\e[1;34m[INFO]\e[0m $1"
}

function error_exit {
    fail "$1"
    exit 1
}

function pkg_installed {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "ok installed"
}

function apt_run {
    local log rc
    log=$(mktemp)
    DEBIAN_FRONTEND=noninteractive apt-get "$@" >"$log" 2>&1
    rc=$?
    if [[ $rc -ne 0 ]]; then
        tail -n 40 "$log" >&2 || true
        rm -f "$log"
        return "$rc"
    fi
    rm -f "$log"
    return 0
}

function kernel_supports_awg31 {
    local major minor rest
    IFS=. read -r major minor rest <<<"$(uname -r | cut -d- -f1)"
    major=${major:-0}
    minor=${minor:-0}
    if (( major > 6 )); then
        return 0
    fi
    if (( major == 6 && minor >= 7 )); then
        return 0
    fi
    return 1
}

function conf_key {
    local s="${1%%#*}"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    [[ "$s" == *"="* ]] || return 1
    local k="${s%%=*}"
    k="${k#"${k%%[![:space:]]*}"}"
    k="${k%"${k##*[![:space:]]}"}"
    printf '%s' "${k,,}"
}

function conf_value {
    local s="${1%%#*}"
    local v="${s#*=}"
    v="${v#"${v%%[![:space:]]*}"}"
    v="${v%"${v##*[![:space:]]}"}"
    printf '%s' "$v"
}

function ipv4_only_list {
    local raw="$1" part out=""
    local -a parts=()
    IFS=',' read -r -a parts <<<"$raw"
    for part in "${parts[@]}"; do
        part="${part//[[:space:]]/}"
        if [[ "$part" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+$ ]]; then
            out+="${out:+, }${part}"
        fi
    done
    printf '%s' "$out"
}

function s_floor {
    local v="${1//[[:space:]]/}"
    local left="${v%%-*}"
    if [[ "$left" =~ ^[0-9]+$ ]]; then
        printf '%s' "$((10#$left))"
        return 0
    fi
    return 1
}

### Переписывает клиентский профиль под ту же схему, что warp-native делал с wgcf:
### DNS и хуки убираются, Table = off не даёт awg-quick забрать маршрут по умолчанию,
### AllowedIPs = 0.0.0.0/0 оставляет шифрование всего IPv4, который вышел в интерфейс.
### Jc/Jmin/Jmax/S/H/I, HeaderProtectionKey и ContentPaddingAddition не меняются.
function prepare_client_config {
    local src="$1" dst="$2"
    local line key value trimmed section="none"
    local have_iface=0 have_peer=0 have_priv=0 have_hpk=0 have_v4=0 have_endpoint=0
    local serverish=0 peer_open=0
    local peer_keepalive=0 peer_pubkey=0 peer_endpoint=0 peer_allowed=0
    local -a out=()
    local -A smin=()
    local normalized tmp

    PREPARE_ERROR=""
    PREPARE_DETAIL=""
    PREPARE_STRIPPED_HOOKS=0

    tmp=$(mktemp)
    sed '1s/^\xEF\xBB\xBF//; s/\r$//' "$src" >"$tmp" || { rm -f "$tmp"; PREPARE_ERROR="not_a_config"; return 1; }

    finish_peer() {
        [[ "$peer_open" -eq 1 ]] || return 0
        if [[ "$peer_allowed" -eq 0 ]]; then
            out+=("AllowedIPs = 0.0.0.0/0")
        fi
        if [[ "$peer_keepalive" -eq 0 ]]; then
            out+=("PersistentKeepalive = 25")
        fi
        if [[ "$peer_pubkey" -eq 0 || "$peer_endpoint" -eq 0 ]]; then
            PREPARE_ERROR="missing_keys"
        fi
        if [[ "$peer_endpoint" -eq 1 ]]; then
            have_endpoint=1
        fi
        peer_open=0
    }

    while IFS= read -r line || [[ -n "$line" ]]; do
        trimmed="${line#"${line%%[![:space:]]*}"}"
        if [[ "$section" == "none" ]]; then
            [[ -z "${trimmed}" || "$trimmed" == \#* ]] && continue
            if [[ "$trimmed" == vpn://* ]]; then
                PREPARE_ERROR="vpn_uri"
                rm -f "$tmp"
                return 1
            fi
        fi

        if [[ "$trimmed" == "[Interface]" ]]; then
            if [[ "$have_iface" -eq 1 ]]; then
                PREPARE_ERROR="not_a_config"
                rm -f "$tmp"
                return 1
            fi
            finish_peer
            section="iface"
            have_iface=1
            out+=("[Interface]")
            out+=("Table = off")
            continue
        fi
        if [[ "$trimmed" == "[Peer]" ]]; then
            if [[ "$have_iface" -eq 0 ]]; then
                PREPARE_ERROR="not_a_config"
                rm -f "$tmp"
                return 1
            fi
            finish_peer
            section="peer"
            have_peer=1
            peer_open=1
            peer_keepalive=0
            peer_pubkey=0
            peer_endpoint=0
            peer_allowed=0
            out+=("[Peer]")
            continue
        fi
        if [[ "$trimmed" == \[*\] ]]; then
            PREPARE_ERROR="not_a_config"
            rm -f "$tmp"
            return 1
        fi
        if [[ "$section" == "none" ]]; then
            PREPARE_ERROR="not_a_config"
            rm -f "$tmp"
            return 1
        fi

        if ! key=$(conf_key "$line"); then
            out+=("$line")
            continue
        fi
        value=$(conf_value "$line")

        case "$key" in
            dns|table|fwmark|saveconfig)
                continue
                ;;
            preup|postup|predown|postdown)
                PREPARE_STRIPPED_HOOKS=1
                continue
                ;;
            listenport)
                serverish=1
                continue
                ;;
        esac

        if [[ "$section" == "iface" ]]; then
            case "$key" in
                privatekey) have_priv=1 ;;
                headerprotectionkey)
                    [[ -n "$value" ]] && have_hpk=1
                    ;;
                address)
                    value=$(ipv4_only_list "$value")
                    [[ -z "$value" ]] && continue
                    have_v4=1
                    out+=("Address = ${value}")
                    continue
                    ;;
                s1|s2|s3|s4)
                    if floor=$(s_floor "$value"); then
                        smin["$key"]=$floor
                    else
                        smin["$key"]=-1
                    fi
                    ;;
            esac
        else
            case "$key" in
                publickey) [[ -n "$value" ]] && peer_pubkey=1 ;;
                endpoint) [[ -n "$value" ]] && peer_endpoint=1 ;;
                allowedips)
                    if [[ "$peer_allowed" -eq 0 ]]; then
                        out+=("AllowedIPs = 0.0.0.0/0")
                        peer_allowed=1
                    fi
                    continue
                    ;;
                persistentkeepalive) peer_keepalive=1 ;;
            esac
        fi
        out+=("$line")
    done <"$tmp"
    rm -f "$tmp"
    finish_peer

    if [[ "$serverish" -eq 1 ]]; then
        PREPARE_ERROR="server_config"
        return 1
    fi
    if [[ "$have_iface" -eq 0 || "$have_peer" -eq 0 ]]; then
        PREPARE_ERROR="not_a_config"
        return 1
    fi
    if [[ -n "$PREPARE_ERROR" ]]; then
        return 1
    fi
    if [[ "$have_priv" -eq 0 ]]; then
        PREPARE_ERROR="missing_keys"
        return 1
    fi
    if [[ "$have_hpk" -eq 0 ]]; then
        PREPARE_ERROR="missing_hpk"
        return 1
    fi
    if [[ "$have_v4" -eq 0 ]]; then
        PREPARE_ERROR="missing_address"
        return 1
    fi
    if [[ "$have_endpoint" -eq 0 ]]; then
        PREPARE_ERROR="missing_keys"
        return 1
    fi

    local sk
    for sk in s1 s2 s3 s4; do
        if [[ -z "${smin[$sk]+x}" ]]; then
            PREPARE_ERROR="s_too_small"
            PREPARE_DETAIL="$(printf '%s' "$sk" | tr '[:lower:]' '[:upper:]') missing"
            return 1
        fi
        if (( smin[$sk] < 12 )); then
            PREPARE_ERROR="s_too_small"
            PREPARE_DETAIL="$(printf '%s' "$sk" | tr '[:lower:]' '[:upper:]')=${smin[$sk]}"
            return 1
        fi
    done

    normalized=$(mktemp)
    printf '%s\n' "${out[@]}" >"$normalized"
    install -m 600 "$normalized" "$dst" || { rm -f "$normalized"; PREPARE_ERROR="not_a_config"; return 1; }
    rm -f "$normalized"
    return 0
}

function self_test {
    local dir src dst ok_cases=0
    dir=$(mktemp -d)
    src="${dir}/in.conf"
    dst="${dir}/out.conf"

    cat >"$src" <<'EOF'
[Interface]
PrivateKey = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=
Address = 10.9.9.2/32, fd00:1::2/128
DNS = 1.1.1.1
MTU = 1280
Jc = 4
Jmin = 40
Jmax = 70
S1 = 88
S2 = 47
S3 = 12-40
S4 = 17
H1 = 1
H2 = 2
H3 = 3
H4 = 4
I1 = <r 2><b 0x858000010002000000001c>
HeaderProtectionKey = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb=
ContentPaddingAddition = 32-128
FwMark = 1234
PostUp = iptables -A FORWARD -j ACCEPT

[Peer]
PublicKey = ccccccccccccccccccccccccccccccccccccccccccc=
Endpoint = 203.0.113.10:39743
AllowedIPs = 0.0.0.0/0, ::/0
EOF

    prepare_client_config "$src" "$dst" || { echo "valid config rejected: $PREPARE_ERROR $PREPARE_DETAIL" >&2; return 1; }
    grep -q '^Table = off$' "$dst" || { echo "Table = off missing" >&2; return 1; }
    grep -q '^DNS' "$dst" && { echo "DNS kept" >&2; return 1; }
    grep -q 'FwMark' "$dst" && { echo "FwMark kept" >&2; return 1; }
    grep -q 'PostUp' "$dst" && { echo "PostUp kept" >&2; return 1; }
    grep -q 'fd00' "$dst" && { echo "IPv6 address kept" >&2; return 1; }
    grep -q '^AllowedIPs = 0.0.0.0/0$' "$dst" || { echo "AllowedIPs not rewritten" >&2; return 1; }
    grep -q '^PersistentKeepalive = 25$' "$dst" || { echo "keepalive missing" >&2; return 1; }
    grep -q '^HeaderProtectionKey = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb=$' "$dst" || { echo "HPK changed" >&2; return 1; }
    grep -q '^I1 = <r 2><b 0x858000010002000000001c>$' "$dst" || { echo "I1 changed" >&2; return 1; }
    grep -q '^S3 = 12-40$' "$dst" || { echo "S3 changed" >&2; return 1; }
    grep -q '^Endpoint = 203.0.113.10:39743$' "$dst" || { echo "endpoint changed" >&2; return 1; }
    [[ "$PREPARE_STRIPPED_HOOKS" -eq 1 ]] || { echo "hook flag not set" >&2; return 1; }
    ok_cases=$((ok_cases + 1))

    printf '%s\r\n' '[Interface]' 'PrivateKey = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=' 'Address = 10.8.0.2/32' 'HeaderProtectionKey = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb=' 'S1 = 12' 'S2 = 12' 'S3 = 12' 'S4 = 12' '[Peer]' 'PublicKey = ccccccccccccccccccccccccccccccccccccccccccc=' 'Endpoint = example.com:51820' >"$src"
    prepare_client_config "$src" "$dst" || { echo "crlf config rejected: $PREPARE_ERROR" >&2; return 1; }
    grep -q $'\r' "$dst" && { echo "CR kept" >&2; return 1; }
    ok_cases=$((ok_cases + 1))

    cat >"$src" <<'EOF'
[Interface]
PrivateKey = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=
Address = 10.9.9.2/32
ListenPort = 51820
S1 = 20
S2 = 20
S3 = 20
S4 = 20
HeaderProtectionKey = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb=
[Peer]
PublicKey = ccccccccccccccccccccccccccccccccccccccccccc=
AllowedIPs = 10.9.9.2/32
EOF
    if prepare_client_config "$src" "$dst"; then
        echo "server config accepted" >&2
        return 1
    fi
    [[ "$PREPARE_ERROR" == "server_config" ]] || { echo "server error is $PREPARE_ERROR" >&2; return 1; }
    ok_cases=$((ok_cases + 1))

    cat >"$src" <<'EOF'
[Interface]
PrivateKey = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=
Address = 10.9.9.2/32
S1 = 20
S2 = 20
S3 = 20
S4 = 8
[Peer]
PublicKey = ccccccccccccccccccccccccccccccccccccccccccc=
Endpoint = 203.0.113.10:1
EOF
    if prepare_client_config "$src" "$dst"; then
        echo "config without 3.1 key accepted" >&2
        return 1
    fi
    [[ "$PREPARE_ERROR" == "missing_hpk" ]] || { echo "hpk error is $PREPARE_ERROR" >&2; return 1; }
    ok_cases=$((ok_cases + 1))

    cat >"$src" <<'EOF'
[Interface]
PrivateKey = aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa=
Address = 10.9.9.2/32
HeaderProtectionKey = bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb=
S1 = 20
S2 = 20
S3 = 20
S4 = 8
[Peer]
PublicKey = ccccccccccccccccccccccccccccccccccccccccccc=
Endpoint = 203.0.113.10:1
EOF
    if prepare_client_config "$src" "$dst"; then
        echo "short S4 accepted" >&2
        return 1
    fi
    [[ "$PREPARE_ERROR" == "s_too_small" && "$PREPARE_DETAIL" == "S4=8" ]] || { echo "s error is $PREPARE_ERROR $PREPARE_DETAIL" >&2; return 1; }
    ok_cases=$((ok_cases + 1))

    printf 'vpn://something\n' >"$src"
    if prepare_client_config "$src" "$dst"; then
        echo "vpn uri accepted" >&2
        return 1
    fi
    [[ "$PREPARE_ERROR" == "vpn_uri" ]] || { echo "uri error is $PREPARE_ERROR" >&2; return 1; }
    ok_cases=$((ok_cases + 1))

    rm -rf "$dir"
    echo "self-test ok (${ok_cases} cases)"
}

if [[ "${1:-}" == "--self-test" ]]; then
    self_test
    exit $?
fi
if [[ $# -ge 1 ]]; then
    CONF_ARG="$1"
fi

NFT_PREINSTALLED=false
CRON_PREINSTALLED=false
AWG_PKGS_PREINSTALLED=()
PREV_INSTALL=false
ROLLBACK_ARMED=false
INSTALL_COMPLETE=false
PPA_ADDED_BY_US=false
KEYRING_ADDED_BY_US=false

function rollback_install {
    echo ""
    warn "$(msg "rollback_start")"

    systemctl disable --now "$UNIT" &>/dev/null || true
    awg-quick down "$IFACE" &>/dev/null || true
    ip link delete "$IFACE" &>/dev/null || true
    ip link delete awgprobe &>/dev/null || true
    systemctl disable --now awg-native-killswitch.service &>/dev/null || true
    nft delete table inet awg_native &>/dev/null || true

    rm -f /etc/cron.d/awg-native
    rm -f /etc/systemd/system/awg-native-killswitch.service
    rm -f /etc/systemd/system/awg-quick@awg.service.d/awg-native-killswitch.conf
    rm -f /etc/systemd/system/nftables.service.d/awg-native-killswitch.conf
    rmdir /etc/systemd/system/awg-quick@awg.service.d /etc/systemd/system/nftables.service.d &>/dev/null || true
    systemctl daemon-reload &>/dev/null || true
    systemctl reset-failed "$UNIT" awg-native-killswitch.service &>/dev/null || true

    rm -rf "$STATE_DIR"
    rm -f /usr/local/bin/awg-native
    rm -f "$CONF_FILE"
    rmdir "$CONF_DIR" /etc/amnezia &>/dev/null || true

    local pkg
    for pkg in amneziawg amneziawg-dkms amneziawg-tools amneziawg-linux-kmod; do
        local was=0 seen
        for seen in "${AWG_PKGS_PREINSTALLED[@]}"; do
            [[ "$seen" == "$pkg" ]] && was=1
        done
        if [[ "$was" -eq 0 ]] && pkg_installed "$pkg"; then
            DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y "$pkg" &>/dev/null || true
        fi
    done
    if [[ "$NFT_PREINSTALLED" == false ]] && pkg_installed nftables; then
        DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y nftables &>/dev/null || true
    fi
    if [[ "$CRON_PREINSTALLED" == false ]] && pkg_installed cron; then
        DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y cron &>/dev/null || true
    fi
    if [[ "$PPA_ADDED_BY_US" == true ]]; then
        rm -f "$PPA_LIST"
    fi
    if [[ "$KEYRING_ADDED_BY_US" == true ]]; then
        rm -f "$PPA_KEYRING"
    fi

    ok "$(msg "rollback_done")"
}

function on_exit {
    [[ -n "${client_src:-}" ]] && rm -f "$client_src"
    [[ -n "${probe_file:-}" ]] && rm -f "$probe_file"
    if [[ $EUID -eq 0 ]]; then
        ip link delete awgprobe &>/dev/null || true
    fi
    if [[ "$ROLLBACK_ARMED" == true && "$INSTALL_COMPLETE" != true ]]; then
        if [[ "$PREV_INSTALL" == true ]]; then
            warn "$(msg "rollback_skipped")"
        else
            rollback_install
        fi
    fi
}

trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

if [[ $EUID -ne 0 ]]; then
    fail "This script must be run as root / Этот скрипт должен быть запущен от имени root"
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

if [[ ! -f /etc/os-release ]]; then
    error_exit "$(msg "unsupported_os")"
fi
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}" in
    ubuntu|debian) ;;
    *)
        if [[ "${ID_LIKE:-}" != *debian* && "${ID_LIKE:-}" != *ubuntu* ]]; then
            error_exit "$(msg "unsupported_os")"
        fi
        ;;
esac

if ! kernel_supports_awg31; then
    error_exit "$(msg "kernel_too_old") $(uname -r)"
fi

if [[ -f "$CONF_FILE" || -d "$STATE_DIR" || -f /usr/local/bin/awg-native ]]; then
    PREV_INSTALL=true
fi
if pkg_installed nftables; then
    NFT_PREINSTALLED=true
fi
if pkg_installed cron; then
    CRON_PREINSTALLED=true
fi
for pkg in amneziawg amneziawg-dkms amneziawg-tools amneziawg-linux-kmod; do
    if pkg_installed "$pkg"; then
        AWG_PKGS_PREINSTALLED+=("$pkg")
    fi
done
ROLLBACK_ARMED=true

info "$(msg "start_install")"
echo ""
info "$(msg "install_packages")"

apt_run update || error_exit "$(msg "update_failed")"
apt_run install -y curl ca-certificates gnupg nftables cron iproute2 || error_exit "$(msg "base_packages_failed")"

ppa_codename=""
case "${ID:-ubuntu}" in
    debian)
        case "${VERSION_CODENAME:-}" in
            bookworm) ppa_codename="focal" ;;
            *) ppa_codename="noble" ;;
        esac
        ;;
    *)
        ppa_codename="${UBUNTU_CODENAME:-${VERSION_CODENAME:-noble}}"
        case "$ppa_codename" in
            noble|jammy|focal) ;;
            *)
                if ! curl -fsI --max-time 15 "https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu/dists/${ppa_codename}/Release" >/dev/null 2>&1; then
                    warn "$(msg "ppa_fallback")"
                    ppa_codename="noble"
                fi
                ;;
        esac
        ;;
esac

install -d -m 0755 /etc/apt/keyrings
if [[ ! -f "$PPA_KEYRING" ]]; then
    key_tmp=$(mktemp)
    curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${PPA_KEY_ID}" -o "$key_tmp" \
        || curl -fsSL "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x${PPA_KEY_ID}&options=mr" -o "$key_tmp" \
        || error_exit "$(msg "repo_failed")"
    gpg --dearmor --output "$PPA_KEYRING" "$key_tmp" || { rm -f "$key_tmp" "$PPA_KEYRING"; error_exit "$(msg "repo_failed")"; }
    rm -f "$key_tmp"
    chmod 644 "$PPA_KEYRING"
    KEYRING_ADDED_BY_US=true
fi

ppa_existed=false
[[ -f "$PPA_LIST" ]] && ppa_existed=true
if [[ "$ppa_existed" == false ]] || ! grep -q "[[:space:]]${ppa_codename}[[:space:]]" "$PPA_LIST"; then
    printf 'deb [signed-by=%s] https://ppa.launchpadcontent.net/amnezia/ppa/ubuntu %s main\n' "$PPA_KEYRING" "$ppa_codename" >"$PPA_LIST" \
        || error_exit "$(msg "repo_failed")"
    chmod 644 "$PPA_LIST"
    [[ "$ppa_existed" == false ]] && PPA_ADDED_BY_US=true
fi

apt_run update || error_exit "$(msg "update_failed")"

kheaders="linux-headers-$(uname -r)"
if ! apt_run install -y "$kheaders"; then
    warn "$(msg "headers_missing")"
    if [[ "${ID:-}" == "ubuntu" || "${ID_LIKE:-}" == *ubuntu* ]]; then
        apt_run install -y linux-headers-generic || true
    elif [[ "$(uname -m)" == "aarch64" || "$(uname -m)" == "arm64" ]]; then
        apt_run install -y linux-headers-arm64 || true
    else
        apt_run install -y linux-headers-amd64 || true
    fi
fi

if ! apt_run install -y amneziawg; then
    apt_run install -y amneziawg-dkms amneziawg-tools || error_exit "$(msg "awg_install_failed")"
fi
if ! command -v awg >/dev/null 2>&1 || ! command -v awg-quick >/dev/null 2>&1; then
    apt_run install -y amneziawg-tools || error_exit "$(msg "tools_missing")"
fi
command -v awg >/dev/null 2>&1 && command -v awg-quick >/dev/null 2>&1 || error_exit "$(msg "tools_missing")"

modprobe amneziawg || error_exit "$(msg "module_failed")"

probe_priv=$(awg genkey | tr -d '\n')
probe_pub=$(printf '%s' "$probe_priv" | awg pubkey | tr -d '\n')
probe_hpk=$(awg genkey | tr -d '\n')
probe_file=$(mktemp)
chmod 600 "$probe_file"
cat >"$probe_file" <<EOF
[Interface]
PrivateKey = ${probe_priv}
HeaderProtectionKey = ${probe_hpk}
S1 = 12
S2 = 12
S3 = 12
S4 = 12
Jc = 1
Jmin = 40
Jmax = 70
H1 = 1
H2 = 2
H3 = 3
H4 = 4

[Peer]
PublicKey = ${probe_pub}
Endpoint = 127.0.0.1:1
AllowedIPs = 0.0.0.0/0
EOF
unset probe_priv probe_pub probe_hpk

ip link delete awgprobe &>/dev/null || true
ip link add awgprobe type amneziawg || { rm -f "$probe_file"; error_exit "$(msg "module_failed")"; }
probe_err=$(mktemp)
if ! awg setconf awgprobe "$probe_file" >"$probe_err" 2>&1; then
    sed -E 's/((Private|Public|Preshared|HeaderProtection)Key[[:space:]]*=[[:space:]]*).*/\1[hidden]/I' "$probe_err" >&2 || true
    rm -f "$probe_err" "$probe_file"
    ip link delete awgprobe &>/dev/null || true
    error_exit "$(msg "probe_failed")"
fi
rm -f "$probe_err"
if ! awg showconf awgprobe 2>/dev/null | grep -qi '^[[:space:]]*HeaderProtectionKey[[:space:]]*='; then
    rm -f "$probe_file"
    ip link delete awgprobe &>/dev/null || true
    error_exit "$(msg "probe_failed")"
fi
ip link delete awgprobe &>/dev/null || true
rm -f "$probe_file"
ok "$(msg "awg_ok")"
echo ""

info "$(msg "read_config")"
client_src=$(mktemp)
chmod 600 "$client_src"

if [[ -n "${AWG_CONF_FILE:-}" ]]; then
    [[ -f "$AWG_CONF_FILE" ]] || error_exit "$(msg "conf_not_found")"
    cp "$AWG_CONF_FILE" "$client_src"
elif [[ -n "$CONF_ARG" ]]; then
    [[ -f "$CONF_ARG" ]] || error_exit "$(msg "conf_not_found")"
    cp "$CONF_ARG" "$client_src"
elif [[ -t 0 ]]; then
    read -r -p "$(msg "conf_path_prompt")" conf_path
    conf_path="${conf_path#"${conf_path%%[![:space:]]*}"}"
    conf_path="${conf_path%"${conf_path##*[![:space:]]}"}"
    conf_path="${conf_path/#\~/$HOME}"
    if [[ -n "$conf_path" ]]; then
        [[ -f "$conf_path" ]] || error_exit "$(msg "conf_not_found")"
        cp "$conf_path" "$client_src"
    else
        info "$(msg "conf_paste_prompt")"
        while IFS= read -r line; do
            [[ "$line" == "END" ]] && break
            printf '%s\n' "$line" >>"$client_src"
        done
    fi
else
    error_exit "$(msg "conf_required")"
fi

if [[ ! -s "$client_src" ]]; then
    rm -f "$client_src"
    error_exit "$(msg "conf_empty")"
fi

install -d -m 700 /etc/amnezia
install -d -m 700 "$CONF_DIR"
install -d -m 700 "$STATE_DIR"
if [[ -f "$CONF_FILE" ]]; then
    cp "$CONF_FILE" "${STATE_DIR}/awg.conf.prev"
    chmod 600 "${STATE_DIR}/awg.conf.prev"
fi

prepare_client_config "$client_src" "$CONF_FILE" || {
    detail=""
    [[ -n "$PREPARE_DETAIL" ]] && detail=" ${PREPARE_DETAIL}"
    rm -f "$client_src"
    error_exit "$(msg "$PREPARE_ERROR")${detail}"
}
rm -f "$client_src"
chmod 600 "$CONF_FILE"
ok "$(msg "config_ready")"
if [[ "$PREPARE_STRIPPED_HOOKS" -eq 1 ]]; then
    info "$(msg "hooks_removed")"
fi
ok "$(msg "saved_config")"
echo ""

info "$(msg "connect")"
systemctl stop "$UNIT" &>/dev/null || true
awg-quick down "$IFACE" &>/dev/null || true
ip link delete "$IFACE" &>/dev/null || true
systemctl reset-failed "$UNIT" &>/dev/null || true
if ! systemctl start "$UNIT"; then
    journalctl -u "$UNIT" -n 40 --no-pager 2>/dev/null \
        | sed -E 's/((Private|Public|Preshared|HeaderProtection)Key[[:space:]]*=[[:space:]]*).*/\1[hidden]/I' >&2 || true
    error_exit "$(msg "connect_failed")"
fi
ok "$(msg "connected")"
echo ""

info "$(msg "check_status")"
handshake_ts=0
if ! awg show "$IFACE" &>/dev/null; then
    warn "$(msg "iface_missing")"
else
    HANDSHAKE_WAIT=15
    SPIN='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    for ((i=0; i<HANDSHAKE_WAIT; i++)); do
        handshake_ts=$(awg show "$IFACE" latest-handshakes 2>/dev/null | awk '$2 > max { max = $2 } END { print max + 0 }')
        if [[ -n "$handshake_ts" && "$handshake_ts" -gt 0 ]]; then
            break
        fi
        c="${SPIN:i%10:1}"
        printf "\r\e[1;34m[..]\e[0m $(msg "waiting_handshake") \e[1;36m%s\e[0m  %ss " "$c" "$((HANDSHAKE_WAIT - i))"
        sleep 1
    done
    printf "\r\e[K"
    if [[ -n "$handshake_ts" && "$handshake_ts" -gt 0 ]]; then
        age=$(( $(date +%s) - handshake_ts ))
        ok "$(msg "handshake_received") ${age}s ago"
        ok "$(msg "tunnel_active")"
    else
        info "$(msg "handshake_pending")"
    fi
fi
echo ""

info "$(msg "enable_autostart")"
systemctl enable "$UNIT" &>/dev/null || error_exit "$(msg "autostart_failed")"
ok "$(msg "autostart_enabled")"
echo ""

info "$(msg "setup_watchdog")"
echo ""

WATCHDOG_INTERVAL=5
WATCHDOG_CRON_INTERVAL="*/5 * * * *"
if [[ -n "${AWG_WATCHDOG_MINUTES:-}" ]]; then
    case "$AWG_WATCHDOG_MINUTES" in
        10) WATCHDOG_INTERVAL=10; WATCHDOG_CRON_INTERVAL="*/10 * * * *" ;;
        15) WATCHDOG_INTERVAL=15; WATCHDOG_CRON_INTERVAL="*/15 * * * *" ;;
        30) WATCHDOG_INTERVAL=30; WATCHDOG_CRON_INTERVAL="*/30 * * * *" ;;
        *) WATCHDOG_INTERVAL=5; WATCHDOG_CRON_INTERVAL="*/5 * * * *" ;;
    esac
elif [[ -t 0 ]]; then
    info "$(msg "watchdog_interval_prompt")"
    echo -e "\e[1;32m$(msg "watchdog_opt_5")\e[0m"
    echo -e "\e[1;32m$(msg "watchdog_opt_10")\e[0m"
    echo -e "\e[1;32m$(msg "watchdog_opt_15")\e[0m"
    echo -e "\e[1;32m$(msg "watchdog_opt_30")\e[0m"
    echo ""
    read -r -p "Choice / Выбор [1-4, Enter = 1]: " wdog_choice
    case "$wdog_choice" in
        2) WATCHDOG_INTERVAL=10; WATCHDOG_CRON_INTERVAL="*/10 * * * *" ;;
        3) WATCHDOG_INTERVAL=15; WATCHDOG_CRON_INTERVAL="*/15 * * * *" ;;
        4) WATCHDOG_INTERVAL=30; WATCHDOG_CRON_INTERVAL="*/30 * * * *" ;;
        *) WATCHDOG_INTERVAL=5; WATCHDOG_CRON_INTERVAL="*/5 * * * *" ;;
    esac
fi

ok "$(msg "watchdog_interval_set") ${WATCHDOG_INTERVAL} min"
echo ""

install -d -m 700 "${STATE_DIR}/logs" || error_exit "$(msg "watchdog_dir_failed")"
printf '%s\n' "$SCRIPT_LANG" >"${STATE_DIR}/lang"
chmod 600 "${STATE_DIR}/lang"

cat >"${STATE_DIR}/config.env" <<'EOF'
# awg-native watchdog configuration
# Edited values take effect on the next cron run

# Cooldown between restarts in seconds (default: 120)
RESTART_COOLDOWN=120

# Max log lines before rotation (default: 1000)
LOG_MAX_LINES=1000
EOF
chmod 600 "${STATE_DIR}/config.env"

cat >"${STATE_DIR}/awg-killswitch.sh" <<'KILLSWITCH_EOF'
#!/bin/bash
set -euo pipefail

TABLE="awg_native"
CHAIN="awg_native_killswitch"
MARK="51888"
IFACE="awg"

enable_killswitch() {
    if ! nft list table inet "$TABLE" &>/dev/null; then
        nft -f - <<EOF
add table inet $TABLE
add chain inet $TABLE $CHAIN { type filter hook output priority -150; policy accept; }
add rule inet $TABLE $CHAIN meta mark $MARK oifname != "$IFACE" counter drop comment "awg-native kill-switch"
EOF
    elif ! nft list chain inet "$TABLE" "$CHAIN" &>/dev/null; then
        nft -f - <<EOF
add chain inet $TABLE $CHAIN { type filter hook output priority -150; policy accept; }
add rule inet $TABLE $CHAIN meta mark $MARK oifname != "$IFACE" counter drop comment "awg-native kill-switch"
EOF
    else
        nft -f - <<EOF
flush chain inet $TABLE $CHAIN
add rule inet $TABLE $CHAIN meta mark $MARK oifname != "$IFACE" counter drop comment "awg-native kill-switch"
EOF
    fi
}

case "${1:-}" in
    start)
        enable_killswitch
        ;;
    stop)
        nft delete chain inet "$TABLE" "$CHAIN" 2>/dev/null || true
        ;;
    status)
        nft -a list chain inet "$TABLE" "$CHAIN"
        ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
KILLSWITCH_EOF
chmod 700 "${STATE_DIR}/awg-killswitch.sh"

cat > /etc/systemd/system/awg-native-killswitch.service <<'KILLSWITCH_SERVICE_EOF'
[Unit]
Description=AWG Native fail-closed kill-switch
After=nftables.service
Before=awg-quick@awg.service

[Service]
Type=oneshot
ExecStart=/opt/awg-native/awg-killswitch.sh start
ExecStop=/opt/awg-native/awg-killswitch.sh stop
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
KILLSWITCH_SERVICE_EOF

install -d /etc/systemd/system/nftables.service.d
cat > /etc/systemd/system/nftables.service.d/awg-native-killswitch.conf <<'NFTABLES_DROPIN_EOF'
[Service]
ExecStartPost=/opt/awg-native/awg-killswitch.sh start
ExecReload=/opt/awg-native/awg-killswitch.sh start
NFTABLES_DROPIN_EOF

install -d /etc/systemd/system/awg-quick@awg.service.d
cat > /etc/systemd/system/awg-quick@awg.service.d/awg-native-killswitch.conf <<'AWG_DEPENDENCY_EOF'
[Unit]
Requires=awg-native-killswitch.service
After=awg-native-killswitch.service

[Service]
ExecStartPre=/opt/awg-native/awg-killswitch.sh start
AWG_DEPENDENCY_EOF

systemctl daemon-reload
systemctl enable --now awg-native-killswitch.service &>/dev/null || error_exit "$(msg "killswitch_failed")"
ok "$(msg "killswitch_enabled")"
echo ""

cat >"${STATE_DIR}/awg-watchdog.sh" <<'WATCHDOG_EOF'
#!/bin/bash

CONFIG="/opt/awg-native/config.env"
LOG="/opt/awg-native/logs/watchdog.log"
COOLDOWN_FILE="/opt/awg-native/logs/.last_restart"
IFACE="awg"
UNIT="awg-quick@awg"

if [[ -f "$CONFIG" ]]; then
    # shellcheck disable=SC1090
    source "$CONFIG"
fi

RESTART_COOLDOWN="${RESTART_COOLDOWN:-120}"
LOG_MAX_LINES="${LOG_MAX_LINES:-1000}"

log() {
    local level="$1"
    local message="$2"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$ts] [$level] $message" >>"$LOG"
}

rotate_log() {
    if [[ -f "$LOG" ]]; then
        local lines
        lines=$(wc -l <"$LOG")
        if [[ $lines -gt $LOG_MAX_LINES ]]; then
            tail -n "$LOG_MAX_LINES" "$LOG" >"${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
        fi
    fi
}

do_restart() {
    local reason="$1"

    if [[ -f "$COOLDOWN_FILE" ]]; then
        local last_restart now diff
        last_restart=$(cat "$COOLDOWN_FILE")
        now=$(date +%s)
        diff=$(( now - last_restart ))
        if [[ $diff -lt $RESTART_COOLDOWN ]]; then
            log "SKIP" "Restart skipped (cooldown: ${diff}s < ${RESTART_COOLDOWN}s). Reason was: $reason"
            return
        fi
    fi

    log "RESTART" "Restarting ${UNIT}. Reason: $reason"

    if ! systemctl is-active --quiet "$UNIT" && ip link show "$IFACE" &>/dev/null; then
        awg-quick down "$IFACE" &>/dev/null || ip link delete "$IFACE" &>/dev/null
    fi

    systemctl restart "$UNIT"
    local ret=$?
    date +%s >"$COOLDOWN_FILE"

    if [[ $ret -eq 0 ]]; then
        log "OK" "${UNIT} restarted successfully"
    else
        log "ERROR" "Failed to restart ${UNIT} (exit code: $ret)"
    fi
}

rotate_log

if ! systemctl is-active --quiet "$UNIT"; then
    do_restart "systemd unit is not active"
    exit 0
fi

handshake_ts=$(awg show "$IFACE" latest-handshakes 2>/dev/null | awk '$2 > max { max = $2 } END { print max + 0 }')
if [[ -n "$handshake_ts" && "$handshake_ts" -gt 0 ]]; then
    hs_age=$(( $(date +%s) - handshake_ts ))
else
    hs_age="n/a"
fi

if ping -I "$IFACE" -c 2 -W 3 1.1.1.1 &>/dev/null; then
    log "OK" "AWG is healthy via ICMP (handshake: ${hs_age}s ago)"
    exit 0
fi

if curl -s --interface "$IFACE" --max-time 8 https://ifconfig.co/json 2>/dev/null | grep -q '"ip"'; then
    log "OK" "AWG is healthy via TCP (ICMP blocked; handshake: ${hs_age}s ago)"
    exit 0
fi

do_restart "no connectivity via awg (ICMP + TCP failed; handshake: ${hs_age}s ago)"
exit 0
WATCHDOG_EOF
chmod 700 "${STATE_DIR}/awg-watchdog.sh"
ok "$(msg "watchdog_created")"

cat > /etc/cron.d/awg-native <<EOF
# awg-native watchdog — checks the AmneziaWG tunnel
${WATCHDOG_CRON_INTERVAL} root /opt/awg-native/awg-watchdog.sh
EOF
chmod 644 /etc/cron.d/awg-native
systemctl enable --now cron &>/dev/null || systemctl enable --now crond &>/dev/null || true
ok "$(msg "watchdog_cron_set")"
echo ""

info "$(msg "setup_command")"

cat > /usr/local/bin/awg-native <<'AWG_CMD_EOF'
#!/bin/bash

IFACE="awg"
UNIT="awg-quick@awg"
LANG_FILE="/opt/awg-native/lang"
SCRIPT_LANG="en"
[[ -f "$LANG_FILE" ]] && SCRIPT_LANG=$(cat "$LANG_FILE")

function fetch_awg {
    local url="$1" out=""
    local attempt
    for attempt in 1 2 3; do
        out=$(curl -s --interface "$IFACE" --max-time 8 "$url" 2>/dev/null)
        [[ -n "$out" ]] && { printf '%s' "$out"; return 0; }
        sleep 1
    done
    return 1
}

function check_exit {
    if [[ "$SCRIPT_LANG" == "ru" ]]; then
        echo -e "\e[1;36mВыход через AmneziaWG:\e[0m"
        local pending="проверяю выход..."
        local provider="Провайдер"
    else
        echo -e "\e[1;36mExit through AmneziaWG:\e[0m"
        local pending="checking exit..."
        local provider="Provider"
    fi
    echo -e "\e[1;35m──────────────────────────────────────\e[0m"
    printf "  \e[2;37m%s\e[0m\r" "$pending"

    local ij ip1 co1 ci1 asn aj co2 isp cg
    ij=$(fetch_awg https://ifconfig.co/json)
    ip1=$(echo "$ij" | grep -oE '"ip":[ ]*"[^"]*"' | cut -d'"' -f4)
    co1=$(echo "$ij" | grep -oE '"country":[ ]*"[^"]*"' | cut -d'"' -f4)
    ci1=$(echo "$ij" | grep -oE '"city":[ ]*"[^"]*"' | cut -d'"' -f4)
    asn=$(echo "$ij" | grep -oE '"asn_org":[ ]*"[^"]*"' | cut -d'"' -f4)

    aj=$(fetch_awg http://ip-api.com/json)
    co2=$(echo "$aj" | grep -oE '"country":[ ]*"[^"]*"' | cut -d'"' -f4)
    isp=$(echo "$aj" | grep -oE '"isp":[ ]*"[^"]*"' | cut -d'"' -f4)

    printf "  \e[1;36mIP          \e[0m %s\n" "${ip1:-—}"
    printf "  \e[1;36mifconfig.co \e[0m %s%s\n" "${co1:-—}" "${ci1:+, $ci1}"
    printf "  \e[1;36mip-api      \e[0m %s\n" "${co2:-—}"
    printf "  \e[1;36m%s   \e[0m %s\n" "$provider" "${asn:-${isp:-—}}"

    cg=$(fetch_awg https://chatgpt.com/cdn-cgi/trace | grep '^loc=' | cut -d= -f2)
    printf "                      \r"
    local v
    if [[ -n "$cg" ]]; then
        if [[ "$cg" =~ ^(RU|CN|BY|IR|KP|CU|SY|VE)$ ]]; then
            if [[ "$SCRIPT_LANG" == "ru" ]]; then
                v="\e[1;31mнедоступен\e[0m ($cg)"
            else
                v="\e[1;31munavailable\e[0m ($cg)"
            fi
        else
            if [[ "$SCRIPT_LANG" == "ru" ]]; then
                v="\e[1;32mдоступен\e[0m ($cg)"
            else
                v="\e[1;32mavailable\e[0m ($cg)"
            fi
        fi
    else
        v="—"
    fi
    printf "  \e[1;36mChatGPT     \e[0m %b\n" "$v"
    echo -e "\e[1;35m──────────────────────────────────────\e[0m"
}

function show_status {
    echo ""
    echo -e "\e[1;35m╭─────────────────────────────────────╮"
    echo -e "│      \e[1;36m   A W G - N A T I V E         \e[1;35m│"
    echo -e "│     \e[2;37m      AmneziaWG 3.1            \e[1;35m│"
    echo -e "\e[1;35m╰─────────────────────────────────────╯\e[0m"
    echo ""

    local status tunnel_ip hs_ts age handshake endpoint
    if systemctl is-active --quiet "$UNIT"; then
        status="\e[1;32mactive\e[0m"
    else
        status="\e[1;31minactive\e[0m"
    fi

    tunnel_ip=$(ip addr show "$IFACE" 2>/dev/null | grep 'inet ' | awk '{print $2}' | head -1)
    [[ -z "$tunnel_ip" ]] && tunnel_ip="—"

    hs_ts=$(awg show "$IFACE" latest-handshakes 2>/dev/null | awk '$2 > max { max = $2 } END { print max + 0 }')
    if [[ -n "$hs_ts" && "$hs_ts" -gt 0 ]]; then
        age=$(( $(date +%s) - hs_ts ))
        handshake="${age}s ago"
    else
        handshake="—"
    fi

    endpoint=$(awk -F= '/^[[:space:]]*Endpoint[[:space:]]*=/{ gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' /etc/amnezia/amneziawg/awg.conf 2>/dev/null)
    [[ -z "$endpoint" ]] && endpoint="—"

    if [[ "$SCRIPT_LANG" == "ru" ]]; then
        echo -e "  \e[1;36mСтатус      :\e[0m $status"
        echo -e "  \e[1;36mПрофиль     :\e[0m AmneziaWG 3.1"
        echo -e "  \e[1;36mEndpoint    :\e[0m $endpoint"
        echo -e "  \e[1;36mIP туннеля  :\e[0m $tunnel_ip"
        echo -e "  \e[1;36mHandshake   :\e[0m $handshake"
        local start_h="запустить" stop_h="остановить" restart_h="перезапустить"
        local check_h="проверить выход" log_h="лог watchdog"
    else
        echo -e "  \e[1;36mStatus      :\e[0m $status"
        echo -e "  \e[1;36mProfile     :\e[0m AmneziaWG 3.1"
        echo -e "  \e[1;36mEndpoint    :\e[0m $endpoint"
        echo -e "  \e[1;36mTunnel IP   :\e[0m $tunnel_ip"
        echo -e "  \e[1;36mHandshake   :\e[0m $handshake"
        local start_h="start" stop_h="stop" restart_h="restart"
        local check_h="check the exit" log_h="watchdog log"
    fi
    echo ""

    if systemctl is-active --quiet "$UNIT"; then
        check_exit
        echo ""
    fi

    echo -e "\e[1;35m──────────────────────────────────────\e[0m"
    echo -e "  \e[1;32mawg-native start\e[0m    — ${start_h}"
    echo -e "  \e[1;32mawg-native stop\e[0m     — ${stop_h}"
    echo -e "  \e[1;32mawg-native restart\e[0m  — ${restart_h}"
    echo -e "  \e[1;32mawg-native check\e[0m    — ${check_h}"
    echo -e "  \e[1;32mawg-native log\e[0m      — ${log_h}"
    echo -e "\e[1;35m──────────────────────────────────────\e[0m"
    echo ""
}

case "$1" in
    start)   systemctl start "$UNIT" ;;
    stop)    systemctl stop "$UNIT" ;;
    restart) systemctl restart "$UNIT" ;;
    check)   check_exit ;;
    log)
        if [[ ! -f /opt/awg-native/logs/watchdog.log ]]; then
            if [[ "$SCRIPT_LANG" == "ru" ]]; then
                echo "Лог пока пуст — watchdog ещё не запускался."
            else
                echo "The log is empty — the watchdog has not run yet."
            fi
        else
            tail -f /opt/awg-native/logs/watchdog.log
        fi
        ;;
    *) show_status ;;
esac
AWG_CMD_EOF
chmod 755 /usr/local/bin/awg-native
ok "$(msg "command_created")"
echo ""

INSTALL_COMPLETE=true

function fetch_awg {
    local url="$1" out=""
    local attempt
    for attempt in 1 2 3; do
        out=$(curl -s --interface "$IFACE" --max-time 8 "$url" 2>/dev/null)
        [[ -n "$out" ]] && { printf '%s' "$out"; return 0; }
        sleep 1
    done
    return 1
}

tunnel_ip=$(ip addr show "$IFACE" 2>/dev/null | grep 'inet ' | awk '{print $2}' | head -1)
[[ -z "$tunnel_ip" ]] && tunnel_ip="—"

final_handshake_ts=$(awg show "$IFACE" latest-handshakes 2>/dev/null | awk '$2 > max { max = $2 } END { print max + 0 }')
if [[ -n "$final_handshake_ts" && "$final_handshake_ts" -gt 0 ]]; then
    final_age=$(( $(date +%s) - final_handshake_ts ))
    handshake_display="${final_age} $(msg "summary_seconds_ago")"
else
    handshake_display="—"
fi

endpoint_display=$(awk -F= '/^[[:space:]]*Endpoint[[:space:]]*=/{ gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2; exit }' "$CONF_FILE" 2>/dev/null)
[[ -z "$endpoint_display" ]] && endpoint_display="—"

echo ""
ok "$(msg "installation_complete")"
echo ""
echo -e "\e[1;36m$(msg "summary_header")\e[0m"
echo -e "\e[1;36m  $(msg "summary_proto") \e[0mAmneziaWG 3.1"
echo -e "\e[1;36m  $(msg "summary_endpoint") \e[0m${endpoint_display}"
echo -e "\e[1;36m  $(msg "summary_tunnel_ip") \e[0m${tunnel_ip}"
echo -e "\e[1;36m  $(msg "summary_handshake") \e[0m${handshake_display}"
echo -e "\e[1;36m$(msg "summary_footer")\e[0m"
echo ""

if systemctl is-active --quiet "$UNIT" && awg show "$IFACE" &>/dev/null; then
    printf "\e[2;37m%s\e[0m\r" "..."
    ij=$(fetch_awg https://ifconfig.co/json)
    ip1=$(echo "$ij" | grep -oE '"ip":[ ]*"[^"]*"' | cut -d'"' -f4)
    co1=$(echo "$ij" | grep -oE '"country":[ ]*"[^"]*"' | cut -d'"' -f4)
    ci1=$(echo "$ij" | grep -oE '"city":[ ]*"[^"]*"' | cut -d'"' -f4)
    asn=$(echo "$ij" | grep -oE '"asn_org":[ ]*"[^"]*"' | cut -d'"' -f4)
    aj=$(fetch_awg http://ip-api.com/json)
    co2=$(echo "$aj" | grep -oE '"country":[ ]*"[^"]*"' | cut -d'"' -f4)
    isp=$(echo "$aj" | grep -oE '"isp":[ ]*"[^"]*"' | cut -d'"' -f4)
    cg=$(fetch_awg https://chatgpt.com/cdn-cgi/trace | grep '^loc=' | cut -d= -f2)
    printf "                      \r"

    echo -e "\e[1;36m$(msg "exit_header")\e[0m"
    printf "  \e[1;36mIP          \e[0m %s\n" "${ip1:-—}"
    printf "  \e[1;36mifconfig.co \e[0m %s%s\n" "${co1:-—}" "${ci1:+, $ci1}"
    printf "  \e[1;36mip-api      \e[0m %s\n" "${co2:-—}"
    printf "  \e[1;36mASN         \e[0m %s\n" "${asn:-${isp:-—}}"
    if [[ -n "$cg" ]]; then
        if [[ "$cg" =~ ^(RU|CN|BY|IR|KP|CU|SY|VE)$ ]]; then
            printf "  \e[1;36mChatGPT     \e[0m \e[1;31m%s\e[0m (%s)\n" "$(msg "exit_unavail")" "$cg"
        else
            printf "  \e[1;36mChatGPT     \e[0m \e[1;32m%s\e[0m (%s)\n" "$(msg "exit_avail")" "$cg"
        fi
    else
        printf "  \e[1;36mChatGPT     \e[0m —\n"
    fi
    echo -e "\e[1;36m$(msg "summary_footer")\e[0m"
    echo ""

    if [[ -z "$ip1" && -z "$co2" && -z "$cg" ]]; then
        warn "$(msg "exit_unreachable")"
    fi
fi

echo -e "\e[1;32m➤ awg-native\e[0m — статус туннеля и управление"
echo ""
echo -e "\e[1;36m➤ $(msg "disable_autostart"): \e[0msystemctl disable ${UNIT}"
echo -e "\e[1;36m➤ $(msg "enable_autostart_cmd"): \e[0msystemctl enable ${UNIT}"
echo -e "\e[1;36m➤ $(msg "watchdog_config"): \e[0m${STATE_DIR}/config.env"
echo ""
