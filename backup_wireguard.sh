#!/usr/bin/bash

# Скрипт для резервного копирования конфигураций WireGuard, установленных через PiVPN.
# Предназначен для запуска от имени root на сервере Debian 12.

# --- Переменные ---
BACKUP_DIR="/root/wireguard_backup" # Директория для хранения архива резервной копии
TIMESTAMP=$(date +"%Y%m%d_%H%M%S") # Метка времени для имени файла резервной копии
BACKUP_FILENAME="wireguard_configs_${TIMESTAMP}.tar.gz" # Имя файла архива резервной копии

# Директории/файлы для резервного копирования
WIREGUARD_CONFIG_DIR="/etc/wireguard"
PIVPN_INSTALL_SCRIPT_DIR="/opt/pivpn" # Директория установки PiVPN (если существует)

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

log_info "Начинаем процесс резервного копирования конфигурации WireGuard."

# --- 1. Создание директории для резервной копии ---
log_info "1/3: Создаем директорию для резервной копии: $BACKUP_DIR"
mkdir -p "$BACKUP_DIR" || { log_error "Не удалось создать директорию для резервной копии $BACKUP_DIR."; exit 1; }
log_success "Директория для резервной копии создана. ✅"

# --- 2. Создание архива ---
log_info "2/3: Создаем архив конфигурации WireGuard: $BACKUP_FILENAME"

# Проверяем, существует ли директория конфигурации WireGuard
if [ ! -d "$WIREGUARD_CONFIG_DIR" ]; then
    log_error "Директория конфигурации WireGuard '$WIREGUARD_CONFIG_DIR' не найдена. WireGuard установлен?"
    exit 1
fi

# Используем tar для сжатия всей директории /etc/wireguard.
# Это включает wg0.conf, /keys/ и /configs/.
# Также проверяем /opt/pivpn, который может содержать другие связанные с PiVPN скрипты/данные.
if [ -d "$PIVPN_INSTALL_SCRIPT_DIR" ]; then
    tar -czf "$BACKUP_DIR/$BACKUP_FILENAME" "$WIREGUARD_CONFIG_DIR" "$PIVPN_INSTALL_SCRIPT_DIR" || { log_error "Не удалось создать архив резервной копии."; exit 1; }
else
    tar -czf "$BACKUP_DIR/$BACKUP_FILENAME" "$WIREGUARD_CONFIG_DIR" || { log_error "Не удалось создать архив резервной копии."; exit 1; }
    log_info "Примечание: Директория установки PiVPN '$PIVPN_INSTALL_SCRIPT_DIR' не найдена, пропускаем ее резервное копирование."
fi

log_success "Конфигурации WireGuard скопированы в $BACKUP_DIR/$BACKUP_FILENAME. 💾"

# --- 3. Проверка резервной копии ---
log_info "3/3: Проверяем файл резервной копии..."
if [ -f "$BACKUP_DIR/$BACKUP_FILENAME" ]; then
    log_info "Размер файла резервной копии: $(du -h "$BACKUP_DIR/$BACKUP_FILENAME" | awk '{print $1}')"
    log_success "Проверка резервной копии прошла успешно. ✅"
else
    log_error "Файл резервной копии '$BACKUP_FILENAME' не найден после создания. Резервное копирование не удалось."
    exit 1
fi

log_info "Процесс резервного копирования WireGuard завершен."
log_info "Для восстановления обычно требуется переустановить PiVPN/WireGuard, остановить службу WireGuard, а затем заменить файлы конфигурации из этой резервной копии."
log_info "Не забудьте обновить PrivateKey сервера и IP-адрес конечной точки клиента, если публичный IP-адрес сервера изменится."