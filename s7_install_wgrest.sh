#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Скрипт для установки и настройки wgrest (API для WireGuard от suquant) на Debian 12.
# Настраивает wgrest на 127.0.0.1:10001.
# Должен быть запущен от имени root.
# Требует предварительной установки WireGuard (и wg0.conf).

# --- Переменные ---
WG_REST_LISTEN_ADDRESS="127.0.0.1" # Адрес, на котором будет слушать wgrest
WG_REST_LISTEN_PORT=10001           # Порт для wgrest API
WG_REST_INSTALL_DIR="/opt/wgrest"   # Директория установки wgrest
WG_REST_SERVICE_FILE="/etc/systemd/system/wgrest.service"
WG_CONFIG_DIR="/etc/wireguard"      # Директория конфигурации WireGuard

# --- Функции для логирования ---
log_info() {
    echo "INFO: $1"
}

log_error() {
    echo "ERROR: $1" >&2
}

log_success() {
    echo "SUCCESS: $1"
}

log_info "Начинаем установку wgrest (suquant)."

# --- Проверка прав root ---
if [[ $EUID -ne 0 ]]; then
   log_error "Этот скрипт должен быть запущен от имени root."
   exit 1
fi

# --- 1. Проверка наличия WireGuard конфигурации ---
if [ ! -f "$WG_CONFIG_DIR/wg0.conf" ]; then
    log_error "Не найден файл конфигурации WireGuard wg0.conf ($WG_CONFIG_DIR/wg0.conf)."
    log_error "Пожалуйста, сначала установите WireGuard и настройте wg0.conf, используя install_wireguard.sh."
    exit 1
fi
log_info "Обнаружен файл конфигурации WireGuard wg0.conf. Продолжаем."

# --- 2. Скачивание и установка wgrest ---
log_info "1/2: Скачиваем и устанавливаем wgrest..."

# Получаем последнюю версию из GitHub API
WGREST_LATEST_RELEASE_URL="https://api.github.com/repos/suquant/wgrest/releases/latest"
WGREST_VERSION=$(curl -s "${WGREST_LATEST_RELEASE_URL}" | grep -Po '"tag_name": "\K[^"]*')

if [ -z "$WGREST_VERSION" ]; then
    log_error "Не удалось определить последнюю версию wgrest. Проверьте подключение или URL: ${WGREST_LATEST_RELEASE_URL}"
    exit 1
fi
log_info "Обнаружена последняя версия wgrest: ${WGREST_VERSION}"

# Определяем архитектуру (amd64, arm64, armv7)
ARCH=$(dpkg --print-architecture)
WGREST_BINARY_NAME=""

case "$ARCH" in
    amd64)
        WGREST_BINARY_NAME="wgrest-linux-amd64"
        ;;
    arm64)
        WGREST_BINARY_NAME="wgrest-linux-arm64"
        ;;
    armhf) # armhf на Debian 12 обычно armv7
        WGREST_BINARY_NAME="wgrest-linux-armv7"
        ;;
    *)
        log_error "Неподдерживаемая архитектура: ${ARCH}. Скрипт поддерживает amd64, arm64, armhf/armv7."
        exit 1
        ;;
esac

WGREST_DOWNLOAD_URL="https://github.com/suquant/wgrest/releases/download/${WGREST_VERSION}/${WGREST_BINARY_NAME}"

mkdir -p "$WG_REST_INSTALL_DIR" || { log_error "Не удалось создать директорию установки wgrest $WG_REST_INSTALL_DIR."; exit 1; }

log_info "Скачиваем wgrest с ${WGREST_DOWNLOAD_URL}..."
curl -L "${WGREST_DOWNLOAD_URL}" -o "${WG_REST_INSTALL_DIR}/wgrest" || { log_error "Не удалось скачать wgrest."; exit 1; }
chmod +x "${WG_REST_INSTALL_DIR}/wgrest" || { log_error "Не удалось сделать wgrest исполняемым."; exit 1; }
log_success "wgrest успешно скачан и установлен. ✅"

# --- 3. Создание systemd сервиса для wgrest ---
log_info "2/2: Создаем systemd сервис для wgrest..."

cat <<EOF > "${WG_REST_SERVICE_FILE}"
[Unit]
Description=WireGuard REST API (suquant/wgrest)
After=network.target wg-quick@wg0.service

[Service]
ExecStart=${WG_REST_INSTALL_DIR}/wgrest --listen ${WG_REST_LISTEN_ADDRESS}:${WG_REST_LISTEN_PORT} --conf ${WG_CONFIG_DIR}/wg0.conf
Restart=always
RestartSec=5s
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

if [ $? -ne 0 ]; then
    log_error "Ошибка при создании Systemd unit-файла для wgrest."
    exit 1
fi
log_success "Systemd unit-файл для wgrest создан. ✅"

# --- 4. Запуск wgrest ---
log_info "Запускаем службу wgrest..."
systemctl daemon-reload
systemctl enable wgrest || { log_error "Не удалось включить wgrest."; exit 1; }
systemctl start wgrest || { log_error "Не удалось запустить wgrest. Проверьте 'journalctl -u wgrest'."; exit 1; }
log_success "wgrest запущен. ✅"

log_info "Установка wgrest завершена."
log_info "WGREST API доступен по адресу: http://${WG_REST_LISTEN_ADDRESS}:${WG_REST_LISTEN_PORT}"
log_info "Для проверки используйте: curl http://${WG_REST_LISTEN_ADDRESS}:${WG_REST_LISTEN_PORT}/peers"

log_info "Скрипт завершил работу."