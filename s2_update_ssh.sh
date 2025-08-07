#!/usr/bin/bash

# Скрипт для настройки SSH и создания пользователя 'github' в Debian 12.
# Предполагается, что скрипт запускается от имени root.
# Использование: ./update_ssh.sh YOUR_GITHUB_USER_PASSWORD

# --- Переменные (ЗАМЕНИТЕ ВАШИМИ ЗНАЧЕНИЯМИ, КРОМЕ GITHUB_USER_PASSWORD!) ---
# Пароль для пользователя 'github' будет передан как первый аргумент скрипта.
GITHUB_USER_PASSWORD="$1"

# Массив публичных SSH-ключей для root. Добавляйте новые ключи в кавычках через пробел.
SSH_PUB_KEYS_ROOT=(
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVdoS7JOTQgmdnD9SS0Mn7MmmdqkR0jTgBDIuSqxrHy badnigga66@yahoo.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICuhznZtRZq8UQStHuDWiGUgEqX8zTBsxUDlQ/bZkdhJ ps@DESKTOP-1VAP4EA" # Пример второго ключа
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDKMTJHO7HOKNsnwnyLRpaRNy3F9IpRVjx3XbPYEis7Tdj9r0slvERfhkV3q/bV09kIus/gHMH2tXGKOO2JzCDMpPUWR/em/eN8j/hpTwlPJLO6rH56goy1Ylev67Y/k6mEwgR1+yw5WipuVBdlqJjtVziUl8o9PSQYXSlxXK0pjTdAV+eNw2da4dwZXtjcB38YIje941ROOa4xS3A6uynuEEACC31UMHQ/H8PJFK+LwfSG+boND/TWBc4YqtXio9y3hKI14el9hKt+xhkkqVlRkaIt1g3wFElcMZsd3A8hkCCNvZaDIkhsHgGMt03aWKt2ycakuvCkCTa0BDxOfINLWajac4RmnJ/BX5r2qO9BPUhJ4YjdkYpn7Hlpbm4FcbdOSgMfpHVmuW05U+BvArtnNNRPCQtuO97uWMeLgkhjDoavyWAk6kdkq0rrDUk+M+eOK80c8w3gJkQ41L/KAbQe+oHjWLiKwvDnLj1yvDVsep615axlmpAAvy5FPDdB9sBZzP6CkyUbiebB7UxZVC0JUlkba7C1emzv/k2+2yjSwCFK+Ni1sOdrsklkv7/MHuF626QI6/FlmEPQlvbFSDdJhwTzD0mcdEAakeVkS1Q2maAMCFwzDqj50lyPP62pumtM/wClLii772Nl52mzQO/GFMQny7uXyBNqu4EWvO4a6w== server" # Пример второго ключа
)

# Массив публичных SSH-ключей для пользователя 'github'. Добавляйте новые ключи в кавычках через пробел.
SSH_PUB_KEYS_GITHUB=(
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJVdoS7JOTQgmdnD9SS0Mn7MmmdqkR0jTgBDIuSqxrHy badnigga66@yahoo.com"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICuhznZtRZq8UQStHuDWiGUgEqX8zTBsxUDlQ/bZkdhJ ps@DESKTOP-1VAP4EA" # Пример второго ключа
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDKMTJHO7HOKNsnwnyLRpaRNy3F9IpRVjx3XbPYEis7Tdj9r0slvERfhkV3q/bV09kIus/gHMH2tXGKOO2JzCDMpPUWR/em/eN8j/hpTwlPJLO6rH56goy1Ylev67Y/k6mEwgR1+yw5WipuVBdlqJjtVziUl8o9PSQYXSlxXK0pjTdAV+eNw2da4dwZXtjcB38YIje941ROOa4xS3A6uynuEEACC31UMHQ/H8PJFK+LwfSG+boND/TWBc4YqtXio9y3hKI14el9hKt+xhkkqVlRkaIt1g3wFElcMZsd3A8hkCCNvZaDIkhsHgGMt03aWKt2ycakuvCkCTa0BDxOfINLWajac4RmnJ/BX5r2qO9BPUhJ4YjdkYpn7Hlpbm4FcbdOSgMfpHVmuW05U+BvArtnNNRPCQtuO97uWMeLgkhjDoavyWAk6kdkq0rrDUk+M+eOK80c8w3gJkQ41L/KAbQe+oHjWLiKwvDnLj1yvDVsep615axlmpAAvy5FPDdB9sBZzP6CkyUbiebB7UxZVC0JUlkba7C1emzv/k2+2yjSwCFK+Ni1sOdrsklkv7/MHuF626QI6/FlmEPQlvbFSDdJhwTzD0mcdEAakeVkS1Q2maAMCFwzDqj50lyPP62pumtM/wClLii772Nl52mzQO/GFMQny7uXyBNqu4EWvO4a6w== server" # Пример второго ключа
)

NEW_SSH_PORT=60000 # Новый порт SSH

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
if [ -z "$GITHUB_USER_PASSWORD" ]; then
    log_error "Использование: $0 <ПАРОЛЬ_ДЛЯ_GITHUB_ЮЗЕРА>"
    log_error "Пример: sudo ./update_ssh.sh MyStrongPassword123!"
    exit 1
fi

log_info "Начинаем настройку системы Debian 12."

# --- 1. Добавление пользователя 'github' ---
log_info "1/5: Добавляем пользователя 'github'..."
if id "github" &>/dev/null; then
    log_info "Пользователь 'github' уже существует. Пропускаем создание."
else
    # Создаем пользователя с домашней директорией и оболочкой по умолчанию
    useradd -m -s /bin/bash github || { log_error "Ошибка при создании пользователя 'github'."; exit 1; }
    # Устанавливаем пароль для пользователя 'github'
    echo "github:$GITHUB_USER_PASSWORD" | chpasswd || { log_error "Ошибка при установке пароля для 'github'."; exit 1; }
    log_success "Пользователь 'github' добавлен и пароль установлен. ✅"
fi

# --- 2. Добавление SSH-ключей ---
log_info "2/5: Настраиваем authorized_keys для пользователей root и github..."

# Для пользователя root
ROOT_SSH_DIR="/root/.ssh"
ROOT_AUTHORIZED_KEYS="$ROOT_SSH_DIR/authorized_keys"
mkdir -p "$ROOT_SSH_DIR" || { log_error "Не удалось создать директорию $ROOT_SSH_DIR."; exit 1; }
chmod 700 "$ROOT_SSH_DIR" || { log_error "Не удалось установить права для $ROOT_SSH_DIR."; exit 1; }

# Добавляем каждый ключ из массива для root
for key in "${SSH_PUB_KEYS_ROOT[@]}"; do
    if grep -qF "$key" "$ROOT_AUTHORIZED_KEYS" 2>/dev/null; then
        log_info "Публичный SSH-ключ для root (частично: ${key:0:40}...) уже существует."
    else
        echo "$key" >> "$ROOT_AUTHORIZED_KEYS" || { log_error "Ошибка при добавлении ключа для root: $key"; exit 1; }
        log_success "Публичный SSH-ключ добавлен для root (частично: ${key:0:40}...).🔑"
    fi
done
chmod 600 "$ROOT_AUTHORIZED_KEYS" || { log_error "Не удалось установить права для $ROOT_AUTHORIZED_KEYS."; exit 1; }

# Для пользователя github
GITHUB_SSH_DIR="/home/github/.ssh"
GITHUB_AUTHORIZED_KEYS="$GITHUB_SSH_DIR/authorized_keys"
mkdir -p "$GITHUB_SSH_DIR" || { log_error "Не удалось создать директорию $GITHUB_SSH_DIR."; exit 1; }
chown github:github "$GITHUB_SSH_DIR" || { log_error "Не удалось сменить владельца $GITHUB_SSH_DIR."; exit 1; }
chmod 700 "$GITHUB_SSH_DIR" || { log_error "Не удалось установить права для $GITHUB_SSH_DIR."; exit 1; }

# Добавляем каждый ключ из массива для github
for key in "${SSH_PUB_KEYS_GITHUB[@]}"; do
    if grep -qF "$key" "$GITHUB_AUTHORIZED_KEYS" 2>/dev/null; then
        log_info "Публичный SSH-ключ для github (частично: ${key:0:40}...) уже существует."
    else
        echo "$key" >> "$GITHUB_AUTHORIZED_KEYS" || { log_error "Ошибка при добавлении ключа для github: $key"; exit 1; }
        log_success "Публичный SSH-ключ добавлен для пользователя 'github' (частично: ${key:0:40}...).🔑"
    fi
done
chown github:github "$GITHUB_AUTHORIZED_KEYS" || { log_error "Не удалось сменить владельца $GITHUB_AUTHORIZED_KEYS."; exit 1; }
chmod 600 "$GITHUB_AUTHORIZED_KEYS" || { log_error "Не удалось установить права для $GITHUB_AUTHORIZED_KEYS."; exit 1; }

# --- 3. Изменение дефолтного SSH порта ---
log_info "3/5: Меняем дефолтный SSH порт на $NEW_SSH_PORT..."
SSH_CONFIG="/etc/ssh/sshd_config"
cp "$SSH_CONFIG" "$SSH_CONFIG.bak_$(date +%Y%m%d%H%M%S)" || { log_error "Не удалось создать резервную копию sshd_config."; exit 1; }

# Проверяем, есть ли уже строка Port. Если да, заменяем. Если нет, добавляем.
if grep -qE "^[[:space:]]*Port[[:space:]]+[0-9]+" "$SSH_CONFIG"; then
    sed -i "s/^[[:space:]]*Port[[:space:]]+.*/Port $NEW_SSH_PORT/" "$SSH_CONFIG" || { log_error "Ошибка при изменении порта SSH."; exit 1; }
else
    # Если строка Port не найдена, добавляем ее в конец файла
    echo "Port $NEW_SSH_PORT" >> "$SSH_CONFIG" || { log_error "Ошибка при добавлении порта SSH."; exit 1; }
fi
log_success "SSH порт изменен на $NEW_SSH_PORT. 🚪"

# --- 4. Отключение возможности подключения через root с паролем ---
log_info "4/5: Отключаем возможность подключения через root с паролем..."

# PermitRootLogin prohibit-password
if grep -qE "^[[:space:]]*PermitRootLogin[[:space:]]+(yes|prohibit-password|without-password)" "$SSH_CONFIG"; then
    sed -i "s/^[[:space:]]*PermitRootLogin.*/PermitRootLogin prohibit-password/" "$SSH_CONFIG" || { log_error "Ошибка при изменении PermitRootLogin."; exit 1; }
else
    echo "PermitRootLogin prohibit-password" >> "$SSH_CONFIG" || { log_error "Ошибка при добавлении PermitRootLogin."; exit 1; }
fi

# PasswordAuthentication no (это относится ко всем пользователям, отключая вход по паролю для всех)
if grep -qE "^[[:space:]]*PasswordAuthentication[[:space:]]+(yes|no)" "$SSH_CONFIG"; then
    sed -i "s/^[[:space:]]*PasswordAuthentication.*/PasswordAuthentication no/" "$SSH_CONFIG" || { log_error "Ошибка при изменении PasswordAuthentication."; exit 1; }
else
    echo "PasswordAuthentication no" >> "$SSH_CONFIG" || { log_error "Ошибка при добавлении PasswordAuthentication."; exit 1; }
fi

log_success "Подключение через root с паролем отключено. Вход только по ключу. 🚫🔑"

# --- 5. Перезапуск SSH-сервиса ---
log_info "5/5: Перезапускаем SSH-сервис для применения изменений..."
systemctl restart ssh.service || { log_error "Ошибка при перезапуске SSH-сервиса. Проверьте конфигурацию!"; exit 1; }
log_success "SSH-сервис успешно перезапущен. ✅"

log_success "Все настройки успешно применены. Пожалуйста, убедитесь, что вы можете подключиться по новому порту ($NEW_SSH_PORT) с помощью SSH-ключа, прежде чем закрывать текущую сессию!"

log_info "Скрипт завершил работу."