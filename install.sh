
#!/usr/bin/env bash
set -euo pipefail

STACK_DIR="$(cd "$(dirname "$0")" && pwd)"
SERVICE_NAME="iot-stack"

log(){ echo "[*] $*"; }

require_root(){
  if [ "$(id -u)" -ne 0 ]; then
    echo "Запусти: sudo $0"; exit 1
  fi
}

ensure_packages(){
  log "Обновляем apt и ставим зависимости…"
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release
}

install_docker(){
  if ! command -v docker >/dev/null 2>&1; then
    log "Устанавливаем Docker CE…"
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"
    arch="$(dpkg --print-architecture)"
    echo "deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${codename} stable" > /etc/apt/sources.list.d/docker.list
    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    systemctl enable --now docker
    usermod -aG docker pi || true
  else
    log "Docker уже установлен: $(docker --version)"
    apt-get install -y docker-compose-plugin docker-buildx-plugin || true
    systemctl enable --now docker
    usermod -aG docker pi || true
  fi
  log "Проверяем docker compose v2…"
  docker compose version >/dev/null
}

prepare_dirs(){
  log "Подготавливаем каталоги…"
  mkdir -p "$STACK_DIR/mosquitto"/{data,log}
  chown -R pi:pi "$STACK_DIR"
}

ensure_env(){
  if [ ! -f "$STACK_DIR/.env" ]; then
    echo "[*] Создаю .env с дефолтами…"
    cat > "$STACK_DIR/.env" <<'EOF'
AGENT_PORT=8080
MOSQ_PORT=1883
NODE_ENV=production
EOF
    chown pi:pi "$STACK_DIR/.env" || true
  fi
}


compose_up(){
  log "Собираем и поднимаем стек…"
  (cd "$STACK_DIR" && docker compose up -d --build)
  docker compose -f "$STACK_DIR/docker-compose.yml" ps
}

write_systemd(){
  log "Прописываем systemd сервис…"
  local unit="/etc/systemd/system/${SERVICE_NAME}.service"
  cat > "$unit" <<EOF
[Unit]
Description=IoT stack (Mosquitto + Field Agent) via docker compose
Requires=docker.service
After=docker.service network-online.target
Wants=network-online.target

[Service]
Type=oneshot
WorkingDirectory=${STACK_DIR}
RemainAfterExit=yes
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=0

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now "${SERVICE_NAME}.service"
}

health(){
  log "Проверяем здоровье…"
  sleep 2
  if command -v curl >/dev/null 2>&1; then
    set +e
    curl -sf "http://127.0.0.1:8080/health" && echo || echo "HTTP health не ответил — смотри логи"
    set -e
  fi
  docker logs --tail=30 field-agent || true
  docker logs --tail=30 mosquitto || true
}

main(){
  require_root
  ensure_packages
  install_docker
  prepare_dirs
  ensure_env
  compose_up
  write_systemd
  health
  echo
  echo "Готово:"
  echo "- HTTP агент:  http://<ip>:8080/health"
  echo "- MQTT брокер: tcp://<ip>:1883"
  echo "- Автозапуск: systemctl status ${SERVICE_NAME}"
}
main "$@"
