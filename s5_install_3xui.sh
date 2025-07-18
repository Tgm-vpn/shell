#!/bin/bash

# Скрипт для установки и настройки 3x-ui в Debian 12.
# Предполагается, что скрипт запускается от имени root.
# Использование: ./install_3xui.sh <ПАРОЛЬ_ДЛЯ_3XUI_ROOT>

# --- Переменные ---
# Пароль для пользователя 'root' в 3x-ui будет передан как первый аргумент скрипта.
THREEXUI_ROOT_PASSWORD="$1"

# Порт и адрес для 3x-ui
THREEXUI_LISTEN_ADDRESS="127.0.0.1"
THREEXUI_LISTEN_PORT="10000"
THREEXUI_USERNAME="root" # Имя пользователя по умолчанию

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
if [ -z "$THREEXUI_ROOT_PASSWORD" ]; then
    log_error "Использование: $0 <ПАРОЛЬ_ДЛЯ_3XUI_ROOT>"
    log_error "Пример: sudo ./install_3xui.sh My3XUIPassword123!"
    exit 1
fi

log_info "Начинаем установку и настройку 3x-ui. 🚀"

### 1. Обновление пакетов и установка необходимых утилит
log_info "1/4: Обновляем список пакетов и устанавливаем curl, git..."
apt update -y || { log_error "Ошибка при apt update."; exit 1; }
apt install -y curl git || { log_error "Ошибка при установке curl или git."; exit 1; }
log_success "Пакеты обновлены и утилиты установлены. ✅"

### 2. Скачивание и установка 3x-ui
log_info "2/4: Скачиваем и устанавливаем 3x-ui..."
# Проверяем, существует ли папка /opt/3x-ui
if [ -d "/opt/3x-ui" ]; then
    log_info "Директория /opt/3x-ui уже существует. Удаляем её для чистой установки..."
    rm -rf /opt/3x-ui || { log_error "Не удалось удалить существующую директорию /opt/3x-ui."; exit 1; }
fi

# Скачиваем скрипт установки 3x-ui
curl -sS -L https://raw.githubusercontent.com/MHSanaei/3x-ui/master/install.sh -o /tmp/install_3xui.sh || { log_error "Не удалось скачать установочный скрипт 3x-ui."; exit 1; }
chmod +x /tmp/install_3xui.sh || { log_error "Не удалось сделать установочный скрипт исполняемым."; exit 1; }

# Запускаем установочный скрипт 3x-ui с подавлением интерактивных запросов через 'yes n'
log_info "Запускаем установочный скрипт 3x-ui (ответы на интерактивные запросы будут 'n')."
yes n | /tmp/install_3xui.sh || { log_error "Ошибка при запуске установочного скрипта 3x-ui."; exit 1; }
log_success "3x-ui успешно скачан и установлен. ✅"

### 3. Настройка 3x-ui: адрес, порт и учетные данные
log_info "3/4: Настраиваем адрес, порт и учетные данные 3x-ui с помощью 'x-ui setting'..."

# Устанавливаем порт
log_info "Устанавливаем порт 3x-ui на $THREEXUI_LISTEN_PORT..."
/usr/local/x-ui/x-ui setting -port "$THREEXUI_LISTEN_PORT" || { log_error "Ошибка при установке порта 3x-ui."; exit 1; }
log_success "Порт 3x-ui установлен на $THREEXUI_LISTEN_PORT. 🌐"

# Устанавливаем адрес прослушивания
log_info "Устанавливаем адрес прослушивания 3x-ui на $THREEXUI_LISTEN_ADDRESS..."
/usr/local/x-ui/x-ui setting -listenIP "$THREEXUI_LISTEN_ADDRESS" || { log_error "Ошибка при установке адреса прослушивания 3x-ui."; exit 1; }
log_success "Адрес прослушивания 3x-ui установлен на $THREEXUI_LISTEN_ADDRESS. ✅"

# Устанавливаем WebBasePath
log_info "Устанавливаем WebBasePath на '/'..."
/usr/local/x-ui/x-ui setting -webBasePath "/" || { log_error "Ошибка при установке WebBasePath."; exit 1; }
log_success "WebBasePath установлен на '/'. ✅"

# Устанавливаем имя пользователя и пароль одной командой
log_info "Устанавливаем имя пользователя '$THREEXUI_USERNAME' и пароль одной командой..."
/usr/local/x-ui/x-ui setting -username "$THREEXUI_USERNAME" -password "$THREEXUI_ROOT_PASSWORD" || { log_error "Ошибка при установке имени пользователя и пароля."; exit 1; }
log_success "Пользователь '$THREEXUI_USERNAME' с новым паролем успешно добавлен/обновлен. 🔑"


### 4. Перезапуск 3x-ui сервиса
log_info "4/4: Перезапускаем 3x-ui сервис для применения изменений..."
systemctl restart x-ui || { log_error "Ошибка при перезапуске 3x-ui сервиса."; exit 1; }
log_success "3x-ui сервис успешно перезапущен. ✅"

log_info "Проверяем финальные настройки 3x-ui..."
/usr/local/x-ui/x-ui setting -show || { log_error "Не удалось отобразить финальные настройки 3x-ui."; }

log_info "Установка и настройка 3x-ui завершены. ✨"
log_info "3x-ui теперь доступен по адресу: http://$THREEXUI_LISTEN_ADDRESS:$THREEXUI_LISTEN_PORT"
log_info "Логин: $THREEXUI_USERNAME, Пароль: <ПАРОЛЬ_КОТОРЫЙ_ВЫ_ПЕРЕДАЛИ>"
log_info "Если вы не можете получить доступ, проверьте настройки файрвола (ufw или nftables)."

log_info "Скрипт завершил работу."