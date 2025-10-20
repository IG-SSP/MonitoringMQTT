# iot-stack (Raspberry Pi/Wirenboard)

Стек: MQTT брокер (Eclipse Mosquitto) + field-agent (Node.js, Express + MQTT).
Разворачивается одной командой на Raspberry Pi / Wirenboard.

## Быстрый старт

```bash
git clone <ВАШ_URL_РЕПО> iot-stack
cd iot-stack
sudo ./install.sh


## Проверка
curl http://localhost:8080/health
docker compose ps

## Повседневные команды
docker compose up -d --build
docker compose logs -f field-agent
docker compose logs -f mosquitto
docker compose ps

## Автозапуск
systemctl status iot-stack
systemctl restart iot-stack