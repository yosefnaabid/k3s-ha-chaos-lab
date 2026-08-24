// SIMULACRO 3. Pico de carga hasta disparar el autoescalado.
// El endpoint /delay/1 de podinfo consume CPU y tiempo por peticion.
//
// Uso:  k6 run --vus 50 --duration 5m drill3-load.js
// Mientras corre:  watch kubectl -n podinfo get hpa,pods
// En Grafana, la grafica de replicas frente a latencia p95 es la captura 7.
import http from 'k6/http';
import { sleep } from 'k6';

export const options = {
  stages: [
    { duration: '1m', target: 10 },   // calentamiento
    { duration: '3m', target: 50 },   // pico sostenido, el HPA debe pasar de 3 a 6
    { duration: '1m', target: 0 },    // enfriamiento, las replicas vuelven solas
  ],
  thresholds: {
    http_req_duration: ['p(95)<2000'],
  },
};

const BASE = __ENV.TARGET || 'https://app.lab.yosefnaabid.com';

export default function () {
  http.get(`${BASE}/delay/1`);
  sleep(0.1);
}
