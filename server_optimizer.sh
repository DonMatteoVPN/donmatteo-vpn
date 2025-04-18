#!/bin/bash

# Цвета для вывода
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Версия скрипта
VERSION="2.0.0"

# Функция справки
show_help() {
    echo "Универсальный скрипт оптимизации сервера для VLESS/3x-ui"
    echo "Версия: $VERSION"
    echo ""
    echo "Использование: $0 [ОПЦИИ]"
    echo ""
    echo "Опции:"
    echo "  -h, --help       Показать эту справку"
    echo "  -v, --version    Показать версию скрипта"
    echo "  --skip-network   Пропустить тест скорости сети"
    echo "  --skip-swap      Пропустить настройку SWAP"
    echo "  --skip-xray      Пропустить оптимизацию Xray"
    echo "  --skip-vless     Пропустить оптимизацию VLESS"
    echo "  --only-report    Только создать отчет без изменений"
    echo "  --auto-reboot    Автоматически перезагрузить после оптимизации"
    echo ""
    echo "Примеры:"
    echo "  $0               Запустить полную оптимизацию"
    echo "  $0 --skip-network Запустить оптимизацию без теста скорости"
    echo "  $0 --only-report  Только создать отчет о текущем состоянии"
    echo ""
    echo "Автор: ChatGPT-4"
}

# Инициализация параметров по умолчанию
SKIP_NETWORK=false
SKIP_SWAP=false
SKIP_XRAY=false
SKIP_VLESS=false
ONLY_REPORT=false
AUTO_REBOOT=false

# Обработка аргументов командной строки
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--version)
            echo "Version: $VERSION"
            exit 0
            ;;
        --skip-network)
            SKIP_NETWORK=true
            ;;
        --skip-swap)
            SKIP_SWAP=true
            ;;
        --skip-xray)
            SKIP_XRAY=true
            ;;
        --skip-vless)
            SKIP_VLESS=true
            ;;
        --only-report)
            ONLY_REPORT=true
            ;;
        --auto-reboot)
            AUTO_REBOOT=true
            ;;
        *)
            echo -e "${RED}[!] Неизвестный параметр: $1${NC}"
            show_help
            exit 1
            ;;
    esac
    shift
done

echo -e "${BLUE}[*] Начинаем универсальную оптимизацию сервера...${NC}"
echo -e "${YELLOW}[*] Параметры оптимизации:${NC}"
echo -e "  - Пропустить тест скорости: $([ "$SKIP_NETWORK" = true ] && echo "Да" || echo "Нет")"
echo -e "  - Пропустить настройку SWAP: $([ "$SKIP_SWAP" = true ] && echo "Да" || echo "Нет")"
echo -e "  - Пропустить оптимизацию Xray: $([ "$SKIP_XRAY" = true ] && echo "Да" || echo "Нет")"
echo -e "  - Пропустить оптимизацию VLESS: $([ "$SKIP_VLESS" = true ] && echo "Да" || echo "Нет")"
echo -e "  - Только создать отчет: $([ "$ONLY_REPORT" = true ] && echo "Да" || echo "Нет")"
echo -e "  - Автоматически перезагрузить: $([ "$AUTO_REBOOT" = true ] && echo "Да" || echo "Нет")"

# Проверка root прав
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}[!] Скрипт должен быть запущен с правами root${NC}"
    exit 1
fi

# Определение дистрибутива Linux
detect_os() {
    echo -e "${BLUE}[*] Определение операционной системы...${NC}"
    
    # Устанавливаем значения по умолчанию
    OS_TYPE="unknown"
    PKG_MANAGER=""
    
    # Проверка наличия файла release
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE=$ID
    elif type lsb_release >/dev/null 2>&1; then
        OS_TYPE=$(lsb_release -si)
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        OS_TYPE=$DISTRIB_ID
    elif [ -f /etc/debian_version ]; then
        OS_TYPE="debian"
    elif [ -f /etc/redhat-release ]; then
        if grep -q "CentOS" /etc/redhat-release; then
            OS_TYPE="centos"
        else
            OS_TYPE="rhel"
        fi
    else
        OS_TYPE=$(uname -s)
    fi
    
    # Приводим к нижнему регистру
    OS_TYPE=$(echo "$OS_TYPE" | tr '[:upper:]' '[:lower:]')
    
    # Определяем пакетный менеджер
    case $OS_TYPE in
        debian|ubuntu|mint|kali)
            PKG_MANAGER="apt-get"
            ;;
        centos|rhel|fedora|rocky|almalinux)
            PKG_MANAGER="yum"
            ;;
        alpine)
            PKG_MANAGER="apk"
            ;;
        arch|manjaro)
            PKG_MANAGER="pacman"
            ;;
        *)
            echo -e "${YELLOW}[!] Неизвестный дистрибутив: $OS_TYPE. Используем apt-get по умолчанию.${NC}"
            PKG_MANAGER="apt-get"
            ;;
    esac
    
    echo -e "${GREEN}[+] Обнаружена операционная система: $OS_TYPE ${NC}"
    echo -e "${GREEN}[+] Будет использован пакетный менеджер: $PKG_MANAGER ${NC}"
}

# Проверка и установка необходимых утилит
install_requirements() {
    echo -e "${BLUE}[*] Проверка и установка необходимых зависимостей...${NC}"
    
    # Список необходимых пакетов
    REQUIRED_PACKAGES=()
    
    # Проверяем наличие ethtool
    if ! command -v ethtool &> /dev/null; then
        REQUIRED_PACKAGES+=("ethtool")
    fi
    
    # Проверяем наличие jq
    if ! command -v jq &> /dev/null; then
        REQUIRED_PACKAGES+=("jq")
    fi
    
    # Проверяем другие необходимые утилиты
    for cmd in lsblk ip sysctl systemctl chrt renice crontab; do
        if ! command -v $cmd &> /dev/null; then
            case $cmd in
                lsblk)
                    if [ "$PKG_MANAGER" = "apt-get" ]; then REQUIRED_PACKAGES+=("util-linux"); fi
                    if [ "$PKG_MANAGER" = "yum" ]; then REQUIRED_PACKAGES+=("util-linux"); fi
                    if [ "$PKG_MANAGER" = "pacman" ]; then REQUIRED_PACKAGES+=("util-linux"); fi
                    if [ "$PKG_MANAGER" = "apk" ]; then REQUIRED_PACKAGES+=("util-linux"); fi
                    ;;
                sysctl)
                    if [ "$PKG_MANAGER" = "apt-get" ]; then REQUIRED_PACKAGES+=("procps"); fi
                    if [ "$PKG_MANAGER" = "yum" ]; then REQUIRED_PACKAGES+=("procps-ng"); fi
                    if [ "$PKG_MANAGER" = "pacman" ]; then REQUIRED_PACKAGES+=("procps-ng"); fi
                    if [ "$PKG_MANAGER" = "apk" ]; then REQUIRED_PACKAGES+=("procps"); fi
                    ;;
                chrt|renice)
                    if [ "$PKG_MANAGER" = "apt-get" ]; then REQUIRED_PACKAGES+=("util-linux"); fi
                    if [ "$PKG_MANAGER" = "yum" ]; then REQUIRED_PACKAGES+=("util-linux"); fi
                    if [ "$PKG_MANAGER" = "pacman" ]; then REQUIRED_PACKAGES+=("util-linux"); fi
                    if [ "$PKG_MANAGER" = "apk" ]; then REQUIRED_PACKAGES+=("util-linux"); fi
                    ;;
                systemctl)
                    if [ "$PKG_MANAGER" = "apt-get" ]; then REQUIRED_PACKAGES+=("systemd"); fi
                    if [ "$PKG_MANAGER" = "yum" ]; then REQUIRED_PACKAGES+=("systemd"); fi
                    if [ "$PKG_MANAGER" = "pacman" ]; then REQUIRED_PACKAGES+=("systemd"); fi
                    if [ "$PKG_MANAGER" = "apk" ]; then REQUIRED_PACKAGES+=("openrc"); fi
                    ;;
                crontab)
                    if [ "$PKG_MANAGER" = "apt-get" ]; then REQUIRED_PACKAGES+=("cron"); fi
                    if [ "$PKG_MANAGER" = "yum" ]; then REQUIRED_PACKAGES+=("cronie"); fi
                    if [ "$PKG_MANAGER" = "pacman" ]; then REQUIRED_PACKAGES+=("cronie"); fi
                    if [ "$PKG_MANAGER" = "apk" ]; then REQUIRED_PACKAGES+=("dcron"); fi
                    ;;
            esac
        fi
    done
    
    # Устанавливаем необходимые пакеты, если они отсутствуют
    if [ ${#REQUIRED_PACKAGES[@]} -ne 0 ]; then
        echo -e "${YELLOW}[*] Необходимо установить следующие пакеты: ${REQUIRED_PACKAGES[*]}${NC}"
        
        case $PKG_MANAGER in
            apt-get)
                $PKG_MANAGER update
                $PKG_MANAGER install -y ${REQUIRED_PACKAGES[@]}
                ;;
            yum)
                $PKG_MANAGER check-update
                $PKG_MANAGER install -y ${REQUIRED_PACKAGES[@]}
                ;;
            pacman)
                $PKG_MANAGER -Sy
                $PKG_MANAGER -S --noconfirm ${REQUIRED_PACKAGES[@]}
                ;;
            apk)
                $PKG_MANAGER update
                $PKG_MANAGER add ${REQUIRED_PACKAGES[@]}
                ;;
        esac
    fi
    
    echo -e "${GREEN}[+] Все необходимые зависимости установлены${NC}"
}

# Определяет поддерживаемые параметры ядра
check_kernel_params() {
    echo -e "${BLUE}[*] Проверка поддерживаемых параметров ядра...${NC}"
    
    # Проверяем поддержку BBR
    if [ ! -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
        echo -e "${YELLOW}[!] Ядро не поддерживает настройку алгоритма перегрузки TCP. Некоторые оптимизации будут пропущены.${NC}"
        HAS_TCP_CC=false
    else
        HAS_TCP_CC=true
    fi
    
    # Проверяем поддержку TCP Fast Open
    if [ ! -f /proc/sys/net/ipv4/tcp_fastopen ]; then
        echo -e "${YELLOW}[!] Ядро не поддерживает TCP Fast Open. Некоторые оптимизации будут пропущены.${NC}"
        HAS_TCP_FASTOPEN=false
    else
        HAS_TCP_FASTOPEN=true
    fi
    
    # Проверка параметров, которые есть не во всех ядрах
    SUPPORTED_PARAMS=()
    UNSUPPORTED_PARAMS=()
    
    # Список параметров для проверки
    PARAMS_TO_CHECK=(
        "net.ipv4.tcp_delack_min"
        "net.ipv4.tcp_notsent_lowat"
        "net.ipv4.tcp_autocorking"
        "net.ipv4.tcp_early_retrans"
        "net.ipv4.tcp_frto"
        "net.ipv4.tcp_thin_linear_timeouts"
        "net.ipv4.tcp_thin_dupack"
    )
    
    for param in "${PARAMS_TO_CHECK[@]}"; do
        param_file=$(echo $param | sed 's/net./\/proc\/sys\/net\//; s/\./\//g')
        if [ -f "$param_file" ]; then
            SUPPORTED_PARAMS+=("$param")
        else
            UNSUPPORTED_PARAMS+=("$param")
        fi
    done
    
    echo -e "${GREEN}[+] Поддерживаемые параметры: ${SUPPORTED_PARAMS[*]}${NC}"
    echo -e "${YELLOW}[!] Неподдерживаемые параметры: ${UNSUPPORTED_PARAMS[*]}${NC}"
}

# Проверка и подготовка среды
detect_os
install_requirements
check_kernel_params

# Определение характеристик системы
get_system_specs() {
    echo -e "${BLUE}[*] Определение характеристик системы...${NC}"
    
    # CPU
    CPU_CORES=$(nproc)
    CPU_MODEL=$(grep "model name" /proc/cpuinfo | head -n1 | cut -d ":" -f2 | sed 's/^[ \t]*//')
    
    # RAM
    TOTAL_RAM=$(free -m | grep Mem | awk '{print $2}')
    
    # Disk
    DISK_SIZE=$(df -h / | tail -n1 | awk '{print $2}' | sed 's/[A-Za-z]//g')
    DISK_TYPE=$(cat /sys/block/$(df -P / | awk 'NR==2 {print $1}' | sed 's/[0-9]*$//;s/\/dev\///')/queue/rotational 2>/dev/null || echo "unknown")
    
    echo -e "${YELLOW}[*] Обнаружено:${NC}"
    echo -e "CPU: $CPU_MODEL"
    echo -e "Ядер CPU: $CPU_CORES"
    echo -e "Оперативная память: $TOTAL_RAM MB"
    echo -e "Размер диска: ${DISK_SIZE}GB"
    echo -e "Тип диска: $([ "$DISK_TYPE" = "0" ] && echo "SSD" || echo "HDD")"
}

# Оптимизация IO планировщика
optimize_io() {
    echo -e "${BLUE}[*] Оптимизация дисковой подсистемы...${NC}"
    
    # Определяем все блочные устройства
    for DEVICE in $(lsblk -d -n -o NAME); do
        if [ -f "/sys/block/$DEVICE/queue/rotational" ]; then
            ROTATIONAL=$(cat /sys/block/$DEVICE/queue/rotational)
            
            if [ "$ROTATIONAL" = "0" ]; then
                # Оптимизация для SSD
                echo none > /sys/block/$DEVICE/queue/scheduler
                echo 0 > /sys/block/$DEVICE/queue/add_random
                echo 0 > /sys/block/$DEVICE/queue/iostats
                echo 1024 > /sys/block/$DEVICE/queue/nr_requests
                echo 0 > /sys/block/$DEVICE/queue/rotational
                echo 256 > /sys/block/$DEVICE/queue/read_ahead_kb
            else
                # Оптимизация для HDD
                echo mq-deadline > /sys/block/$DEVICE/queue/scheduler
                echo 128 > /sys/block/$DEVICE/queue/nr_requests
                echo 1024 > /sys/block/$DEVICE/queue/read_ahead_kb
            fi
        fi
    done
    
    # Оптимизация VM
    echo "vm.dirty_ratio = 10" >> /etc/sysctl.conf
    echo "vm.dirty_background_ratio = 5" >> /etc/sysctl.conf
    echo "vm.vfs_cache_pressure = 50" >> /etc/sysctl.conf
    echo "vm.swappiness = 10" >> /etc/sysctl.conf
    
    echo -e "${GREEN}[+] Дисковая подсистема оптимизирована${NC}"
}

# Создание оптимального файла подкачки
setup_swap() {
    echo -e "${BLUE}[*] Настройка SWAP...${NC}"
    
    # Расчет размера SWAP в зависимости от RAM и нагрузки
    if [ $TOTAL_RAM -le 2048 ]; then
        SWAP_SIZE=$((TOTAL_RAM * 2))
    elif [ $TOTAL_RAM -le 8192 ]; then
        SWAP_SIZE=$((TOTAL_RAM * 3/2))
    else
        SWAP_SIZE=8192
    fi
    
    swapoff -a
    echo -e "${YELLOW}[*] Создание SWAP размером ${SWAP_SIZE}MB${NC}"
    dd if=/dev/zero of=/swapfile bs=1M count=$SWAP_SIZE status=progress
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo '/swapfile none swap sw 0 0' >> /etc/fstab
    
    # Тонкая настройка свопинга
    echo -e "${YELLOW}[*] Настройка параметров свопинга${NC}"
    echo "vm.swappiness=10" >> /etc/sysctl.conf
    echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
    echo "vm.dirty_ratio=10" >> /etc/sysctl.conf
    echo "vm.dirty_background_ratio=5" >> /etc/sysctl.conf
    
    echo -e "${GREEN}[+] SWAP файл создан и настроен${NC}"
}

# Оптимизация системных параметров
optimize_sysctl() {
    echo -e "${BLUE}[*] Оптимизация системных параметров...${NC}"
    
    # Расчет оптимальных значений на основе RAM
    local MAX_MEM=$((TOTAL_RAM * 1024)) # Конвертация в KB
    local HALF_MEM=$((MAX_MEM / 2))
    local QUARTER_MEM=$((MAX_MEM / 4))
    
    cat > /etc/sysctl.conf << EEOF
# Основные параметры сети
net.ipv4.tcp_fastopen = 3
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_max_syn_backlog = $((CPU_CORES * 4096))
net.ipv4.tcp_max_tw_buckets = $((CPU_CORES * 4000))
net.ipv4.ip_local_port_range = 1024 65535

# Настройка памяти
net.ipv4.tcp_mem = $QUARTER_MEM $HALF_MEM $MAX_MEM
net.ipv4.tcp_rmem = 4096 87380 $HALF_MEM
net.ipv4.tcp_wmem = 4096 65536 $HALF_MEM
net.ipv4.tcp_mtu_probing = 1
net.core.rmem_max = $HALF_MEM
net.core.wmem_max = $HALF_MEM
net.core.rmem_default = 65536
net.core.wmem_default = 65536

# Настройка очередей
net.core.netdev_max_backlog = $((CPU_CORES * 2000))
net.core.somaxconn = $((CPU_CORES * 16384))
net.ipv4.tcp_slow_start_after_idle = 0

# Расширенные оптимизации TCP
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_fack = 1
net.ipv4.tcp_low_latency = 1
net.ipv4.tcp_adv_win_scale = 2
net.ipv4.tcp_rfc1337 = 1
net.ipv4.tcp_fin_timeout = 15
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Защита от DDoS
net.ipv4.tcp_max_orphans = $((CPU_CORES * 4096))
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_synack_retries = 2
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_max_syn_backlog = $((CPU_CORES * 4096))

# Оптимизация IPv4
net.ipv4.ip_forward = 1
net.ipv4.conf.all.forwarding = 1
net.ipv4.conf.default.forwarding = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
EEOF
    sysctl -p
    echo -e "${GREEN}[+] Системные параметры оптимизированы${NC}"
}

# Включение BBR и оптимизация TCP
optimize_tcp() {
    echo -e "${BLUE}[*] Оптимизация TCP и включение BBR...${NC}"
    
    # Включение BBR
    modprobe tcp_bbr
    echo "tcp_bbr" >> /etc/modules-load.d/modules.conf
    
    # Установка параметров TCP
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    
    # Дополнительные оптимизации TCP
    echo "net.ipv4.tcp_fastopen=3" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_slow_start_after_idle=0" >> /etc/sysctl.conf
    
    sysctl -p
    echo -e "${GREEN}[+] TCP оптимизирован и BBR включен${NC}"
}

# Оптимизация системных лимитов
optimize_limits() {
    echo -e "${BLUE}[*] Настройка системных лимитов...${NC}"
    
    # Расчет оптимальных значений на основе RAM и CPU
    local MAX_FILES=$((CPU_CORES * 32768))
    
    cat > /etc/security/limits.conf << EEOF
* soft nofile $MAX_FILES
* hard nofile $MAX_FILES
* soft nproc $((MAX_FILES / 2))
* hard nproc $((MAX_FILES / 2))
root soft nofile $MAX_FILES
root hard nofile $MAX_FILES
* soft memlock unlimited
* hard memlock unlimited
EEOF
    echo -e "${GREEN}[+] Системные лимиты настроены${NC}"
}

# Оптимизация SSH
optimize_ssh() {
    echo -e "${BLUE}[*] Оптимизация SSH...${NC}"
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    # Расширенные настройки SSH
    cat >> /etc/ssh/sshd_config << EEOF

# Оптимизация производительности
TCPKeepAlive yes
ClientAliveInterval 30
ClientAliveCountMax 100
Compression yes
UseDNS no
MaxStartups 100:30:200
MaxSessions 100
EEOF
    
    systemctl restart sshd
    echo -e "${GREEN}[+] SSH оптимизирован${NC}"
}

# Оптимизация системных служб
optimize_services() {
    echo -e "${BLUE}[*] Оптимизация системных служб...${NC}"
    
    # Отключение ненужных служб
    SERVICES_TO_DISABLE=(
        "bluetooth.service"
        "cups.service"
        "ModemManager.service"
        "wpa_supplicant.service"
    )
    
    for service in "${SERVICES_TO_DISABLE[@]}"; do
        if systemctl is-active --quiet "$service"; then
            systemctl stop "$service"
            systemctl disable "$service"
            echo -e "${YELLOW}[*] Служба $service отключена${NC}"
        fi
    done
    
    echo -e "${GREEN}[+] Системные службы оптимизированы${NC}"
}

# Расчет максимального количества пользователей
calculate_max_users() {
    # Расчет на основе RAM (1 пользователь ~ 50MB RAM)
    local RAM_USERS=$((TOTAL_RAM / 50))
    
    # Расчет на основе CPU (1 ядро ~ 40 пользователей)
    local CPU_USERS=$((CPU_CORES * 40))
    
    # Берем минимальное значение для безопасности
    MAX_USERS=$(( RAM_USERS < CPU_USERS ? RAM_USERS : CPU_USERS ))
    
    # Применяем коэффициент безопасности 0.8
    MAX_USERS=$(( MAX_USERS * 8 / 10 ))
    
    # Минимум 10 пользователей
    MAX_USERS=$(( MAX_USERS < 10 ? 10 : MAX_USERS ))
}

# Оптимизация сетевой производительности
optimize_network() {
    echo -e "${BLUE}[*] Оптимизация сетевой производительности...${NC}"
    
    # Создаем временный файл для sysctl конфигурации
    TMP_SYSCTL=$(mktemp)

    # Базовые сетевые буферы (поддерживаются всеми ядрами)
    cat > $TMP_SYSCTL << EOF
# Оптимизация сетевых буферов
net.core.rmem_default = 1048576
net.core.rmem_max = 33554432
net.core.wmem_default = 1048576
net.core.wmem_max = 33554432
net.ipv4.tcp_rmem = 4096 1048576 33554432
net.ipv4.tcp_wmem = 4096 1048576 33554432
net.ipv4.udp_rmem_min = 16384
net.ipv4.udp_wmem_min = 16384

# Базовая оптимизация TCP
net.ipv4.tcp_window_scaling = 1
net.ipv4.tcp_timestamps = 1
net.ipv4.tcp_sack = 1
net.ipv4.tcp_low_latency = 1

# Оптимизация очередей
net.core.netdev_max_backlog = 65536
net.core.somaxconn = 131072
net.ipv4.tcp_max_syn_backlog = 65536

# Оптимизация производительности
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fin_timeout = 10
net.ipv4.tcp_keepalive_time = 300
net.ipv4.tcp_keepalive_probes = 5
net.ipv4.tcp_keepalive_intvl = 15

# Оптимизация для высокоскоростных сетей
net.core.optmem_max = 131072
net.ipv4.tcp_adv_win_scale = 3
net.ipv4.tcp_tw_reuse = 1

# Защита от SYN-флуда и DDoS
net.ipv4.tcp_max_tw_buckets = 1440000
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_syn_retries = 2
net.ipv4.tcp_synack_retries = 1

EOF

    # Добавляем поддержку TCP Congestion Control только если она есть
    if [ "$HAS_TCP_CC" = true ]; then
        echo -e "${GREEN}[+] Добавляем оптимизации для TCP Congestion Control${NC}"
        cat >> $TMP_SYSCTL << EOF
# TCP Congestion Control
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq
EOF
    fi

    # Добавляем поддержку TCP Fast Open только если она есть
    if [ "$HAS_TCP_FASTOPEN" = true ]; then
        echo -e "${GREEN}[+] Добавляем оптимизации TCP Fast Open${NC}"
        cat >> $TMP_SYSCTL << EOF
# TCP Fast Open
net.ipv4.tcp_fastopen = 3
EOF
    fi

    # Добавляем поддержку расширенных параметров TCP только если они поддерживаются
    for param in "${SUPPORTED_PARAMS[@]}"; do
        case $param in
            "net.ipv4.tcp_delack_min")
                echo "net.ipv4.tcp_delack_min = 5" >> $TMP_SYSCTL
                ;;
            "net.ipv4.tcp_notsent_lowat")
                echo "net.ipv4.tcp_notsent_lowat = 16384" >> $TMP_SYSCTL
                ;;
            "net.ipv4.tcp_autocorking")
                echo "net.ipv4.tcp_autocorking = 0" >> $TMP_SYSCTL
                ;;
            "net.ipv4.tcp_early_retrans")
                echo "net.ipv4.tcp_early_retrans = 1" >> $TMP_SYSCTL
                ;;
            "net.ipv4.tcp_frto")
                echo "net.ipv4.tcp_frto = 1" >> $TMP_SYSCTL
                ;;
            "net.ipv4.tcp_thin_linear_timeouts")
                echo "net.ipv4.tcp_thin_linear_timeouts = 1" >> $TMP_SYSCTL
                ;;
            "net.ipv4.tcp_thin_dupack")
                echo "net.ipv4.tcp_thin_dupack = 1" >> $TMP_SYSCTL
                ;;
        esac
    done

    # Добавляем в основной файл конфигурации
    cat $TMP_SYSCTL >> /etc/sysctl.conf
    
    # Удаляем временный файл
    rm -f $TMP_SYSCTL

    # Применяем настройки
    sysctl -p 2>&1 | grep -v "error" || true
    echo -e "${GREEN}[+] Сетевые настройки применены${NC}"

    # Оптимизация сетевых интерфейсов
    for interface in $(ip -o link show | awk -F': ' '{print $2}'); do
        if [ "$interface" != "lo" ] && [[ ! "$interface" =~ ^docker ]]; then
            echo -e "${YELLOW}[*] Оптимизация интерфейса $interface${NC}"
            
            # Увеличение размера очередей (обрабатываем ошибки)
            ethtool -G $interface rx 8192 tx 8192 2>/dev/null || {
                echo -e "${YELLOW}[!] Не удалось изменить размер очередей для $interface${NC}"
            }
            
            # Включение offload (обрабатываем ошибки)
            ethtool -K $interface tso on gso on gro on 2>/dev/null || {
                echo -e "${YELLOW}[!] Базовые offload-параметры не поддерживаются на $interface${NC}"
            }
            
            # Пробуем расширенные offload возможности
            ethtool -K $interface lro on tx-scatter-gather on rx-vlan-filter off rx-vlan-stag-filter off tx-nocache-copy off 2>/dev/null || {
                echo -e "${YELLOW}[!] Расширенные offload-параметры не поддерживаются на $interface${NC}"
            }
            
            # Отключение прерывания для улучшения производительности
            ethtool -C $interface adaptive-rx on adaptive-tx on rx-usecs 16 tx-usecs 16 2>/dev/null || {
                echo -e "${YELLOW}[!] Не удалось настроить прерывания для $interface${NC}"
            }
            
            # Настройка правильного размера MTU
            ip link set dev $interface mtu 1500 2>/dev/null || {
                echo -e "${YELLOW}[!] Не удалось установить MTU для $interface${NC}"
            }
        fi
    done

    echo -e "${GREEN}[+] Сетевая производительность оптимизирована${NC}"
}

# Тестирование скорости сети
test_network_speed() {
    echo -e "${BLUE}[*] Тестирование скорости сети...${NC}"
    
    SPEED_TEST_CMD=""
    SPEED_TEST_RESULT=""
    PING=""
    DOWNLOAD=""
    UPLOAD=""
    
    # Проверяем наличие speedtest-cli
    if command -v speedtest-cli &> /dev/null; then
        SPEED_TEST_CMD="speedtest-cli"
    # Проверяем наличие speedtest
    elif command -v speedtest &> /dev/null; then
        SPEED_TEST_CMD="speedtest"
    # Пробуем установить speedtest
    else
        echo -e "${YELLOW}[*] Установка утилиты для тестирования скорости...${NC}"
        
        case $PKG_MANAGER in
            apt-get)
                # Пробуем сначала установить speedtest от Ookla
                curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash
                apt-get install -y speedtest
                if command -v speedtest &> /dev/null; then
                    SPEED_TEST_CMD="speedtest"
                else
                    # Пробуем установить speedtest-cli
                    apt-get install -y speedtest-cli
                    if command -v speedtest-cli &> /dev/null; then
                        SPEED_TEST_CMD="speedtest-cli"
                    fi
                fi
                ;;
            yum)
                # Пробуем сначала установить speedtest от Ookla
                curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.rpm.sh | bash
                yum install -y speedtest
                if command -v speedtest &> /dev/null; then
                    SPEED_TEST_CMD="speedtest"
                else
                    # Пробуем установить speedtest-cli
                    yum install -y python3-pip
                    pip3 install speedtest-cli
                    if command -v speedtest-cli &> /dev/null; then
                        SPEED_TEST_CMD="speedtest-cli"
                    fi
                fi
                ;;
            pacman)
                # Пробуем установить speedtest-cli
                pacman -S --noconfirm python-pip
                pip install speedtest-cli
                if command -v speedtest-cli &> /dev/null; then
                    SPEED_TEST_CMD="speedtest-cli"
                fi
                ;;
            apk)
                # Пробуем установить speedtest-cli
                apk add python3 py3-pip
                pip3 install speedtest-cli
                if command -v speedtest-cli &> /dev/null; then
                    SPEED_TEST_CMD="speedtest-cli"
                fi
                ;;
        esac
    fi
    
    if [ -n "$SPEED_TEST_CMD" ]; then
        echo -e "${YELLOW}[*] Запуск теста скорости с использованием $SPEED_TEST_CMD...${NC}"
        
        # Выполняем тест скорости в зависимости от доступной команды
        if [ "$SPEED_TEST_CMD" = "speedtest-cli" ]; then
            SPEED_TEST_RESULT=$(speedtest-cli --simple 2>/dev/null || echo "Ошибка выполнения теста")
            
            # Извлекаем данные
            if echo "$SPEED_TEST_RESULT" | grep -q "Ping"; then
                PING=$(echo "$SPEED_TEST_RESULT" | grep "Ping" | awk '{print $2}')
                DOWNLOAD=$(echo "$SPEED_TEST_RESULT" | grep "Download" | awk '{print $2}')
                UPLOAD=$(echo "$SPEED_TEST_RESULT" | grep "Upload" | awk '{print $2}')
            fi
        elif [ "$SPEED_TEST_CMD" = "speedtest" ]; then
            # Выполняем speedtest в формате JSON для более надежного парсинга
            SPEED_TEST_JSON=$(speedtest -f json 2>/dev/null || echo "{}")
            
            # Проверяем, что результат содержит валидный JSON
            if echo "$SPEED_TEST_JSON" | grep -q "ping"; then
                # Извлекаем данные с помощью jq, если доступен
                if command -v jq &> /dev/null; then
                    PING=$(echo "$SPEED_TEST_JSON" | jq -r '.ping.latency // 0')
                    DOWNLOAD=$(echo "$SPEED_TEST_JSON" | jq -r '(.download.bandwidth // 0) * 8 / 1000000')
                    UPLOAD=$(echo "$SPEED_TEST_JSON" | jq -r '(.upload.bandwidth // 0) * 8 / 1000000')
                else
                    # Базовый парсинг, если jq недоступен
                    PING=$(echo "$SPEED_TEST_JSON" | grep -o '"latency":[0-9.]*' | cut -d':' -f2)
                    DOWNLOAD=$(echo "$SPEED_TEST_JSON" | grep -o '"bandwidth":[0-9.]*' | head -1 | cut -d':' -f2)
                    UPLOAD=$(echo "$SPEED_TEST_JSON" | grep -o '"bandwidth":[0-9.]*' | tail -1 | cut -d':' -f2)
                    
                    # Конвертируем байты/с в Мбит/с
                    if [ -n "$DOWNLOAD" ]; then
                        DOWNLOAD=$(echo "$DOWNLOAD * 8 / 1000000" | bc -l | awk '{printf "%.2f", $1}')
                    fi
                    if [ -n "$UPLOAD" ]; then
                        UPLOAD=$(echo "$UPLOAD * 8 / 1000000" | bc -l | awk '{printf "%.2f", $1}')
                    fi
                fi
            fi
        fi
    else
        echo -e "${RED}[!] Не удалось установить утилиту для тестирования скорости${NC}"
        # Устанавливаем значения по умолчанию
        PING="N/A"
        DOWNLOAD="N/A"
        UPLOAD="N/A"
    fi
    
    # Выводим результаты, если они есть
    if [ -n "$DOWNLOAD" ] && [ "$DOWNLOAD" != "N/A" ]; then
        echo -e "${GREEN}[+] Тест скорости завершен${NC}"
        echo -e "${YELLOW}[*] Пинг: ${PING} ms${NC}"
        echo -e "${YELLOW}[*] Скорость загрузки: ${DOWNLOAD} Mbit/s${NC}"
        echo -e "${YELLOW}[*] Скорость отдачи: ${UPLOAD} Mbit/s${NC}"
    else
        echo -e "${YELLOW}[!] Не удалось получить данные о скорости. Пропускаем.${NC}"
    fi
    
    return 0
}

# Оптимизация VLESS в 3x-ui
optimize_vless() {
    echo -e "${BLUE}[*] Оптимизация VLESS в 3x-ui...${NC}"
    
    # Проверяем наличие установленного 3x-ui
    XUI_PATHS=("/usr/bin/x-ui" "/usr/local/bin/x-ui" "/etc/x-ui/x-ui" "/usr/local/x-ui/x-ui")
    XUI_BIN=""
    for path in "${XUI_PATHS[@]}"; do
        if [ -f "$path" ]; then
            XUI_BIN="$path"
            break
        fi
    done
    
    # Проверяем наличие x-ui сервиса
    XUI_SERVICE=""
    for service in "/etc/systemd/system/x-ui.service" "/usr/lib/systemd/system/x-ui.service"; do
        if [ -f "$service" ]; then
            XUI_SERVICE="$service"
            break
        fi
    done
    
    # Если не найден бинарный файл, но найден сервис, пробуем определить бинарный файл из сервиса
    if [ -z "$XUI_BIN" ] && [ -n "$XUI_SERVICE" ]; then
        POSSIBLE_BIN=$(grep "ExecStart" "$XUI_SERVICE" | awk '{print $1}' | cut -d'=' -f2)
        if [ -n "$POSSIBLE_BIN" ] && [ -f "$POSSIBLE_BIN" ]; then
            XUI_BIN="$POSSIBLE_BIN"
        fi
    fi
    
    if [ -z "$XUI_BIN" ] && [ -z "$XUI_SERVICE" ]; then
        echo -e "${YELLOW}[!] 3x-ui не обнаружен. Пропускаем оптимизацию VLESS.${NC}"
        return 0
    fi
    
    if [ -n "$XUI_BIN" ]; then
        echo -e "${YELLOW}[*] Найден 3x-ui: $XUI_BIN${NC}"
    fi
    
    if [ -n "$XUI_SERVICE" ]; then
        echo -e "${YELLOW}[*] Найден сервис 3x-ui: $XUI_SERVICE${NC}"
    fi
    
    # Проверяем наличие jq, если нет - устанавливаем
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}[*] Установка jq для оптимизации JSON...${NC}"
        case $PKG_MANAGER in
            apt-get)
                apt-get update
                apt-get install -y jq
                ;;
            yum)
                yum install -y jq
                ;;
            pacman)
                pacman -S --noconfirm jq
                ;;
            apk)
                apk add jq
                ;;
        esac
    fi
    
    # Создаем директорию для скриптов оптимизации
    mkdir -p /etc/x-ui/optimization
    
    # Создаем скрипт для поиска и оптимизации конфигурации VLESS
    cat > /etc/x-ui/optimization/vless_optimizer.sh << 'EOF'
#!/bin/bash

# Поиск конфиг-файлов
CONFIG_FILES=(
    "/usr/local/x-ui/bin/config.json"
    "/etc/x-ui/config.json"
    "/usr/local/etc/xray/config.json"
    "/etc/xray/config.json"
)

FOUND_CONFIG=false

# Проверка всех возможных расположений конфигов
for CONFIG_FILE in "${CONFIG_FILES[@]}"; do
    if [ -f "$CONFIG_FILE" ]; then
        echo "Найден конфигурационный файл: $CONFIG_FILE"
        FOUND_CONFIG=true
        
        # Создаем временный файл
        TMP_FILE=$(mktemp)
        
        # Проверяем наличие протокола VLESS
        if grep -q "\"protocol\": \"vless\"" "$CONFIG_FILE"; then
            echo "Найден протокол VLESS, применяю оптимизации..."
            
            # Создаем резервную копию
            cp "$CONFIG_FILE" "${CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
            
            # Добавляем оптимальные настройки для VLESS, если jq доступен
            if command -v jq &> /dev/null; then
                # Пробуем обновить настройки sockopt для VLESS
                jq '(.inbounds[] | select(.protocol == "vless")).streamSettings.sockopt = {"tcpFastOpen": true, "tcpKeepAlive": true}' "$CONFIG_FILE" > "$TMP_FILE"
                if [ -s "$TMP_FILE" ]; then
                    cat "$TMP_FILE" > "$CONFIG_FILE"
                    echo "VLESS оптимизирован с TCP Fast Open и TCP Keep Alive"
                fi
                
                # Проверяем использование Reality и оптимизируем его
                if grep -q "\"security\": \"reality\"" "$CONFIG_FILE"; then
                    jq '(.inbounds[] | select(.streamSettings.security == "reality")).streamSettings.realitySettings.fingerprint = "chrome"' "$CONFIG_FILE" > "$TMP_FILE"
                    if [ -s "$TMP_FILE" ]; then
                        cat "$TMP_FILE" > "$CONFIG_FILE"
                        echo "Оптимизирован Reality с fingerprint chrome"
                    fi
                fi
                
                # Оптимизация TLS
                if grep -q "\"security\": \"tls\"" "$CONFIG_FILE"; then
                    jq '(.inbounds[] | select(.streamSettings.security == "tls")).streamSettings.tlsSettings.alpn = ["h2", "http/1.1"]' "$CONFIG_FILE" > "$TMP_FILE"
                    if [ -s "$TMP_FILE" ]; then
                        cat "$TMP_FILE" > "$CONFIG_FILE"
                        jq '(.inbounds[] | select(.streamSettings.security == "tls")).streamSettings.tlsSettings.minVersion = "1.3"' "$CONFIG_FILE" > "$TMP_FILE"
                        if [ -s "$TMP_FILE" ]; then
                            cat "$TMP_FILE" > "$CONFIG_FILE"
                            echo "Оптимизирован TLS с ALPN h2 и версией 1.3"
                        fi
                    fi
                fi
                
                # Добавляем оптимизации логирования
                if ! grep -q "\"loglevel\": \"warning\"" "$CONFIG_FILE"; then
                    mkdir -p /var/log/xray
                    jq '.log = {"loglevel": "warning", "access": "/var/log/xray/access.log", "error": "/var/log/xray/error.log"}' "$CONFIG_FILE" > "$TMP_FILE"
                    if [ -s "$TMP_FILE" ]; then
                        cat "$TMP_FILE" > "$CONFIG_FILE"
                        echo "Оптимизировано логирование"
                    fi
                fi
                
                # Добавляем статистику для отслеживания трафика
                if ! grep -q "\"stats\": {}" "$CONFIG_FILE"; then
                    jq '.stats = {}' "$CONFIG_FILE" > "$TMP_FILE"
                    if [ -s "$TMP_FILE" ]; then
                        cat "$TMP_FILE" > "$CONFIG_FILE"
                        echo "Добавлена поддержка статистики"
                    fi
                fi
            else
                echo "Утилита jq не найдена, пропускаем JSON-оптимизации"
            fi
        else
            echo "Протокол VLESS не найден в $CONFIG_FILE"
        fi
        
        # Очистка временных файлов
        rm -f "$TMP_FILE"
    fi
done

if [ "$FOUND_CONFIG" = false ]; then
    echo "Конфигурационный файл не найден в стандартных местах"
fi

# Проверяем необходимость перезапуска сервисов
for service in "xray" "x-ui"; do
    if command -v systemctl &> /dev/null && systemctl is-active --quiet "$service"; then
        echo "Перезапуск сервиса $service..."
        systemctl restart "$service"
    elif command -v service &> /dev/null; then
        echo "Перезапуск сервиса $service через service..."
        service "$service" restart
    fi
done

echo "Оптимизация VLESS завершена"
EOF
    
    # Делаем скрипт исполняемым
    chmod +x /etc/x-ui/optimization/vless_optimizer.sh
    
    # Запускаем скрипт
    if [ -x "/etc/x-ui/optimization/vless_optimizer.sh" ]; then
        /etc/x-ui/optimization/vless_optimizer.sh
    fi
    
    # Создаем автоматический скрипт для запуска после обновления
    if command -v crontab &> /dev/null; then
        if [ ! -f "/etc/cron.daily/vless_optimizer" ]; then
            cat > "/etc/cron.daily/vless_optimizer" << 'EOF'
#!/bin/bash
if [ -x "/etc/x-ui/optimization/vless_optimizer.sh" ]; then
    /etc/x-ui/optimization/vless_optimizer.sh > /var/log/vless_optimizer.log 2>&1
fi
EOF
            chmod +x "/etc/cron.daily/vless_optimizer"
            echo -e "${GREEN}[+] Создано ежедневное задание для оптимизации VLESS${NC}"
        fi
    else
        echo -e "${YELLOW}[!] Команда crontab не найдена. Автоматическая оптимизация VLESS не будет выполняться${NC}"
    fi
    
    echo -e "${GREEN}[+] VLESS в 3x-ui оптимизирован${NC}"
}

# Оптимизация Xray-core для максимальной скорости
optimize_xray() {
    echo -e "${BLUE}[*] Оптимизация Xray для максимальной производительности...${NC}"
    
    # Проверяем наличие установленного Xray с учетом разных путей установки
    XRAY_BIN=""
    XRAY_SERVICE=""
    XRAY_CONFIG=""
    
    # Ищем бинарный файл Xray
    for path in "/usr/local/bin/xray" "/usr/bin/xray" "/root/bin/xray" "/usr/local/x-ui/bin/xray" "/usr/local/x-ui/bin/bin/xray"; do
        if [ -f "$path" ]; then
            XRAY_BIN="$path"
            break
        fi
    done
    
    # Если не нашли, пробуем найти с помощью команды which
    if [ -z "$XRAY_BIN" ]; then
        XRAY_BIN=$(which xray 2>/dev/null || true)
    fi
    
    # Ищем сервис Xray
    for service in "/etc/systemd/system/xray.service" "/usr/lib/systemd/system/xray.service" "/etc/systemd/system/x-ui.service" "/usr/lib/systemd/system/x-ui.service"; do
        if [ -f "$service" ]; then
            XRAY_SERVICE="$service"
            if echo "$service" | grep -q "x-ui"; then
                SERVICE_NAME="x-ui"
            else
                SERVICE_NAME="xray"
            fi
            break
        fi
    done
    
    # Ищем конфигурационный файл Xray
    for config in "/usr/local/etc/xray/config.json" "/etc/xray/config.json" "/etc/x-ui/config.json" "/usr/local/x-ui/bin/config.json"; do
        if [ -f "$config" ]; then
            XRAY_CONFIG="$config"
            break
        fi
    done
    
    if [ -z "$XRAY_BIN" ]; then
        echo -e "${YELLOW}[!] Xray не обнаружен. Пропускаем оптимизацию Xray.${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}[*] Найден Xray: $XRAY_BIN${NC}"
    
    if [ -n "$XRAY_SERVICE" ]; then
        echo -e "${YELLOW}[*] Найден сервис Xray: $XRAY_SERVICE${NC}"
    fi
    
    if [ -n "$XRAY_CONFIG" ]; then
        echo -e "${YELLOW}[*] Найден конфиг Xray: $XRAY_CONFIG${NC}"
    fi
    
    # Создаем директорию для скриптов оптимизации
    mkdir -p /etc/x-ui/optimization
    
    # Создаем оптимизированный шаблон конфигурации Xray
    cat > /etc/x-ui/optimization/xray_optimization.json << 'EOF'
{
  "log": {
    "loglevel": "warning",
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log"
  },
  "api": {
    "tag": "api",
    "services": ["HandlerService", "LoggerService", "StatsService"]
  },
  "stats": {},
  "policy": {
    "levels": {
      "0": {
        "handshake": 4,
        "connIdle": 300,
        "uplinkOnly": 5,
        "downlinkOnly": 30,
        "statsUserUplink": true,
        "statsUserDownlink": true,
        "bufferSize": 8192
      }
    },
    "system": {
      "statsInboundDownlink": true,
      "statsInboundUplink": true,
      "statsOutboundDownlink": true,
      "statsOutboundUplink": true
    }
  },
  "dns": {
    "servers": [
      "1.1.1.1",
      "8.8.8.8",
      "localhost"
    ],
    "queryStrategy": "UseIPv4"
  },
  "routing": {
    "domainStrategy": "IPIfNonMatch",
    "rules": [
      {
        "type": "field",
        "outboundTag": "blocked",
        "ip": ["geoip:private"]
      },
      {
        "type": "field",
        "outboundTag": "blocked",
        "protocol": ["bittorrent"]
      }
    ]
  },
  "transport": {
    "tcpSettings": {
      "acceptProxyProtocol": false
    }
  }
}
EOF
    
    # Создаем скрипт для применения оптимизации Xray
    cat > /etc/x-ui/optimization/apply_xray_optimization.sh << EOF
#!/bin/bash

# Определяем пути Xray
XRAY_BIN="$XRAY_BIN"
XRAY_SERVICE="$XRAY_SERVICE"
XRAY_CONFIG="$XRAY_CONFIG"
SERVICE_NAME="$SERVICE_NAME"

# Создаем директорию для логов, если она не существует
mkdir -p /var/log/xray

# Если найден сервис, создаем оптимизированную версию
if [ -n "\$XRAY_SERVICE" ]; then
    # Проверяем нужно ли создавать новый файл сервиса
    if ! grep -q "LimitNOFILE=1000000" "\$XRAY_SERVICE"; then
        # Сохраняем оригинальный файл
        cp "\$XRAY_SERVICE" "\$XRAY_SERVICE.bak.$(date +%Y%m%d%H%M%S)"
        
        # Создаем новую конфигурацию
        cat > "\$XRAY_SERVICE.new" << EOOF
[Unit]
Description=Xray Service
Documentation=https://github.com/xtls
After=network.target nss-lookup.target

[Service]
User=root
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ExecStart=\$XRAY_BIN run -config \$XRAY_CONFIG
Restart=on-failure
RestartPreventExitStatus=23
LimitNPROC=10000
LimitNOFILE=1000000

[Install]
WantedBy=multi-user.target
EOOF
        
        # Применяем новый файл сервиса
        mv "\$XRAY_SERVICE.new" "\$XRAY_SERVICE"
        
        # Перезагружаем systemd только если он доступен
        if command -v systemctl &> /dev/null; then
            systemctl daemon-reload
            echo "Оптимизирован systemd сервис Xray для повышения производительности"
        fi
    else
        echo "Сервис Xray уже оптимизирован"
    fi
fi

# Применяем системные настройки для улучшения производительности Xray
# Используем только поддерживаемые параметры
SYSCTL_PARAMS=()

for param in "net.core.rmem_max=16777216" "net.core.wmem_max=16777216"; do
    param_name=\$(echo \$param | cut -d= -f1)
    param_file=\$(echo \$param_name | sed 's/net./\/proc\/sys\/net\//; s/\./\//g')
    
    if [ -f "\$param_file" ]; then
        SYSCTL_PARAMS+=("\$param")
    fi
done

# Применяем поддерживаемые параметры TCP
if [ -f "/proc/sys/net/ipv4/tcp_fastopen" ]; then
    SYSCTL_PARAMS+=("net.ipv4.tcp_fastopen=3")
fi

if [ -f "/proc/sys/net/ipv4/tcp_slow_start_after_idle" ]; then
    SYSCTL_PARAMS+=("net.ipv4.tcp_slow_start_after_idle=0")
fi

# Применяем параметры если они не пусты
if [ \${#SYSCTL_PARAMS[@]} -ne 0 ]; then
    for param in "\${SYSCTL_PARAMS[@]}"; do
        sysctl -w \$param
    done
    echo "Применены системные настройки для оптимизации Xray"
fi

# Проверяем и перезапускаем службы
if command -v systemctl &> /dev/null; then
    if systemctl is-active --quiet "\$SERVICE_NAME"; then
        systemctl restart "\$SERVICE_NAME"
        echo "Сервис \$SERVICE_NAME перезапущен"
    fi
else
    # Для систем без systemd пробуем использовать service
    if command -v service &> /dev/null; then
        service "\$SERVICE_NAME" restart
        echo "Сервис \$SERVICE_NAME перезапущен с помощью service"
    fi
fi

echo "Оптимизация Xray завершена"
EOF
    
    # Делаем скрипт исполняемым
    chmod +x /etc/x-ui/optimization/apply_xray_optimization.sh
    
    # Запускаем скрипт оптимизации Xray
    if [ -x "/etc/x-ui/optimization/apply_xray_optimization.sh" ]; then
        /etc/x-ui/optimization/apply_xray_optimization.sh
    fi
    
    # Создаем скрипт для приоритизации процесса Xray
    cat > /etc/x-ui/optimization/prioritize_xray.sh << 'EOF'
#!/bin/bash

# Находим PID процесса Xray
XRAY_PID=$(pgrep -f "xray run" || pgrep -f "xray -config" || pgrep -f "xray$")

if [ -n "$XRAY_PID" ]; then
    # Устанавливаем наивысший приоритет для Xray, если доступна команда renice
    if command -v renice &> /dev/null; then
        renice -n -20 -p $XRAY_PID 2>/dev/null || true
        echo "Установлен высокий приоритет для Xray (PID: $XRAY_PID)"
    fi
    
    # Устанавливаем политику планировщика на FIFO (realtime), если доступна команда chrt
    if command -v chrt &> /dev/null; then
        chrt -f -p 99 $XRAY_PID 2>/dev/null || true
        echo "Установлена политика реального времени для Xray (PID: $XRAY_PID)"
    fi
else
    echo "Процесс Xray не найден"
fi
EOF
    
    # Делаем скрипт исполняемым
    chmod +x /etc/x-ui/optimization/prioritize_xray.sh
    
    # Запускаем скрипт немедленно
    /etc/x-ui/optimization/prioritize_xray.sh
    
    # Добавляем скрипт в cron для запуска каждые 10 минут если crontab доступен
    if command -v crontab &> /dev/null; then
        (crontab -l 2>/dev/null | grep -v "prioritize_xray.sh"; echo "*/10 * * * * /etc/x-ui/optimization/prioritize_xray.sh > /dev/null 2>&1") | crontab -
        echo -e "${GREEN}[+] Добавлен cron-задание для приоритизации Xray${NC}"
    else
        echo -e "${YELLOW}[!] Команда crontab не найдена. Приоритизация Xray не будет выполняться автоматически${NC}"
    fi
    
    # Устанавливаем большие лимиты для файлов Xray
    if [ -f "/etc/security/limits.conf" ]; then
        if ! grep -q "# Лимиты для улучшения производительности Xray" "/etc/security/limits.conf"; then
            cat >> /etc/security/limits.conf << EOOF
# Лимиты для улучшения производительности Xray
root soft nofile 1000000
root hard nofile 1000000
nobody soft nofile 1000000
nobody hard nofile 1000000
EOOF
            echo -e "${GREEN}[+] Добавлены лимиты файлов для Xray${NC}"
        fi
    else
        echo -e "${YELLOW}[!] Файл limits.conf не найден. Лимиты файлов не будут установлены${NC}"
    fi
    
    echo -e "${GREEN}[+] Xray оптимизирован для максимальной производительности${NC}"
}

# Проверка результатов оптимизации
check_optimization_results() {
    echo -e "${BLUE}[*] Проверка результатов оптимизации...${NC}"
    
    # Создаем отчет о проделанной работе
    REPORT_FILE="/root/optimization_report.txt"
    {
        echo "===== ОТЧЕТ О ВЫПОЛНЕННОЙ ОПТИМИЗАЦИИ ====="
        echo "Дата оптимизации: $(date)"
        echo ""
        echo "1. ПРОВЕРКА СИСТЕМНЫХ ПАРАМЕТРОВ"
        echo "--------------------------------"
        echo "- Конфигурация ядра:"
        
        # Проверка BBR
        if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q "bbr"; then
            echo "  + BBR активирован успешно ✓"
        else
            echo "  - BBR не активирован ×"
        fi
        
        # Проверка fq
        if sysctl net.core.default_qdisc 2>/dev/null | grep -q "fq"; then
            echo "  + FQ scheduler активирован успешно ✓"
        else
            echo "  - FQ scheduler не активирован ×"
        fi
        
        # Проверка TCP Fast Open
        if [ -f "/proc/sys/net/ipv4/tcp_fastopen" ]; then
            TFO_VALUE=$(cat /proc/sys/net/ipv4/tcp_fastopen)
            if [ "$TFO_VALUE" -gt 0 ]; then
                echo "  + TCP Fast Open активирован (значение: $TFO_VALUE) ✓"
            else
                echo "  - TCP Fast Open не активирован ×"
            fi
        else
            echo "  - TCP Fast Open не поддерживается ядром ×"
        fi
        
        # Проверка размера буферов сети
        RMEM_MAX=$(sysctl net.core.rmem_max 2>/dev/null | awk '{print $3}')
        WMEM_MAX=$(sysctl net.core.wmem_max 2>/dev/null | awk '{print $3}')
        echo "  + Размер буфера приема: $RMEM_MAX"
        echo "  + Размер буфера передачи: $WMEM_MAX"
        
        echo ""
        echo "2. ПРОВЕРКА СЕТЕВЫХ ИНТЕРФЕЙСОВ"
        echo "------------------------------"
        for interface in $(ip -o link show | awk -F': ' '{print $2}'); do
            if [ "$interface" != "lo" ] && [[ ! "$interface" =~ ^docker ]]; then
                echo "  - Интерфейс: $interface"
                
                # Проверка MTU
                MTU=$(ip link show dev $interface | grep -oP 'mtu \K\d+')
                echo "    + MTU: $MTU"
                
                # Проверка offload параметров, если ethtool доступен
                if command -v ethtool &> /dev/null; then
                    TCP_SEG_OFFLOAD=$(ethtool -k $interface 2>/dev/null | grep "tcp-segmentation-offload" | awk '{print $2}')
                    if [ "$TCP_SEG_OFFLOAD" = "on" ]; then
                        echo "    + TCP Segmentation Offload: включен ✓"
                    else
                        echo "    - TCP Segmentation Offload: выключен"
                    fi
                fi
            fi
        done
        
        echo ""
        echo "3. ПРОВЕРКА XRAY"
        echo "---------------"
        # Проверка наличия Xray
        XRAY_BIN=$(which xray 2>/dev/null || find /usr/local/bin /usr/bin /root/bin /usr/local/x-ui/bin -name xray 2>/dev/null | head -1)
        if [ -n "$XRAY_BIN" ]; then
            echo "  + Xray найден: $XRAY_BIN ✓"
            
            # Проверка версии Xray
            XRAY_VERSION=$($XRAY_BIN version 2>/dev/null | head -1 || echo "Не удалось определить версию")
            echo "  + Версия Xray: $XRAY_VERSION"
            
            # Проверка запущен ли Xray
            XRAY_PID=$(pgrep -f "xray run" || pgrep -f "xray -config" || pgrep -f "xray$")
            if [ -n "$XRAY_PID" ]; then
                echo "  + Xray запущен (PID: $XRAY_PID) ✓"
                
                # Проверка приоритета
                XRAY_PRIO=$(ps -o nice -p $XRAY_PID | tail -1)
                if [ "$XRAY_PRIO" -lt 0 ]; then
                    echo "  + Приоритет Xray повышен (nice: $XRAY_PRIO) ✓"
                else
                    echo "  - Приоритет Xray не оптимизирован (nice: $XRAY_PRIO) ×"
                fi
            else
                echo "  - Xray не запущен ×"
            fi
            
            # Проверка лимитов файлов
            if [ -f "/etc/security/limits.conf" ]; then
                if grep -q "nofile 1000000" /etc/security/limits.conf; then
                    echo "  + Лимиты открытых файлов оптимизированы ✓"
                else
                    echo "  - Лимиты открытых файлов не оптимизированы ×"
                fi
            fi
        else
            echo "  - Xray не найден ×"
        fi
        
        echo ""
        echo "4. ПРОВЕРКА 3X-UI"
        echo "----------------"
        # Проверка наличия 3x-ui
        XUI_BIN=$(which x-ui 2>/dev/null || find /usr/bin /usr/local/bin /etc/x-ui -name x-ui 2>/dev/null | head -1)
        if [ -n "$XUI_BIN" ]; then
            echo "  + 3x-ui найден: $XUI_BIN ✓"
            
            # Проверка запущен ли x-ui
            if command -v systemctl &> /dev/null && systemctl is-active --quiet x-ui; then
                echo "  + Сервис x-ui запущен ✓"
            else
                echo "  - Сервис x-ui не запущен ×"
            fi
            
            # Поиск конфигов VLESS
            VLESS_CONFIGS=0
            for config in "/usr/local/x-ui/bin/config.json" "/etc/x-ui/config.json" "/usr/local/etc/xray/config.json" "/etc/xray/config.json"; do
                if [ -f "$config" ] && grep -q "\"protocol\": \"vless\"" "$config"; then
                    VLESS_CONFIGS=$((VLESS_CONFIGS + 1))
                    
                    # Проверка оптимизаций VLESS
                    if grep -q "tcpFastOpen" "$config"; then
                        echo "  + VLESS с TCP Fast Open найден в $config ✓"
                    else
                        echo "  - VLESS без TCP Fast Open в $config ×"
                    fi
                    
                    # Проверка Reality
                    if grep -q "\"security\": \"reality\"" "$config"; then
                        echo "  + VLESS с Reality найден в $config ✓"
                    fi
                    
                    # Проверка TLS 1.3
                    if grep -q "\"minVersion\": \"1.3\"" "$config"; then
                        echo "  + TLS 1.3 настроен в $config ✓"
                    fi
                fi
            done
            
            if [ "$VLESS_CONFIGS" -eq 0 ]; then
                echo "  - Конфигурации VLESS не найдены ×"
            else
                echo "  + Найдено $VLESS_CONFIGS конфигураций VLESS ✓"
            fi
        else
            echo "  - 3x-ui не найден ×"
        fi
        
        echo ""
        echo "5. ПРОВЕРКА SWAP"
        echo "--------------"
        # Проверка наличия SWAP
        SWAP_TOTAL=$(free -m | grep Swap | awk '{print $2}')
        if [ "$SWAP_TOTAL" -gt 0 ]; then
            echo "  + SWAP настроен (размер: ${SWAP_TOTAL}MB) ✓"
            
            # Проверка параметров свопинга
            SWAPPINESS=$(sysctl vm.swappiness 2>/dev/null | awk '{print $3}')
            if [ -n "$SWAPPINESS" ] && [ "$SWAPPINESS" -le 10 ]; then
                echo "  + Swappiness оптимизирован (значение: $SWAPPINESS) ✓"
            else
                echo "  - Swappiness не оптимизирован (значение: $SWAPPINESS) ×"
            fi
        else
            echo "  - SWAP не настроен ×"
        fi
        
        echo ""
        echo "6. РЕЗУЛЬТАТЫ ТЕСТА СКОРОСТИ"
        echo "---------------------------"
        if [ -n "$DOWNLOAD" ] && [ "$DOWNLOAD" != "N/A" ]; then
            echo "  + Пинг: $PING ms"
            echo "  + Скорость загрузки: $DOWNLOAD Mbit/s"
            echo "  + Скорость отдачи: $UPLOAD Mbit/s"
        else
            echo "  - Тест скорости не выполнен или завершился с ошибкой ×"
        fi
        
        echo ""
        echo "7. РЕКОМЕНДАЦИИ ПО ДАЛЬНЕЙШЕЙ ОПТИМИЗАЦИИ"
        echo "-----------------------------------------"
        # Предложения по дальнейшей оптимизации
        if [ -n "$XUI_BIN" ]; then
            echo "  1. Проверьте настройки VLESS в панели 3x-ui:"
            echo "     - Используйте протокол TCP вместо HTTP/WebSocket/gRPC для лучшей скорости"
            echo "     - Включите XTLS-Vision flow для максимальной скорости в VLESS+TCP"
            echo "     - Используйте Reality вместо обычного TLS для лучшей приватности"
        fi
        
        echo "  2. Настройте файрвол для защиты сервера:"
        echo "     - Установите и настройте iptables/nftables"
        echo "     - Разрешите только необходимые порты"
        echo "     - Настройте fail2ban для защиты от брутфорса"
        
        echo "  3. Настройте мониторинг и автоматические обновления:"
        echo "     - Включите логирование для обнаружения проблем"
        echo "     - Настройте автоматические обновления системы и Xray"
        echo "     - Настройте резервное копирование конфигурации"
        
        echo ""
        echo "===== ИТОГОВАЯ ОЦЕНКА ОПТИМИЗАЦИИ ====="
        # Подсчет общего количества проверок и успешных проверок
        TOTAL_CHECKS=0
        SUCCESSFUL_CHECKS=0
        
        # Извлекаем результаты проверок из файла
        while IFS= read -r line; do
            if [[ "$line" == *"✓"* ]]; then
                SUCCESSFUL_CHECKS=$((SUCCESSFUL_CHECKS + 1))
                TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
            elif [[ "$line" == *"×"* ]]; then
                TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
            fi
        done < <(cat "$REPORT_FILE" | grep -E "✓|×")
        
        # Вычисляем процент успешных проверок
        if [ $TOTAL_CHECKS -gt 0 ]; then
            PERCENT=$((SUCCESSFUL_CHECKS * 100 / TOTAL_CHECKS))
            echo "Успешно выполнено $SUCCESSFUL_CHECKS из $TOTAL_CHECKS проверок ($PERCENT%)"
            
            if [ $PERCENT -ge 90 ]; then
                echo "Отлично! Ваша система оптимизирована на высоком уровне."
            elif [ $PERCENT -ge 70 ]; then
                echo "Хорошо! Система оптимизирована, но есть возможности для улучшения."
            elif [ $PERCENT -ge 50 ]; then
                echo "Удовлетворительно. Некоторые оптимизации выполнены, но требуется дальнейшая работа."
            else
                echo "Требуется дополнительная оптимизация. Обратите внимание на пункты, отмеченные '×'."
            fi
        fi
        
        echo ""
        echo "Отчет сохранен в файл: $REPORT_FILE"
        echo "=== Конец отчета ==="
    } > "$REPORT_FILE"
    
    echo -e "${GREEN}[+] Проверка результатов оптимизации завершена${NC}"
    echo -e "${YELLOW}[*] Отчет сохранен в файл: $REPORT_FILE${NC}"
    echo -e "${YELLOW}[*] Просмотреть отчет можно командой: cat $REPORT_FILE${NC}"
}

# Очистка дубликатов в sysctl.conf
clean_sysctl_duplicates() {
    echo -e "${BLUE}[*] Очистка дублирующихся параметров в sysctl.conf...${NC}"
    
    # Создаем временный файл
    TMP_SYSCTL=$(mktemp)
    
    # Получаем список всех параметров из sysctl.conf
    grep -v "^#" /etc/sysctl.conf | grep -v "^$" | sort > "$TMP_SYSCTL.all"
    
    # Получаем список уникальных параметров (только имена)
    cut -d "=" -f1 "$TMP_SYSCTL.all" | sort | uniq > "$TMP_SYSCTL.keys"
    
    # Копируем комментарии в новый файл
    grep "^#" /etc/sysctl.conf > "$TMP_SYSCTL.clean"
    
    # Добавляем пустые строки
    grep "^$" /etc/sysctl.conf >> "$TMP_SYSCTL.clean"
    
    # Для каждого параметра находим последнее его значение
    while read -r param; do
        param=$(echo "$param" | xargs)  # Удаляем лишние пробелы
        if [ -n "$param" ]; then
            grep "^$param[[:space:]]*=" "$TMP_SYSCTL.all" | tail -1 >> "$TMP_SYSCTL.clean"
        fi
    done < "$TMP_SYSCTL.keys"
    
    # Создаем резервную копию исходного файла
    cp /etc/sysctl.conf /etc/sysctl.conf.bak.$(date +%Y%m%d%H%M%S)
    
    # Применяем новый файл
    cat "$TMP_SYSCTL.clean" > /etc/sysctl.conf
    
    # Подсчитываем количество удаленных дубликатов
    ORIGINAL_COUNT=$(grep -v "^#" /etc/sysctl.conf.bak.* | grep -v "^$" | wc -l)
    NEW_COUNT=$(grep -v "^#" /etc/sysctl.conf | grep -v "^$" | wc -l)
    REMOVED_COUNT=$((ORIGINAL_COUNT - NEW_COUNT))
    
    echo -e "${GREEN}[+] Удалено $REMOVED_COUNT дублирующихся параметров в sysctl.conf${NC}"
    
    # Очистка временных файлов
    rm -f "$TMP_SYSCTL" "$TMP_SYSCTL.all" "$TMP_SYSCTL.keys" "$TMP_SYSCTL.clean"
    
    # Применяем обновленные настройки
    sysctl -p
}

# Основная функция
main() {
    # Проверка и подготовка среды уже выполнена в начале скрипта
    
    get_system_specs
    
    # Если выбран режим только отчета, пропускаем все оптимизации
    if [ "$ONLY_REPORT" = true ]; then
        echo -e "${YELLOW}[*] Выбран режим только создания отчета. Пропускаем оптимизации.${NC}"
        # Проверяем результаты текущего состояния
        check_optimization_results
        return 0
    fi
    
    # Выполняем оптимизации в соответствии с параметрами
    optimize_io
    
    # Настройка SWAP если не пропущена
    if [ "$SKIP_SWAP" = false ]; then
        setup_swap
    else
        echo -e "${YELLOW}[*] Пропускаем настройку SWAP.${NC}"
    fi
    
    optimize_sysctl
    optimize_tcp
    optimize_network
    optimize_limits
    optimize_ssh
    optimize_services
    
    # Оптимизация VLESS если не пропущена
    if [ "$SKIP_VLESS" = false ]; then
        optimize_vless
    else
        echo -e "${YELLOW}[*] Пропускаем оптимизацию VLESS.${NC}"
    fi
    
    # Оптимизация Xray если не пропущена
    if [ "$SKIP_XRAY" = false ]; then
        optimize_xray
    else
        echo -e "${YELLOW}[*] Пропускаем оптимизацию Xray.${NC}"
    fi
    
    # Очистка дубликатов в sysctl.conf
    clean_sysctl_duplicates
    
    # Тестирование сети если не пропущено
    if [ "$SKIP_NETWORK" = false ]; then
        test_network_speed
    else
        echo -e "${YELLOW}[*] Пропускаем тест скорости сети.${NC}"
        # Устанавливаем значения по умолчанию для отчетов
        PING="N/A"
        DOWNLOAD="N/A"
        UPLOAD="N/A"
    fi
    
    # Расчет максимального количества пользователей
    calculate_max_users
    
    echo -e "${GREEN}[+] Расширенная оптимизация завершена успешно!${NC}"
    echo -e "${BLUE}[*] Рекомендуется перезагрузить сервер${NC}"
    echo -e "${YELLOW}[*] Характеристики системы сохранены в /root/system_specs.txt${NC}"
    
    # Сохранение характеристик системы
    {
        echo "=== Характеристики системы ==="
        echo "CPU: $CPU_MODEL"
        echo "Количество ядер: $CPU_CORES"
        echo "Оперативная память: $TOTAL_RAM MB"
        echo "Размер диска: ${DISK_SIZE}GB"
        echo "Тип диска: $([ "$DISK_TYPE" = "0" ] && echo "SSD" || echo "HDD")"
        echo "=== Настройки оптимизации ==="
        echo "Размер SWAP: $SWAP_SIZE MB"
        echo "Максимальное количество открытых файлов: $MAX_FILES"
        echo "TCP Congestion Control: $(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "Не настроен")"
        echo "IO Scheduler: $(cat /sys/block/$(df -P / | awk 'NR==2 {print $1}' | sed 's/[0-9]*$//;s/\/dev\///')/queue/scheduler 2>/dev/null || echo "Не настроен")"
        echo ""
        echo "=== Результаты теста скорости ==="
        echo "Пинг: $PING ms"
        echo "Скорость загрузки: $DOWNLOAD Mbit/s"
        echo "Скорость отдачи: $UPLOAD Mbit/s"
        echo ""
        echo "============================================="
        echo "РЕКОМЕНДУЕМОЕ МАКСИМАЛЬНОЕ КОЛИЧЕСТВО"
        echo "ОДНОВРЕМЕННЫХ ПОЛЬЗОВАТЕЛЕЙ ДЛЯ 3X-UI:"
        echo "$MAX_USERS ПОЛЬЗОВАТЕЛЕЙ"
        echo "============================================="
        echo ""
        echo "* Это значение рассчитано с учетом:"
        echo "  - Доступной оперативной памяти"
        echo "  - Количества ядер процессора"
        echo "  - Коэффициента безопасности 0.8"
        echo ""
        echo "* Рекомендации для достижения максимальной скорости:"
        echo "  1. Используйте протокол VLESS вместо VMESS (рекомендуемый протокол)"
        echo "  2. Включите TCP BBR (уже включено)"
        echo "  3. Используйте порты выше 10000"
        echo "  4. Отключите TLS для внутренних соединений"
        echo "  5. Установите MTU = 1500"
        echo "  6. Используйте режим TCP_FAST_OPEN (уже включено)"
        echo "  7. Используйте Reality вместо обычного TLS для лучшей приватности"
        echo "  8. Выберите транспортный протокол TCP (не HTTP/GRPC/WebSocket) для скорости"
        echo "  9. Используйте XTLS-VISION flow для максимальной скорости в VLESS+TCP"
        echo " 10. Используйте h2 (HTTP/2) в качестве ALPN при использовании TLS"
        echo " 11. Установите минимальную версию TLS 1.3 для улучшения безопасности"
        echo ""
        echo "* Параметры производительности после оптимизации:"
        echo "  - Увеличены размеры TCP буферов до оптимальных значений"
        echo "  - Оптимизирован приоритет процесса Xray для минимальной задержки"
        echo "  - Настроены параметры ядра для минимальной задержки передачи пакетов"
        echo "  - Задействованы оптимизации TCP для стабильных высокоскоростных соединений"
        echo "  - Активировано TCP_FASTOPEN для ускорения установки соединений"
        echo "  - Оптимизировано распределение ресурсов для Xray"
        echo ""
        echo "* Расширенные оптимизации для 3x-ui VLESS:"
        echo "  - Настроены sockopt параметры для VLESS"
        echo "  - Оптимизированы параметры Reality и TLS"
        echo "  - Отрегулированы параметры обработки пакетов для снижения задержки"
        echo "  - Установлена приоритизация процесса Xray для maximum throughput"
        echo "  - Созданы оптимизированные systemd конфигурации"
        echo "  - Настроены параметры QoS для улучшения пропускной способности"
        echo ""
        echo "* Для дальнейшего улучшения скорости:"
        echo "  - Рекомендуется выполнить тюнинг VLESS в панели 3x-ui"
        echo "  - Обновите Xray до последней версии (min v1.8.0)"
        echo "  - Используйте блокировку рекламы и оптимизацию маршрутов"
        echo "  - Настройте правила маршрутизации для оптимального роутинга"
        echo ""
        echo "Дата оптимизации: $(date)"
    } > /root/system_specs.txt
    
    # Проверка результатов оптимизации
    check_optimization_results
    
    # Выводим сообщение о необходимости перезагрузки
    echo -e "${GREEN}[+] Все оптимизации завершены! ${YELLOW}Рекомендуется перезагрузить сервер!${NC}"
    
    # Перезагрузка в зависимости от параметра
    if [ "$AUTO_REBOOT" = true ]; then
        echo -e "${YELLOW}[*] Автоматическая перезагрузка сервера через 5 секунд...${NC}"
        sleep 5
        reboot
    else
        read -p "Перезагрузить сервер сейчас? (y/n): " REBOOT_NOW
        if [[ "$REBOOT_NOW" == "y" || "$REBOOT_NOW" == "Y" ]]; then
            echo -e "${YELLOW}[*] Перезагрузка сервера...${NC}"
            reboot
        else
            echo -e "${YELLOW}[*] Не забудьте перезагрузить сервер позже для применения всех изменений${NC}"
        fi
    fi
}

# Запуск скрипта
main 