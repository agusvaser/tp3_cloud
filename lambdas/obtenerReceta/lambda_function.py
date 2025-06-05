import boto3
import json
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('TablaRecetas')

def lambda_handler(event, context):
    # Habilitar CORS
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,GET'
    }

    try:
        print("Received event:", json.dumps(event))

        # Adaptado a HTTP API v2: pathParameters está bajo 'pathParameters'
        path_params = event.get('pathParameters', {})
        id_receta = path_params.get('id')
        print(id_receta)
        if not id_receta:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'mensaje': 'Falta el id de la receta'})
            }

        response = table.query(
            IndexName='GSI-RECETA',
            KeyConditionExpression=Key('RECETA').eq(id_receta)
        )
        items = response.get('Items', [])

        if not items:
            return {
                'statusCode': 404,
                'headers': cors_headers,
                'body': json.dumps({'mensaje': 'Receta no encontrada'})
            }

        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps(items[0])
        }

    except Exception as e:
        print("Error:", str(e))
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': str(e)})
        }
