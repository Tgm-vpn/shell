#!/bin/bash

# Скрипт для восстановления конфигураций WireGuard из бэкапа.
# Предназначен для запуска от имени root на сервере Debian 12.
# ПРЕДПОЛАГАЕТСЯ, ЧТО WIREGUARD И WG-REST УЖЕ УСТАНОВЛЕНЫ И РАБОТАЮТ!
# Использование: ./restore_wg_config.sh <ПУТЬ_К_АРХИВУ_БЭКАПА>

# --- Переменные ---
# BACKUP_ARCHIVE_PATH теперь будет браться из аргумента командной строки
WG_CONFIG_TARGET_DIR="/etc/wireguard" # Целевая директория для конфигураций WireGuard
TEMP_EXTRACT_DIR="/tmp/wg_restore_temp" # Временная директория для распаковки бэкапа

# Настройки WG-REST (используются для проверки доступности после восстановления)
WG_REST_LISTEN_ADDRESS="127.0.0.1"
WG_REST_LISTEN_PORT=10001 # Порт wg-rest

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

# --- Проверка аргументов ---
if [ -z "$1" ]; then
    log_error "Использование: $0 <ПУТЬ_К_АРХИВУ_БЭКАПА>"
    log_error "Пример: sudo ./restore_wg_config.sh /root/my_backups/wireguard_configs_20231027_153000.tar.gz"
    exit 1
fi

BACKUP_ARCHIVE_PATH="$1" # Получаем путь к архиву из первого аргумента

log_info "Начинаем процесс восстановления WireGuard конфигурации из бэкапа."

# --- 1. Проверка наличия файла бэкапа ---
log_info "1/4: Проверяем наличие файла резервной копии: $BACKUP_ARCHIVE_PATH"
if [ ! -f "$BACKUP_ARCHIVE_PATH" ]; then
    log_error "Файл резервной копии '$BACKUP_ARCHIVE_PATH' не найден. Укажите правильный путь."
    exit 1
fi
log_success "Файл резервной копии найден. ✅"

# --- 2. Остановка WireGuard для восстановления ---
log_info "2/4: Останавливаем службы WireGuard (wg-quick@wg0) и wg-rest (wg-rest.service)..."
systemctl stop wg-quick@wg0 2>/dev/null
systemctl stop wg-rest 2>/dev/null
log_success "Службы WireGuard и wg-rest остановлены (если были запущены). ✅"

# --- 3. Распаковка бэкапа и восстановление файлов ---
log_info "3/4: Распаковываем архив '$BACKUP_ARCHIVE_PATH' и восстанавливаем файлы..."

# Создаем и очищаем временную директорию
mkdir -p "$TEMP_EXTRACT_DIR" || { log_error "Не удалось создать временную директорию $TEMP_EXTRACT_DIR."; exit 1; }
rm -rf "$TEMP_EXTRACT_DIR"/* # Очищаем на случай предыдущих запусков

# Распаковываем архив
tar -xzf "$BACKUP_ARCHIVE_PATH" -C "$TEMP_EXTRACT_DIR" --strip-components=1 || { log_error "Не удалось распаковать архив резервной копии."; exit 1; }
log_success "Архив резервной копии успешно распакован. ✅"

# Очищаем существующую конфигурацию WireGuard (ОСТОРОЖНО!)
log_info "Очищаем существующую директорию $WG_CONFIG_TARGET_DIR/* перед восстановлением..."
rm -rf "$WG_CONFIG_TARGET_DIR"/*
mkdir -p "$WG_CONFIG_TARGET_DIR" # Убедимся, что директория существует

# Копируем восстановленные файлы
cp -r "$TEMP_EXTRACT_DIR/etc/wireguard/"* "$WG_CONFIG_TARGET_DIR/" || { log_error "Не удалось скопировать восстановленные файлы WireGuard."; exit 1; }

# Устанавливаем правильные права доступа (очень важно для WireGuard!)
chmod 600 "$WG_CONFIG_TARGET_DIR/wg0.conf" || { log_error "Не удалось установить права для wg0.conf."; exit 1; }
# Убедимся, что директории keys и configs существуют перед установкой прав
mkdir -p "$WG_CONFIG_TARGET_DIR/keys" "$WG_CONFIG_TARGET_DIR/configs"
chmod -R 700 "$WG_CONFIG_TARGET_DIR/keys" || { log_error "Не удалось установить права для директории keys."; exit 1; }
chmod -R 700 "$WG_CONFIG_TARGET_DIR/configs" || { log_error "Не удалось установить права для директории configs."; exit 1; }

log_success "Серверный wg0.conf, ключи и клиентские конфигурации восстановлены. ✅"

# --- 4. Запуск WireGuard и wg-rest ---
log_info "4/4: Запускаем службы WireGuard (wg-quick@wg0) и wg-rest (wg-rest.service)..."

# Запускаем wg-rest первым, чтобы он мог прочитать wg0.conf
systemctl start wg-rest || { log_error "Не удалось запустить wg-rest. Проверьте 'journalctl -u wg-rest'."; exit 1; }
log_success "wg-rest запущен. ✅"
sleep 5 # Даем wg-rest время на инициализацию и чтение wg0.conf

# Запускаем WireGuard
systemctl start wg-quick@wg0 || { log_error "Не удалось запустить wg-quick@wg0. Проверьте логи WireGuard."; exit 1; }
log_success "Служба WireGuard запущена. ✅"

log_info "Процесс восстановления WireGuard завершен."
log_info "Не забудьте удалить временную директорию: rm -rf $TEMP_EXTRACT_DIR"
log_info "Проверьте статус WireGuard: wg show"
log_info "Проверьте статус WG-REST: curl http://$WG_REST_LISTEN_ADDRESS:$WG_REST_LISTEN_PORT/peers"