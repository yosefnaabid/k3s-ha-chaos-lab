# Los cuatro simulacros

Cada simulacro recrea un incidente real y sale con una cifra. Ejecuta cada uno dos veces, la primera para descubrir lo que falla y la segunda para medir. La evidencia curada (logs, capturas y cifras) vive en docs/evidence.md

| Simulacro | Incidente que recrea | Script | Cifra que produce |
|---|---|---|---|
| 1 | Muere un nodo a las 3 de la manana | drill1-node-death.sh + monitor.sh | Segundos de degradacion y tiempo de failover de PostgreSQL |
| 2 | Despliegue roto un viernes | drill2-broken-deploy.sh + monitor.sh | Downtime del ciclo romper y revertir, objetivo cero |
| 3 | Pico de carga | drill3-load.js (k6) | Replicas de 3 a 6 y latencia p95 estable |
| 4 | Perdida total | drill4-total-loss.sh | Minutos hasta que TODO vuelve desde Git y copias |

El monitor se arranca siempre en una terminal aparte antes de romper nada. Al cortarlo con Ctrl+C imprime el resumen de huecos que va directo al README.
