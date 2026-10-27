import json
import os
import re
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key


TABLE_NAME = os.environ.get(
    "TABLE_NAME", "repositorio-escolar-documentos-p07"
)
COURSE_PATTERN = re.compile(r"^[A-Za-z0-9_-]{1,40}$")

dynamodb = boto3.resource("dynamodb")
table = dynamodb.Table(TABLE_NAME)


def json_default(value):
    if isinstance(value, Decimal):
        return int(value) if value % 1 == 0 else float(value)
    raise TypeError(f"Tipo no serializable: {type(value).__name__}")


def response(status_code, payload):
    return {
        "statusCode": status_code,
        "headers": {
            "Content-Type": "application/json; charset=utf-8",
            "Access-Control-Allow-Origin": "*",
            "Cache-Control": "no-store",
        },
        "body": json.dumps(payload, ensure_ascii=False, default=json_default),
    }


def lambda_handler(event, context):
    query = event.get("queryStringParameters") or {}
    course = query.get("curso", "AWS-101").strip().upper()

    if not COURSE_PATTERN.fullmatch(course):
        return response(400, {"error": "El parámetro curso no es válido."})

    result = table.query(
        KeyConditionExpression=Key("pk").eq(f"CURSO#{course}"),
        ProjectionExpression="pk, sk, documento_id, titulo, autor, estado, #url",
        ExpressionAttributeNames={"#url": "url"},
    )

    return response(
        200,
        {
            "proyecto": "Repositorio Escolar",
            "consulta": course,
            "cantidad": result.get("Count", 0),
            "documentos": result.get("Items", []),
            "soloLectura": True,
            "requestId": context.aws_request_id,
        },
    )
