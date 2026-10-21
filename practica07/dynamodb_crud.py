import os
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Attr, Key


TABLE_NAME = os.getenv("DYNAMODB_TABLE", "repositorio-escolar-documentos-p07")
REGION = os.getenv("AWS_REGION", "us-east-1")
COURSE_ID = "AWS-101"
TEMP_DOCUMENT_ID = "DOC-CRUD-001"
TEMP_SORT_KEY = f"DOCUMENTO#2026-10-21T18:00:00Z#{TEMP_DOCUMENT_ID}"


def table_resource():
    dynamodb = boto3.resource("dynamodb", region_name=REGION)
    return dynamodb.Table(TABLE_NAME)


def seed_documents(table):
    documents = [
        ("DOC-101", "2026-10-10T09:00:00Z", "Guia de alta disponibilidad", "publicado"),
        ("DOC-102", "2026-10-11T10:00:00Z", "Practica de escalamiento", "publicado"),
        ("DOC-103", "2026-10-12T11:00:00Z", "Diseno de la VPC", "publicado"),
        ("DOC-104", "2026-10-13T12:00:00Z", "Modelo relacional", "borrador"),
        ("DOC-105", "2026-10-14T13:00:00Z", "Seguridad de almacenamiento", "publicado"),
    ]
    with table.batch_writer(overwrite_by_pkeys=["pk", "sk"]) as batch:
        for document_id, created_at, title, status in documents:
            batch.put_item(
                Item={
                    "pk": f"CURSO#{COURSE_ID}",
                    "sk": f"DOCUMENTO#{created_at}#{document_id}",
                    "documento_id": document_id,
                    "curso_id": COURSE_ID,
                    "titulo": title,
                    "estado": status,
                    "autor": "Diego Docente",
                    "tamano_kb": Decimal("128"),
                }
            )


def create_document(table):
    response = table.put_item(
        Item={
            "pk": f"CURSO#{COURSE_ID}",
            "sk": TEMP_SORT_KEY,
            "documento_id": TEMP_DOCUMENT_ID,
            "curso_id": COURSE_ID,
            "titulo": "Practica NoSQL CRUD",
            "estado": "borrador",
            "autor": "Edgar Rodriguez",
            "tamano_kb": Decimal("96"),
        },
        ConditionExpression="attribute_not_exists(pk) AND attribute_not_exists(sk)",
        ReturnConsumedCapacity="TOTAL",
    )
    print("CREATE OK", response["ConsumedCapacity"])


def query_course_documents(table):
    response = table.query(
        KeyConditionExpression=Key("pk").eq(f"CURSO#{COURSE_ID}")
        & Key("sk").begins_with("DOCUMENTO#"),
        ScanIndexForward=False,
        ReturnConsumedCapacity="TOTAL",
    )
    print(
        "QUERY OK",
        {"Count": response["Count"], "ScannedCount": response["ScannedCount"]},
        response["ConsumedCapacity"],
    )
    for item in response["Items"]:
        print(item["documento_id"], item["titulo"], item["estado"])


def update_document(table):
    response = table.update_item(
        Key={"pk": f"CURSO#{COURSE_ID}", "sk": TEMP_SORT_KEY},
        UpdateExpression="SET estado = :status, titulo = :title",
        ExpressionAttributeValues={
            ":status": "publicado",
            ":title": "Practica NoSQL CRUD verificada",
        },
        ReturnValues="ALL_NEW",
        ReturnConsumedCapacity="TOTAL",
    )
    print("UPDATE OK", response["Attributes"], response["ConsumedCapacity"])


def inefficient_scan(table):
    response = table.scan(
        FilterExpression=Attr("autor").eq("Diego Docente"),
        ReturnConsumedCapacity="TOTAL",
    )
    print(
        "SCAN INEFICIENTE",
        {"Count": response["Count"], "ScannedCount": response["ScannedCount"]},
        response["ConsumedCapacity"],
    )


def delete_document(table):
    response = table.delete_item(
        Key={"pk": f"CURSO#{COURSE_ID}", "sk": TEMP_SORT_KEY},
        ReturnValues="ALL_OLD",
        ReturnConsumedCapacity="TOTAL",
    )
    print("DELETE OK", response.get("Attributes"), response["ConsumedCapacity"])


def main():
    table = table_resource()
    seed_documents(table)
    create_document(table)
    query_course_documents(table)
    update_document(table)
    inefficient_scan(table)
    delete_document(table)
    print("CRUD COMPLETO SIN LLAVES PERMANENTES")


if __name__ == "__main__":
    main()
