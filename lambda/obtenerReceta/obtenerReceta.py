import boto3
import json
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('TablaRecetas')

def lambda_handler(event, context):
    try:
        id_receta = event['pathParameters']['id']

        response = table.query(
            IndexName='GSI-RECETA',
            KeyConditionExpression=Key('RECETA').eq(id_receta)
        )
        items = response.get('Items', [])

        
        if not items:
            return {
                'statusCode': 404,
                'headers': {'Access-Control-Allow-Origin': '*'},
                'body': json.dumps({'mensaje': 'Receta no encontrada'})
            }
        
        return {
            'statusCode': 200,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps(items[0])
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }
