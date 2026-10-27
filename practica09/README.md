# Practica 09 - API serverless del Repositorio Escolar

Esta practica implementa una consulta publica y de solo lectura para listar los documentos de un curso del Repositorio Escolar.

## Arquitectura

- Amazon API Gateway HTTP API recibe `GET /repositorio-escolar-consultar-documentos-p09?curso=AWS-101`.
- AWS Lambda ejecuta `lambda_function.lambda_handler` con Python 3.14, 128 MB y 3 segundos de timeout.
- Amazon DynamoDB responde desde la tabla `repositorio-escolar-documentos-p07` mediante una operacion `Query`.
- El rol de ejecucion solo permite escribir bitacoras y ejecutar `dynamodb:Query` sobre esa tabla.

## Archivos

- `lambda_function.py`: codigo desplegado en Lambda.
- `evento_prueba.json`: evento usado para la prueba desde la consola.

## Endpoint verificado

`https://cwzxjwslv8.execute-api.us-east-1.amazonaws.com/default/repositorio-escolar-consultar-documentos-p09?curso=AWS-101`

La respuesta verificada contiene `statusCode 200` y cinco documentos. La interfaz esta abierta sin autenticacion para fines academicos; antes de una entrega productiva debe protegerse con autenticacion y limites de consumo.

## Mediciones

| Estado | Duracion | Duracion facturada | Inicializacion | Memoria maxima |
|---|---:|---:|---:|---:|
| Arranque en frio | 295.89 ms | 779 ms | 482.99 ms | 93 MB |
| Invocacion inmediata | 29.31 ms | 30 ms | No aplica | 93 MB |

## Precios consultados

- [AWS Lambda Pricing](https://aws.amazon.com/lambda/pricing/)
- [Amazon API Gateway Pricing](https://aws.amazon.com/api-gateway/pricing/)
- [AWS Prescriptive Guidance - t3.micro en us-east-1](https://docs.aws.amazon.com/prescriptive-guidance/latest/optimize-costs-microsoft-workloads/right-size-selection.html)

