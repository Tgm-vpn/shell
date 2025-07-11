#!/bin/bash

# Скрипт для первоначальной установки WireGuard и wg-rest на Debian 12.
# Настраивает wg0 на порту 443 и wg-rest на 127.0.0.1:10001.
# Должен быть запущен от имени root.

# --- Переменные ---
WG_LISTEN_PORT=443
WG_REST_LISTEN_ADDRESS="127.0.0.1"
WG_REST_LISTEN_PORT=10001
WG_REST_INSTALL_DIR="/opt/wg-rest"
WG_REST_SERVICE_FILE="/etc/systemd/system/wg-rest.service"

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

log_info "Начинаем установку WireGuard и wg-rest."

# --- 1. Установка WireGuard ---
log_info "1/4: Устанавливаем пакет WireGuard..."
apt update -y || { log_error "Ошибка при apt update."; exit 1; }
apt install -y wireguard qrencode || { log_error "Ошибка при установке WireGuard и qrencode."; exit 1; }
log_success "WireGuard установлен. ✅"

# --- 2. Генерация серверных ключей и настройка wg0.conf ---
log_info "2/4: Генерируем ключи WireGuard и настраиваем wg0.conf..."

WG_CONFIG_DIR="/etc/wireguard"
WG_CONF_FILE="$WG_CONFIG_DIR/wg0.conf"

mkdir -p "$WG_CONFIG_DIR" || { log_error "Не удалось создать директорию $WG_CONFIG_DIR."; exit 1; }
chmod 700 "$WG_CONFIG_DIR" || { log_error "Не удалось установить права для $WG_CONFIG_DIR."; exit 1; }

# Генерируем ключи сервера
SERVER_PRIV_KEY=$(wg genkey)
SERVER_PUB_KEY=$(echo "$SERVER_PRIV_KEY" | wg pubkey)

# Удаляем старый wg0.conf, если он есть
rm -f "$WG_CONF_FILE"

# Создаем wg0.conf
cat <<EOF > "$WG_CONF_FILE"
[Interface]
PrivateKey = $SERVER_PRIV_KEY
Address = 10.244.0.1/24
ListenPort = $WG_LISTEN_PORT
SaveConfig = true # Позволяет wg-quick сохранять изменения пиров

EOF

chmod 600 "$WG_CONF_FILE" || { log_error "Не удалось установить права для $WG_CONF_FILE."; exit 1; }
log_success "Серверные ключи сгенерированы и $WG_CONF_FILE создан. ✅"
log_info "Публичный ключ сервера WireGuard: $SERVER_PUB_KEY"
log_info "Запомните этот ключ, он понадобится для клиентов."

# Включаем форвардинг IPv4
log_info "Включаем перенаправление IPv4..."
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard-forwarding.conf
sysctl -p /etc/sysctl.d/99-wireguard-forwarding.conf || { log_error "Ошибка при включении форвардинга IPv4."; exit 1; }
log_success "Перенаправление IPv4 включено. ✅"

# --- 3. Установка и настройка wg-rest ---
log_info "3/4: Устанавливаем и настраиваем wg-rest..."

# Скачиваем последнюю версию wg-rest
WG_REST_VERSION=$(curl -s "https://api.github.com/repos/WireGuard/wg-rest/releases/latest" | grep -Po '"tag_name": "\K[^"]*')
if [ -z "$WG_REST_VERSION" ]; then
    log_error "Не удалось определить последнюю версию wg-rest. Пожалуйста, проверьте вручную."
    exit 1
fi
log_info "Обнаружена последняя версия wg-rest: $WG_REST_VERSION"

WG_REST_ARCH="amd64" # Для большинства Debian серверов
WG_REST_DOWNLOAD_URL="https://github.com/WireGuard/wg-rest/releases/download/${WG_REST_VERSION}/wg-rest-linux-${WG_REST_ARCH}"

mkdir -p "$WG_REST_INSTALL_DIR" || { log_error "Не удалось создать директорию установки wg-rest $WG_REST_INSTALL_DIR."; exit 1; }

log_info "Скачиваем wg-rest с $WG_REST_DOWNLOAD_URL..."
curl -L "$WG_REST_DOWNLOAD_URL" -o "$WG_REST_INSTALL_DIR/wg-rest" || { log_error "Не удалось скачать wg-rest."; exit 1; }
chmod +x "$WG_REST_INSTALL_DIR/wg-rest" || { log_error "Не удалось сделать wg-rest исполняемым."; exit 1; }
log_success "wg-rest успешно скачан и установлен. ✅"

# Создаем systemd сервис для wg-rest
log_info "Создаем systemd сервис для wg-rest..."

cat <<EOF > "$WG_REST_SERVICE_FILE"
[Unit]
Description=WireGuard REST API
After=network.target wg-quick@wg0.service

[Service]
ExecStart=$WG_REST_INSTALL_DIR/wg-rest --bind-address $WG_REST_LISTEN_ADDRESS --port $WG_REST_LISTEN_PORT --config $WG_CONFIG_DIR/wg0.conf
Restart=always
RestartSec=5s
User=root # wg-rest должен работать от root для доступа к WireGuard
Group=root

[Install]
WantedBy=multi-user.target
EOF

if [ $? -ne 0 ]; then
    log_error "Ошибка при создании Systemd unit-файла для wg-rest."
    exit 1
fi
log_success "Systemd unit-файл для wg-rest создан. ✅"

# --- 4. Запуск WireGuard и wg-rest ---
log_info "4/4: Запускаем службы WireGuard и wg-rest..."

# Включаем и запускаем wg0
systemctl daemon-reload
systemctl enable wg-quick@wg0 || { log_error "Не удалось включить wg-quick@wg0."; exit 1; }
systemctl start wg-quick@wg0 || { log_error "Не удалось запустить wg-quick@wg0. Проверьте 'journalctl -u wg-quick@wg0'."; exit 1; }
log_success "WireGuard wg0 запущен. ✅"

# Включаем и запускаем wg-rest
systemctl enable wg-rest || { log_error "Не удалось включить wg-rest."; exit 1; }
systemctl start wg-rest || { log_error "Не удалось запустить wg-rest. Проверьте 'journalctl -u wg-rest'."; exit 1; }
log_success "wg-rest запущен. ✅"

log_info "Установка WireGuard и wg-rest завершена."
log_info "WireGuard сервер запущен на порту: $WG_LISTEN_PORT"
log_info "WG-REST API доступен по адресу: http://$WG_REST_LISTEN_ADDRESS:$WG_REST_LISTEN_PORT"
log_info "Используйте 'wg show' для проверки статуса WireGuard."
log_info "Используйте 'curl http://$WG_REST_LISTEN_ADDRESS:$WG_REST_LISTEN_PORT/peers' для проверки wg-rest."

log_info "Скрипт завершил работу."