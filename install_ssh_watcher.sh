#!/bin/bash

# Скрипт для установки ssh_watcher.sh и настройки Systemd сервиса.
# Должен быть запущен от имени root.
# Использование: sudo ./install_ssh_watcher.sh <ВАШ_БОТ_ТОКЕН>

# --- Переменные ---
SSH_WATCHER_SCRIPT_NAME="ssh_watcher.sh"
INSTALL_PATH="/usr/local/bin/$SSH_WATCHER_SCRIPT_NAME"
SYSTEMD_SERVICE_NAME="ssh_watcher.service"
SYSTEMD_SERVICE_FILE="/etc/systemd/system/$SYSTEMD_SERVICE_NAME"

# BOT_TOKEN теперь передается как первый аргумент
BOT_TOKEN="$1"

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

# --- Проверка прав root ---
if [[ $EUID -ne 0 ]]; then
   log_error "Этот скрипт должен быть запущен от имени root."
   exit 1
fi

# --- Проверка аргументов ---
if [ -z "$BOT_TOKEN" ]; then
    log_error "Использование: $0 <ВАШ_БОТ_ТОКЕН>"
    log_error "Пример: sudo ./install_ssh_watcher.sh 7186089328:AAFIUznc2era-FXwZcxMA8ufZDSRmLFnJ1I"
    exit 1
fi

log_info "Начинаем установку SSH Watcher и настройку Systemd сервиса."

# --- 1. Копирование и модификация скрипта ---
log_info "1/3: Копируем и модифицируем скрипт $SSH_WATCHER_SCRIPT_NAME в $INSTALL_PATH..."
# Проверяем, существует ли файл скрипта в текущей директории
if [ ! -f "./$SSH_WATCHER_SCRIPT_NAME" ]; then
    log_error "Файл скрипта './$SSH_WATCHER_SCRIPT_NAME' не найден в текущей директории."
    log_error "Убедитесь, что вы запустили этот скрипт из той же директории, где находится $SSH_WATCHER_SCRIPT_NAME."
    exit 1
fi

# Копируем скрипт
cp "./$SSH_WATCHER_SCRIPT_NAME" "$INSTALL_PATH" || { log_error "Ошибка при копировании скрипта."; exit 1; }

# Вставляем BOT_TOKEN в ssh_watcher.sh
# Используем sed для вставки строки "BOT_TOKEN=\"$BOT_TOKEN\"" после строки # --- Конфигурация Telegram ---
# Важно: используем другую косую черту в разделителе sed ('|' вместо '/') для обработки токена
sed -i "/# --- Конфигурация Telegram ---/aBOT_TOKEN=\"$BOT_TOKEN\"" "$INSTALL_PATH" || { log_error "Ошибка при вставке BOT_TOKEN в скрипт."; exit 1; }

chmod +x "$INSTALL_PATH" || { log_error "Ошибка при установке прав на выполнение для скрипта."; exit 1; }
log_success "Скрипт $SSH_WATCHER_SCRIPT_NAME успешно скопирован, модифицирован и сделан исполняемым. ✅"

# --- 2. Создание Systemd Unit файла ---
log_info "2/3: Создаем Systemd unit-файл для $SYSTEMD_SERVICE_NAME..."

cat <<EOF > "$SYSTEMD_SERVICE_FILE"
[Unit]
Description=SSH Login Watcher for Root User
After=network.target syslog.target

[Service]
ExecStart=$INSTALL_PATH
Restart=always
RestartSec=5
StandardOutput=append:/var/log/ssh_watcher.log
StandardError=append:/var/log/ssh_watcher.log

[Install]
WantedBy=multi-user.target
EOF

if [ $? -ne 0 ]; then
    log_error "Ошибка при создании Systemd unit-файла $SYSTEMD_SERVICE_FILE."
    exit 1
fi
log_success "Systemd unit-файл $SYSTEMD_SERVICE_FILE успешно создан. ✅"

# --- 3. Активация и запуск Systemd сервиса ---
log_info "3/3: Активируем и запускаем Systemd сервис $SYSTEMD_SERVICE_NAME..."

systemctl daemon-reload || { log_error "Ошибка при перезагрузке демона systemd."; exit 1; }
systemctl enable "$SYSTEMD_SERVICE_NAME" || { log_error "Ошибка при включении сервиса $SYSTEMD_SERVICE_NAME."; exit 1; }
systemctl start "$SYSTEMD_SERVICE_NAME" || { log_error "Ошибка при запуске сервиса $SYSTEMD_SERVICE_NAME. Проверьте логи: journalctl -u $SYSTEMD_SERVICE_NAME -f"; exit 1; }

log_success "Systemd сервис $SYSTEMD_SERVICE_NAME успешно активирован и запущен. ✅"
log_info "Проверьте статус сервиса командой: systemctl status $SYSTEMD_SERVICE_NAME"
log_info "Просмотрите логи сервиса командой: journalctl -u $SYSTEMD_SERVICE_NAME -f"

log_info "Установка SSH Watcher завершена."