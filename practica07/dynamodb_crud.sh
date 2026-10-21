#!/usr/bin/env bash
set -euo pipefail

TABLE_NAME="${DYNAMODB_TABLE:-repositorio-escolar-documentos-p07}"
REGION="${AWS_REGION:-us-east-1}"
PARTITION_KEY="CURSO#AWS-101"
TEMP_SORT_KEY="DOCUMENTO#2026-10-21T18:00:00Z#DOC-CRUD-001"

put_document() {
  local document_id="$1" created_at="$2" title="$3" status="$4" author="$5" size_kb="$6"
  aws dynamodb put-item --table-name "$TABLE_NAME" --region "$REGION" \
    --item "{\"pk\":{\"S\":\"$PARTITION_KEY\"},\"sk\":{\"S\":\"DOCUMENTO#$created_at#$document_id\"},\"documento_id\":{\"S\":\"$document_id\"},\"curso_id\":{\"S\":\"AWS-101\"},\"titulo\":{\"S\":\"$title\"},\"estado\":{\"S\":\"$status\"},\"autor\":{\"S\":\"$author\"},\"tamano_kb\":{\"N\":\"$size_kb\"}}" \
    --return-consumed-capacity TOTAL --output json >/dev/null
}

put_document "DOC-101" "2026-10-10T09:00:00Z" "Guia de alta disponibilidad" "publicado" "Diego Docente" "128"
put_document "DOC-102" "2026-10-11T10:00:00Z" "Practica de escalamiento" "publicado" "Diego Docente" "128"
put_document "DOC-103" "2026-10-12T11:00:00Z" "Diseno de la VPC" "publicado" "Diego Docente" "128"
put_document "DOC-104" "2026-10-13T12:00:00Z" "Modelo relacional" "borrador" "Diego Docente" "128"
put_document "DOC-105" "2026-10-14T13:00:00Z" "Seguridad de almacenamiento" "publicado" "Diego Docente" "128"

CREATE_OUTPUT=$(aws dynamodb put-item --table-name "$TABLE_NAME" --region "$REGION" \
  --item "{\"pk\":{\"S\":\"$PARTITION_KEY\"},\"sk\":{\"S\":\"$TEMP_SORT_KEY\"},\"documento_id\":{\"S\":\"DOC-CRUD-001\"},\"curso_id\":{\"S\":\"AWS-101\"},\"titulo\":{\"S\":\"Practica NoSQL CRUD\"},\"estado\":{\"S\":\"borrador\"},\"autor\":{\"S\":\"Edgar Rodriguez\"},\"tamano_kb\":{\"N\":\"96\"}}" \
  --condition-expression "attribute_not_exists(pk) AND attribute_not_exists(sk)" \
  --return-consumed-capacity TOTAL --query "ConsumedCapacity.CapacityUnits" --output text)
echo "CREATE OK | capacidad_consumida=$CREATE_OUTPUT"

QUERY_OUTPUT=$(aws dynamodb query --table-name "$TABLE_NAME" --region "$REGION" \
  --key-condition-expression "pk = :pk AND begins_with(sk, :prefix)" \
  --expression-attribute-values '{":pk":{"S":"CURSO#AWS-101"},":prefix":{"S":"DOCUMENTO#"}}' \
  --no-scan-index-forward --return-consumed-capacity TOTAL \
  --query "{Count:Count,ScannedCount:ScannedCount,Capacity:ConsumedCapacity.CapacityUnits,Documentos:Items[].documento_id.S}" --output json)
echo "QUERY OK | $QUERY_OUTPUT"

UPDATE_OUTPUT=$(aws dynamodb update-item --table-name "$TABLE_NAME" --region "$REGION" \
  --key "{\"pk\":{\"S\":\"$PARTITION_KEY\"},\"sk\":{\"S\":\"$TEMP_SORT_KEY\"}}" \
  --update-expression "SET estado = :status, titulo = :title" \
  --expression-attribute-values '{":status":{"S":"publicado"},":title":{"S":"Practica NoSQL CRUD verificada"}}' \
  --return-values ALL_NEW --return-consumed-capacity TOTAL \
  --query "{Estado:Attributes.estado.S,Titulo:Attributes.titulo.S,Capacity:ConsumedCapacity.CapacityUnits}" --output json)
echo "UPDATE OK | $UPDATE_OUTPUT"

SCAN_OUTPUT=$(aws dynamodb scan --table-name "$TABLE_NAME" --region "$REGION" \
  --filter-expression "autor = :author" \
  --expression-attribute-values '{":author":{"S":"Diego Docente"}}' \
  --return-consumed-capacity TOTAL \
  --query "{Count:Count,ScannedCount:ScannedCount,Capacity:ConsumedCapacity.CapacityUnits}" --output json)
echo "SCAN INEFICIENTE | $SCAN_OUTPUT"

DELETE_OUTPUT=$(aws dynamodb delete-item --table-name "$TABLE_NAME" --region "$REGION" \
  --key "{\"pk\":{\"S\":\"$PARTITION_KEY\"},\"sk\":{\"S\":\"$TEMP_SORT_KEY\"}}" \
  --return-values ALL_OLD --return-consumed-capacity TOTAL \
  --query "{Eliminado:Attributes.documento_id.S,Capacity:ConsumedCapacity.CapacityUnits}" --output json)
echo "DELETE OK | $DELETE_OUTPUT"
echo "CRUD COMPLETO SIN LLAVES PERMANENTES"
