# import boto3
# import json
# import os
# import datetime

# # Initialize DynamoDB client
# dynamodb = boto3.resource('dynamodb')
# # Get table name from environment variable, with a fallback for local testing
# TABLE_NAME = os.environ.get('DYNAMODB_TABLE', 'TablaRecetas')
# table = dynamodb.Table(TABLE_NAME)

# def lambda_handler(event, context):
#     cors_headers = {
#         'Access-Control-Allow-Origin': '*',
#         'Access-Control-Allow-Headers': 'Content-Type,Authorization',
#         'Access-Control-Allow-Methods': 'OPTIONS,POST'
#     }

#     # Handle OPTIONS request for CORS preflight
#     if event.get('httpMethod') == 'OPTIONS':
#         return {
#             'statusCode': 200,
#             'headers': cors_headers,
#             'body': json.dumps({'message': 'CORS preflight check successful'})
#         }

#     try:
#         print(f"Received event: {json.dumps(event)}")

#         # Expecting body to be a JSON string
#         if isinstance(event.get('body'), str):
#             body = json.loads(event['body'])
#         else:
#             body = event.get('body') or {}

#         user_email = body.get('user_email')
#         recipe_id = body.get('recipe_id')

#         print(f"Extracted user_email: {user_email}, recipe_id: {recipe_id}, type of recipe_id: {type(recipe_id)}")

#         if not user_email or not recipe_id or recipe_id == "undefined":
#             error_message = 'user_email and a valid recipe_id are required in the request body.'
#             if recipe_id == "undefined":
#                 error_message = 'recipe_id cannot be the string "undefined".'
            
#             print(f"Validation Failed: {error_message} (user_email='{user_email}', recipe_id='{recipe_id}')")
#             return {
#                 'statusCode': 400,
#                 'headers': cors_headers,
#                 'body': json.dumps({
#                     'message': error_message,
#                     'error': 'MISSING_OR_INVALID_PARAMETERS'
#                 })
#             }

#         favorite_item_sk = f"FAVORITE#{recipe_id}"
#         timestamp = datetime.datetime.utcnow().isoformat() + "Z"

#         item_to_put = {
#             'USER': user_email,             
#             'RECETA': favorite_item_sk,       
#             'originalRecipeId': recipe_id,
#             'favoritedAt': timestamp
#         }
        
#         print(f"Attempting to put item: {json.dumps(item_to_put)}")

#         table.put_item(Item=item_to_put)

#         print(f"Successfully added favorite for user {user_email}, recipe {recipe_id}")

#         return {
#             'statusCode': 201, # 201 Created
#             'headers': cors_headers,
#             'body': json.dumps({
#                 'message': 'Recipe added to favorites successfully',
#                 'item': item_to_put # Optional: return the created item
#             })
#         }

#     except json.JSONDecodeError as je:
#         print(f"ERROR - JSON Decode: {str(je)}")
#         return {
#             'statusCode': 400, # Bad Request due to malformed JSON
#             'headers': cors_headers,
#             'body': json.dumps({
#                 'message': 'Invalid JSON format in request body.',
#                 'error': str(je),
#                 'type': type(je).__name__
#             })
#         }
#     except Exception as e:
#         print(f"ERROR: {str(e)}")
#         import traceback
#         print(f"Traceback: {traceback.format_exc()}")
#         return {
#             'statusCode': 500,
#             'headers': cors_headers,
#             'body': json.dumps({
#                 'message': 'Error adding recipe to favorites.',
#                 'error': str(e),
#                 'type': type(e).__name__
#             })
#         } 

import boto3
import json
import os
import datetime
import base64
from boto3.dynamodb.conditions import Key, Attr

dynamodb = boto3.resource('dynamodb')
sqs = boto3.client('sqs')

SQS_URL = os.environ["SQS_URL"]
TABLE_NAME = os.environ.get('DYNAMODB_TABLE', 'TablaRecetas')
table = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    raw_body = event.get('body')
    decoded_body = base64.b64decode(raw_body).decode('utf-8') if event.get('isBase64Encoded') else raw_body

    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'OPTIONS,POST'
    }

    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({'message': 'CORS preflight check successful'})
        }

    try:
        body = json.loads(event['body']) if isinstance(event.get('body'), str) else (event.get('body') or {})

        user_email = body.get('user_email')
        recipe_id = body.get('recipe_id')

        if not user_email or not recipe_id or recipe_id == "undefined":
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'message': 'Faltan user_email o recipe_id válido'})
            }

        favorite_item_sk = f"FAVORITE#{recipe_id}"
        timestamp = datetime.datetime.utcnow().isoformat() + "Z"

        item_to_put = {
            'USER': user_email,
            'RECETA': favorite_item_sk,
            'originalRecipeId': recipe_id,
            'favoritedAt': timestamp
        }

        table.put_item(Item=item_to_put)

        response = table.scan(
            FilterExpression=Attr('originalRecipeId').eq(recipe_id)
        )
        favorite_count = len(response['Items'])

        if favorite_count >= 1:
            autor_query = table.query(
                IndexName="GSI-RECETA",
                KeyConditionExpression=Key('RECETA').eq(recipe_id)
            )

            if autor_query['Items']:
                receta_item = autor_query['Items'][0]
                autor_email = receta_item['USER']
                ya_notificado = receta_item.get('notificadoPorTresLikes', False)
                topicArn = "arn:aws:sns:us-east-1:595314810548:avasermanatitba_edu_ar"

                mensaje = {
                    "topic_arn": topicArn,
                    "subject": "¡Tu receta es popular!",
                    "message": f"¡Felicitaciones! Tu receta '{receta_item.get('nombre', 'sin nombre')}' ha sido guardada por 3 usuarios."
                }

                sqs.send_message(
                    QueueUrl=SQS_URL,
                    MessageBody=json.dumps(mensaje)
                )

                table.update_item(
                    Key={'USER': autor_email, 'RECETA': recipe_id},
                    UpdateExpression="SET notificadoPorTresLikes = :v",
                    ExpressionAttributeValues={':v': True}
                )

        return {
            'statusCode': 201,
            'headers': cors_headers,
            'body': json.dumps({
                'message': 'Recipe added to favorites successfully',
                'item': item_to_put
            })
        }

    except json.JSONDecodeError as je:
        return {
            'statusCode': 400,
            'headers': cors_headers,
            'body': json.dumps({'message': 'JSON inválido.', 'error': str(je)})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'message': 'Error interno.', 'error': str(e)})
        }
