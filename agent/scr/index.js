import express from 'express';
import mqtt from 'mqtt';

const app = express();
const port = process.env.PORT || 8080;
const mqttUrl = process.env.MQTT_URL || 'mqtt://mosquitto:1883';
const client = mqtt.connect(mqttUrl);

client.on('connect', () => {
  console.log('[agent] connected to MQTT', mqttUrl);
  client.publish('agent/hello', JSON.stringify({ ts: Date.now() }));
});

client.on('error', (err) => {
  console.error('[agent] mqtt error', err.message);
});

app.get('/health', (req, res) => {
  res.json({ ok: true, ts: Date.now() });
});

app.listen(port, () => console.log(`[agent] HTTP on ${port}`));
