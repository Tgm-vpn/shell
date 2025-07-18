#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Скрипт для первоначальной установки WireGuard на Debian 12.
# Настраивает wg0 на указанном порту.
# Должен быть запущен от имени root.

# --- Переменные ---
WG_LISTEN_PORT=443 # Порт для прослушивания WireGuard

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

log_info "Начинаем установку WireGuard."

# --- Проверка прав root ---
if [[ $EUID -ne 0 ]]; then
   log_error "Этот скрипт должен быть запущен от имени root."
   exit 1
fi

# --- 1. Установка WireGuard ---
log_info "1/3: Устанавливаем пакет WireGuard..."
apt update -y || { log_error "Ошибка при apt update."; exit 1; }
apt install -y wireguard qrencode || { log_error "Ошибка при установке WireGuard и qrencode."; exit 1; }
log_success "WireGuard установлен. ✅"

# --- 2. Генерация серверных ключей и настройка wg0.conf ---
log_info "2/3: Генерируем ключи WireGuard и настраиваем wg0.conf..."

WG_CONFIG_DIR="/etc/wireguard"
WG_CONF_FILE="$WG_CONFIG_DIR/wg0.conf"

mkdir -p "$WG_CONFIG_DIR" || { log_error "Не удалось создать директорию $WG_CONFIG_DIR."; exit 1; }
chmod 700 "$WG_CONFIG_DIR" || { log_error "Не удалось установить права для $WG_CONFIG_DIR."; exit 1; }

# Генерируем ключи сервера и обрезаем пробелы/новые строки
SERVER_PRIV_KEY=$(wg genkey | tr -d '\n' | tr -d ' ')
SERVER_PUB_KEY=$(echo "$SERVER_PRIV_KEY" | wg pubkey | tr -d '\n' | tr -d ' ')

# --- Добавлена проверка ключей ---
if [[ -z "$SERVER_PRIV_KEY" || ${#SERVER_PRIV_KEY} -ne 44 ]]; then
    log_error "Ошибка: Приватный ключ WireGuard пуст или имеет неверную длину (ожидается 44 символа)."
    log_error "Полученный ключ: '${SERVER_PRIV_KEY}' (длина: ${#SERVER_PRIV_KEY})"
    exit 1
fi

if [[ -z "$SERVER_PUB_KEY" || ${#SERVER_PUB_KEY} -ne 44 ]]; then
    log_error "Ошибка: Публичный ключ WireGuard пуст или имеет неверную длину (ожидается 44 символа)."
    log_error "Полученный ключ: '${SERVER_PUB_KEY}' (длина: ${#SERVER_PUB_KEY})"
    exit 1
fi
# --- Конец проверки ключей ---

# Удаляем старый wg0.conf, если он есть
rm -f "$WG_CONF_FILE"

# Создаем wg0.conf
# Используем printf для точного контроля вывода и предотвращения нежелательных символов
printf "[Interface]\n" > "$WG_CONF_FILE"
printf "PrivateKey = %s\n" "$SERVER_PRIV_KEY" >> "$WG_CONF_FILE"
printf "Address = 10.244.0.1/24\n" >> "$WG_CONF_FILE"
printf "ListenPort = %d\n" "$WG_LISTEN_PORT" >> "$WG_CONF_FILE"
printf "SaveConfig = true # Позволяет wg-quick сохранять изменения пиров\n\n" >> "$WG_CONF_FILE"


chmod 600 "$WG_CONF_FILE" || { log_error "Не удалось установить права для $WG_CONF_FILE."; exit 1; }
log_success "Серверные ключи сгенерированы и $WG_CONF_FILE создан. ✅"
log_info "Публичный ключ сервера WireGuard: $SERVER_PUB_KEY"
log_info "Запомните этот ключ, он понадобится для клиентов."

# Включаем форвардинг IPv4
log_info "Включаем перенаправление IPv4..."
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-wireguard-forwarding.conf
sysctl -p /etc/sysctl.d/99-wireguard-forwarding.conf || { log_error "Ошибка при включении форвардинга IPv4."; exit 1; }
log_success "Перенаправление IPv4 включено. ✅"

# --- 3. Запуск WireGuard ---
log_info "3/3: Запускаем службу WireGuard..."
systemctl daemon-reload
systemctl enable wg-quick@wg0 || { log_error "Не удалось включить wg-quick@wg0."; exit 1; }
systemctl start wg-quick@wg0 || { log_error "Не удалось запустить wg-quick@wg0. Проверьте 'journalctl -u wg-quick@wg0'."; exit 1; }
log_success "WireGuard wg0 запущен. ✅"

log_info "Установка WireGuard завершена."
log_info "WireGuard сервер запущен на порту: $WG_LISTEN_PORT"
log_info "Используйте 'wg show' для проверки статуса WireGuard."

log_info "Скрипт завершил работу."