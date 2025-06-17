import boto3
import json
import os
import datetime
import base64
from boto3.dynamodb.conditions import Key, Attr

dynamodb = boto3.resource("dynamodb")
sqs       = boto3.client("sqs")

TABLE_NAME = os.environ.get("DYNAMODB_TABLE", "TablaRecetas")
SQS_URL    = os.environ["SQS_URL"]

table = dynamodb.Table(TABLE_NAME)

def _cors():
    return {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "Content-Type,Authorization",
        "Access-Control-Allow-Methods": "OPTIONS,POST",
    }


def lambda_handler(event, context):
    if event.get("httpMethod") == "OPTIONS":
        return {"statusCode": 200, "headers": _cors(), "body": json.dumps({"msg": "OK"})}

    raw_body = event.get("body")
    if event.get("isBase64Encoded"):
        raw_body = base64.b64decode(raw_body).decode("utf-8")

    body = json.loads(raw_body or "{}")
    user_email = body.get("user_email")
    recipe_id  = body.get("recipe_id")

    if not user_email or not recipe_id or recipe_id == "undefined":
        return {
            "statusCode": 400,
            "headers": _cors(),
            "body": json.dumps({"message": "Faltan user_email o recipe_id válido"}),
        }

    favorite_item_sk = f"FAVORITE#{recipe_id}"
    now_iso = datetime.datetime.utcnow().isoformat() + "Z"

    table.put_item(
        Item={
            "USER": user_email,
            "RECETA": favorite_item_sk,
            "originalRecipeId": recipe_id,
            "favoritedAt": now_iso,
        }
    )

    likes_resp     = table.scan(FilterExpression=Attr("originalRecipeId").eq(recipe_id))
    favorite_count = len(likes_resp["Items"])

    THRESHOLD = 1  # ACA DESPUES CAMBIEMOSLO A TRES, ERA PARA PROBAR AHORA ESTE
    if favorite_count < THRESHOLD:
        return {
            "statusCode": 201,
            "headers": _cors(),
            "body": json.dumps({"message": "Recipe added to favorites successfully"}),
        }

    receta_q = table.query(
        IndexName="GSI-RECETA", KeyConditionExpression=Key("RECETA").eq(recipe_id)
    )
    if not receta_q["Items"]:
        return {
            "statusCode": 201,
            "headers": _cors(),
            "body": json.dumps({"message": "Recipe added to favorites successfully"}),
        }

    receta_item  = receta_q["Items"][0]
    autor_email  = receta_item["USER"]
    ya_notif     = receta_item.get("notificadoPorTresLikes", False)
    if ya_notif:
        return {
            "statusCode": 201,
            "headers": _cors(),
            "body": json.dumps({"message": "Recipe added to favorites successfully"}),
        }

    perfil = table.get_item(Key={"USER": autor_email, "RECETA": "SNS_TOPIC"})
    topicArn = perfil.get("Item", {}).get("topic_arn")

    if not topicArn:
        print(f"[WARN] Sin topicArn para {autor_email}")
        return {
            "statusCode": 201,
            "headers": _cors(),
            "body": json.dumps({"message": "Recipe added; autor sin SNS topic"}),
        }

    sqs.send_message(
        QueueUrl=SQS_URL,
        MessageBody=json.dumps(
            {
                "topic_arn": topicArn,
                "subject": "¡Tu receta es popular!",
                "message": f"¡Felicitaciones! Tu receta '{receta_item.get('nombre', 'sin nombre')}' ya tiene {favorite_count} favoritos.",
            }
        ),
    )

    table.update_item(
        Key={"USER": autor_email, "RECETA": recipe_id},
        UpdateExpression="SET notificadoPorTresLikes = :v",
        ExpressionAttributeValues={":v": True},
    )

    return {
        "statusCode": 201,
        "headers": _cors(),
        "body": json.dumps({"message": "Recipe added to favorites successfully"}),
    }