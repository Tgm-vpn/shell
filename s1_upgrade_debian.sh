#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

# Скрипт для обновления Debian 11 до Debian 12
# и выполнения apt update/upgrade для Debian 12.
# Предназначен для запуска через asyncssh.

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

log_info "Начинаем процесс проверки и обновления Debian."

# --- Определение версии Debian ---
DEBIAN_VERSION=$(lsb_release -rs)
log_info "Текущая версия Debian: $DEBIAN_VERSION"

# --- Логика обновления ---
if [[ "$DEBIAN_VERSION" == "11" ]]; then
    log_info "Обнаружена Debian 11. Начинаем процесс обновления до Debian 12 (Bookworm)."
    log_info "Убедитесь, что у вас есть резервная копия данных!"
    log_info "Будьте готовы к интерактивным вопросам во время обновления."

    # 1. Обновляем существующие пакеты Debian 11
    log_info "Шаг 1/5: Обновляем существующие пакеты Debian 11..."
    apt update || { log_error "Ошибка при apt update для Debian 11."; exit 1; }
    apt upgrade -y || { log_error "Ошибка при apt upgrade для Debian 11."; exit 1; }
    apt full-upgrade -y || { log_error "Ошибка при apt full-upgrade для Debian 11."; exit 1; }
    apt autoremove -y || { log_error "Ошибка при apt autoremove для Debian 11."; exit 1; }
    apt clean || { log_error "Ошибка при apt clean для Debian 11."; exit 1; }

    # 2. Обновляем /etc/apt/sources.list
    log_info "Шаг 2/5: Обновляем /etc/apt/sources.list на 'bookworm'..."
    # Создаем резервную копию
    cp /etc/apt/sources.list /etc/apt/sources.list.bak_$(date +%Y%m%d%H%M%S) || { log_error "Не удалось создать резервную копию sources.list."; exit 1; }
    # Заменяем 'bullseye' на 'bookworm' и 'bullseye/updates' на 'bookworm-security'
    sed -i 's/bullseye/bookworm/g' /etc/apt/sources.list || { log_error "Не удалось заменить 'bullseye' на 'bookworm' в sources.list."; exit 1; }
    sed -i 's/bullseye\/updates/bookworm-security/g' /etc/apt/sources.list || { log_error "Не удалось заменить 'bullseye/updates' на 'bookworm-security' в sources.list."; exit 1; }

    # Добавляем bookworm-updates, если его нет (для минорных обновлений)
    if ! grep -q "bookworm-updates" /etc/apt/sources.list; then
        log_info "Добавляем 'bookworm-updates' в sources.list..."
        echo "deb http://deb.debian.org/debian bookworm-updates main contrib non-free" >> /etc/apt/sources.list
    fi

    # Удаляем строки, содержащие `security.debian.org/debian-security` с `bullseye`
    sed -i '/bullseye\/updates/d' /etc/apt/sources.list

    log_info "Содержимое /etc/apt/sources.list после изменений:"
    cat /etc/apt/sources.list

    # 3. Выполняем первое обновление до новой версии
    log_info "Шаг 3/5: Выполняем первое обновление с новыми источниками..."
    apt update || { log_error "Ошибка при apt update после изменения sources.list."; exit 1; }
    apt upgrade -y --without-new-pkgs || { log_error "Ошибка при apt upgrade --without-new-pkgs."; exit 1; }

    # 4. Выполняем полное обновление дистрибутива
    log_info "Шаг 4/5: Выполняем полное обновление дистрибутива (apt full-upgrade)..."
    log_info "Этот шаг может занять много времени и потребует внимания к запросам."
    apt full-upgrade -y || { log_error "Ошибка при apt full-upgrade до Debian 12."; exit 1; }

    # 5. Очистка устаревших пакетов
    log_info "Шаг 5/5: Очистка устаревших пакетов и зависимостей..."
    apt autoremove -y || { log_error "Ошибка при apt autoremove после обновления."; exit 1; }
    apt clean || { log_error "Ошибка при apt clean после обновления."; exit 1; }

    log_success "Обновление до Debian 12 завершено. Система НЕ БУДЕТ перезагружена автоматически. ПЕРЕЗАГРУЗИТЕ СИСТЕМУ ВРУЧНУЮ КАК МОЖНО СКОРЕЕ!"

elif [[ "$DEBIAN_VERSION" == "12" ]]; then
    log_info "Обнаружена Debian 12. Выполняем стандартное обновление пакетов."
    apt update || { log_error "Ошибка при apt update для Debian 12."; exit 1; }
    apt upgrade -y || { log_error "Ошибка при apt upgrade для Debian 12."; exit 1; }
    apt autoremove -y || { log_error "Ошибка при apt autoremove для Debian 12."; exit 1; }
    apt clean || { log_error "Ошибка при apt clean для Debian 12."; exit 1; }
    log_success "Обновление пакетов Debian 12 завершено. Система НЕ БУДЕТ перезагружена автоматически. Если обновлялось ядро, РЕКОМЕНДУЕТСЯ перезагрузка."

else
    log_error "Неизвестная или неподдерживаемая версия Debian: $DEBIAN_VERSION. Скрипт предназначен для Debian 11 или 12."
    exit 1
fi

log_info "Скрипт завершил работу."