// SIMULACRO 3. Pico de carga hasta disparar el autoescalado.
//
// POR QUE NO SE USA /delay/1
// La primera version pegaba a /delay/1, que suena a carga pero no lo es: ese
// endpoint DUERME un segundo, no calcula nada. El HPA de este laboratorio
// escala por CPU, y un proceso dormido no gasta CPU, asi que el autoescalado
// no se enteraba de nada por mucho trafico que le echaras. Medido: 80 usuarios
// contra /delay/1 dejaban los pods a 3 milicores.
//
// /api/info si serializa una respuesta en cada peticion. Medido con la misma
// carga: de 3 milicores a entre 200 y 550 por pod, el HPA marcando 471 por
// ciento de su objetivo, y las replicas subiendo de 3 a 6.
//
// Uso:  k6 run drill3-load.js
// Mientras corre:  kubectl -n podinfo get hpa,pods
// En Grafana, el panel Laboratorio / Simulacros es la captura 7.
import http from 'k6/http';
import { check } from 'k6';

export const options = {
  stages: [
    { duration: '1m', target: 10 },   // calentamiento, el HPA no deberia moverse
    { duration: '3m', target: 60 },   // pico sostenido, tiene que pasar de 3 a 6
    { duration: '1m', target: 0 },    // enfriamiento, las replicas bajan solas
  ],
  thresholds: {
    // El objetivo no es que la latencia no suba nada, es que se mantenga en un
    // rango util mientras el cluster absorbe el pico anadiendo replicas.
    http_req_duration: ['p(95)<500'],
    http_req_failed: ['rate<0.01'],
  },
};

const BASE = __ENV.TARGET || 'https://app.lab.yosefnaabid.com';

export default function () {
  const r = http.get(`${BASE}/api/info`);
  check(r, { 'responde 200': (res) => res.status === 200 });
}
