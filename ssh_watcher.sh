#!/usr/bin/bash

# Скрипт для мониторинга SSH-подключений и отправки уведомлений в Telegram.
# Уведомления отправляются только для подключений пользователя 'root'.
# Размещается в /usr/local/bin/ssh_watcher.sh

# --- Конфигурация Telegram ---
# BOT_TOKEN теперь будет установлен install_ssh_watcher.sh
# CHAT_ID_1 и CHAT_ID_2 остаются здесь
CHAT_ID_1="630035569" # ID первого чата/пользователя Telegram
CHAT_ID_2="459359171" # ID второго чата/пользователя Telegram

# --- Системные переменные ---
SERVER_IP=$(hostname -I | awk '{print $1}')
HOSTNAME=$(hostname)
CACHE_FILE="/tmp/ssh_login_cache.txt" # Файл для кэширования последних уведомлений
MAX_AGE=60  # Время в секундах, в течение которого повторные подключения одного и того же USER/IP/METHOD будут игнорироваться

# --- Функции логирования (для отладки, если запуск через systemd) ---
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [SSH_WATCHER] $1" >> /var/log/ssh_watcher.log
}

# --- Основной скрипт ---

# Проверяем, что BOT_TOKEN установлен (это будет сделано скриптом инсталляции)
if [ -z "$BOT_TOKEN" ]; then
    log_message "ERROR: BOT_TOKEN is not set. Exiting."
    exit 1
fi

# Убедимся, что файл кэша существует
touch "$CACHE_FILE" || { log_message "ERROR: Cannot create cache file $CACHE_FILE. Exiting."; exit 1; }

log_message "Starting SSH Watcher..."

# Мониторим /var/log/auth.log в реальном времени
tail -Fn0 /var/log/auth.log | \
while read line; do
    # Проверяем строки, указывающие на успешное SSH-подключение
    if echo "$line" | grep -q "sshd.*Accepted"; then
        USER=$(echo "$line" | awk '{for (i=1;i<=NF;i++) if ($i=="for") print $(i+1)}')
        IP=$(echo "$line" | awk '{for (i=1;i<=NF;i++) if ($i=="from") print $(i+1)}')
        METHOD="неизвестно"

        # Определяем метод аутентификации
        if echo "$line" | grep -q "password"; then
            METHOD="по паролю"
        elif echo "$line" | grep -q "publickey"; then
            METHOD="по ключу"
        fi

        # Фильтрация по пользователю root
        if [ "$USER" != "root" ]; then
            continue # Пропускаем, если пользователь не root
        fi

        TIME_FORMATTED=$(date "+%Y-%m-%d %H:%M:%S")

        # Уникальный ключ для кэша: пользователь|IP|метод
        CACHE_KEY="$USER|$IP|$METHOD"

        # Проверяем кэш для предотвращения спама
        LAST_TIME_EPOCH=$(grep "^$CACHE_KEY|" "$CACHE_FILE" | tail -n 1 | awk -F'|' '{print $4}')
        CURRENT_TIME_EPOCH=$(date +%s)

        if [[ -n "$LAST_TIME_EPOCH" && $(("$CURRENT_TIME_EPOCH" - "$LAST_TIME_EPOCH")) -lt "$MAX_AGE" ]]; then
            log_message "Skipping duplicate notification for $CACHE_KEY (last sent $LAST_TIME_EPOCH seconds ago)."
            continue # Пропускаем, если уведомление недавно отправлялось
        fi

        # Обновляем кэш: добавляем новую запись
        echo "$CACHE_KEY|$CURRENT_TIME_EPOCH" >> "$CACHE_FILE"

        MESSAGE="🔐 *SSH-подключение ROOT*
👤 Пользователь: \`$USER\`
📡 Сервер: \`$HOSTNAME\` (\`$SERVER_IP\`)
🌍 IP клиента: \`$IP\`
🛠 Метод: *$METHOD*
🕓 Время: \`$TIME_FORMATTED\`"

        # Отправка уведомления в Telegram (чат 1)
        curl -s -o /dev/null -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
            -d chat_id="$CHAT_ID_1" \
            -d text="$MESSAGE" \
            -d parse_mode="Markdown" \
            --connect-timeout 10 # Добавлен таймаут для curl

        # Отправка уведомления в Telegram (чат 2)
        if [ -n "$CHAT_ID_2" ]; then # Проверяем, что второй CHAT_ID не пустой
            curl -s -o /dev/null -X POST "https://api.telegram.org/bot$BOT_TOKEN/sendMessage" \
                -d chat_id="$CHAT_ID_2" \
                -d text="$MESSAGE" \
                -d parse_mode="Markdown" \
                --connect-timeout 10
        fi

        log_message "Sent notification for user $USER from IP $IP via $METHOD."
    fi
done