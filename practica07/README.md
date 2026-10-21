# Practica 07 DynamoDB CRUD

## Patrones de acceso definidos antes del diseno

1. Dado un curso, listar sus documentos del mas reciente al mas antiguo.
2. Dado un curso y un documento, obtener su metadata exacta.
3. Dado un curso, consultar solamente sus materiales usando el prefijo `DOCUMENTO#`.

## Claves

- Clave de particion `pk`: `CURSO#<curso_id>`.
- Clave de ordenamiento `sk`: `DOCUMENTO#<fecha_iso>#<documento_id>`.

La particion agrupa los documentos que se consultan juntos. La fecha al inicio de la clave de
ordenamiento permite ordenar sin recorrer toda la tabla, y el identificador evita colisiones.

## Ejecucion

Los scripts usan el proveedor de credenciales predeterminado de AWS. En EC2 obtienen credenciales
temporales del rol de instancia; no contienen llaves de acceso. La version Bash permite ejecutar
la practica en una AMI minima sin instalar dependencias adicionales.

```bash
export DYNAMODB_TABLE=repositorio-escolar-documentos-p07
export AWS_REGION=us-east-1
python3 dynamodb_crud.py
# Alternativa sin dependencias adicionales:
bash dynamodb_crud.sh
```

El flujo crea datos ficticios, inserta un documento, consulta por clave, actualiza el documento,
ejecuta intencionalmente un `Scan` ineficiente y elimina el documento temporal.
