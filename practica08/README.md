# Práctica 08 - Alta disponibilidad

Arquitectura del Repositorio escolar con un Application Load Balancer y un grupo de escalamiento distribuido en `us-east-1a` y `us-east-1b`.

## Parámetros verificados

- Plantilla de lanzamiento con Amazon Linux 2023, `t3.micro`, perfil de instancia y configuración automática mediante `user-data.sh`.
- Grupo de escalamiento: mínimo 2, deseado 2 y máximo 4 durante la prueba.
- Verificación de estado: `GET /health`, intervalo de 10 segundos, dos aciertos para estado sano y dos fallos para retirar un destino.
- Política de seguimiento de objetivo: CPU promedio de 50 %, con calentamiento de 120 segundos.
- El grupo de seguridad de las instancias permite HTTP únicamente desde el grupo de seguridad del balanceador.

## Justificación del umbral

El objetivo de 50 % de CPU conserva margen para absorber aumentos repentinos de demanda antes de que una instancia se sature. También evita escalar por picos breves y deja que el grupo reduzca capacidad cuando la carga vuelve a niveles normales.

## Resultado verificado

- El balanceador respondió desde `i-044d08e9d2a49c7dd` en `us-east-1a` y `i-043b19cfd07a3f4dd` en `us-east-1b`.
- La terminación controlada de `i-044d08e9d2a49c7dd` inició el `2026-10-22T05:09:42Z`.
- Durante el reemplazo, el balanceador continuó respondiendo desde `i-043b19cfd07a3f4dd`.
- Auto Scaling creó `i-0edc79c2ac4aedb43` y recuperó dos destinos sanos en 72 segundos.
- Al finalizar se dejó el grupo en mínimo 1, deseado 1 y máximo 4, con `i-0edc79c2ac4aedb43` en estado `InService` y `Healthy`.

## Archivos

- `crear-alta-disponibilidad.sh`: crea los grupos de seguridad, la plantilla, el grupo destino, el balanceador, el grupo de escalamiento y la política de CPU.
- `user-data.sh`: instala Apache y publica una página que muestra el identificador de instancia y la zona de disponibilidad.
- `reducir-costos.sh`: deja el grupo en una instancia al terminar la práctica y muestra el estado final.
