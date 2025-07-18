#!/bin/bash

export DEBIAN_FRONTEND=noninteractive

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

# --- Переменные конфигурации ---
NODE_EXPORTER_VERSION="1.7.0" # Проверьте последнюю версию на GitHub
NODE_EXPORTER_ARCH="linux-amd64"
NODE_EXPORTER_PORT="9000" # Локальный порт для прослушивания

# --- Проверка прав root ---
if [[ $EUID -ne 0 ]]; then
   log_error "Этот скрипт должен быть запущен от имени root."
   exit 1
fi

log_info "Начинаем установку Node Exporter версии ${NODE_EXPORTER_VERSION}."

# --- 1. Проверка наличия Node Exporter ---
if systemctl is-active --quiet node_exporter; then
    log_info "Node Exporter уже установлен и запущен. Пропускаем установку."
    log_success "Node Exporter готов к работе на порту ${NODE_EXPORTER_PORT} с заданными метриками."
    exit 0
fi

# --- 2. Установка необходимых зависимостей ---
log_info "Шаг 1/5: Обновление списка пакетов и установка зависимостей..."
apt update -y || { log_error "Ошибка при apt update."; exit 1; }
apt install -y curl wget || { log_error "Ошибка при установке curl/wget."; exit 1; }

# --- 3. Создание пользователя и группы для Node Exporter ---
log_info "Шаг 2/5: Создание пользователя и группы 'node_exporter'..."
if ! id "node_exporter" &>/dev/null; then
    useradd --no-create-home --shell /bin/false node_exporter || { log_error "Ошибка при создании пользователя node_exporter."; exit 1; }
    log_info "Пользователь 'node_exporter' создан."
else
    log_info "Пользователь 'node_exporter' уже существует."
fi

# --- 4. Загрузка и установка Node Exporter ---
log_info "Шаг 3/5: Загрузка и распаковка Node Exporter..."
NODE_EXPORTER_TARBALL="node_exporter-${NODE_EXPORTER_VERSION}.${NODE_EXPORTER_ARCH}.tar.gz"
NODE_EXPORTER_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/${NODE_EXPORTER_TARBALL}"

wget -q "${NODE_EXPORTER_URL}" -O "/tmp/${NODE_EXPORTER_TARBALL}" || { log_error "Ошибка при загрузке Node Exporter с ${NODE_EXPORTER_URL}. Проверьте версию или URL."; exit 1; }
tar xvfz "/tmp/${NODE_EXPORTER_TARBALL}" -C /tmp/ || { log_error "Ошибка при распаковке Node Exporter."; exit 1; }

log_info "Копирование исполняемого файла Node Exporter в /usr/local/bin..."
cp "/tmp/node_exporter-${NODE_EXPORTER_VERSION}.${NODE_EXPORTER_ARCH}/node_exporter" /usr/local/bin/ || { log_error "Ошибка при копировании исполняемого файла."; exit 1; }
chown node_exporter:node_exporter /usr/local/bin/node_exporter || { log_error "Ошибка при изменении владельца файла."; exit 1; }

# --- 5. Настройка Systemd сервиса ---
log_info "Шаг 4/5: Создание Systemd сервиса для Node Exporter..."

NODE_EXPORTER_SERVICE_CONFIG="/etc/systemd/system/node_exporter.service"

cat <<EOF > "${NODE_EXPORTER_SERVICE_CONFIG}"
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter \
  --web.listen-address="127.0.0.1:${NODE_EXPORTER_PORT}" \
  --collector.disable-defaults \
  --collector.cpu \
  --collector.filesystem \
  --collector.meminfo \
  --collector.netdev
Restart=always
RestartSec=5s

[Install]
WantedBy=multi-user.target
EOF

chown root:root "${NODE_EXPORTER_SERVICE_CONFIG}" || { log_error "Ошибка при изменении владельца service файла."; exit 1; }
chmod 644 "${NODE_EXPORTER_SERVICE_CONFIG}" || { log_error "Ошибка при изменении прав service файла."; exit 1; }

# --- 6. Запуск и активация сервиса Node Exporter ---
log_info "Шаг 5/5: Перезагрузка Systemd, запуск и активация Node Exporter..."
systemctl daemon-reload || { log_error "Ошибка при daemon-reload."; exit 1; }
systemctl start node_exporter || { log_error "Ошибка при запуске Node Exporter."; exit 1; }
systemctl enable node_exporter || { log_error "Ошибка при включении Node Exporter в автозагрузку."; exit 1; }

# --- 7. Проверка статуса ---
if systemctl is-active --quiet node_exporter; then
    log_success "Node Exporter успешно установлен и запущен на 127.0.0.1:${NODE_EXPORTER_PORT}."
    log_info "Собираемые метрики: CPU, Filesystem, Memory, Network."
    log_info "Метрики доступны по адресу: http://127.0.0.1:${NODE_EXPORTER_PORT}/metrics"
else
    log_error "Node Exporter не запущен. Проверьте логи: journalctl -u node_exporter -f"
    exit 1
fi

# --- Очистка временных файлов ---
log_info "Удаление временных файлов..."
rm -f "/tmp/${NODE_EXPORTER_TARBALL}"
rm -rf "/tmp/node_exporter-${NODE_EXPORTER_VERSION}.${NODE_EXPORTER_ARCH}"

log_info "Скрипт завершил работу."