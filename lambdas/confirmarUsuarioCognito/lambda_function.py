import boto3
import json
import os

client = boto3.client('cognito-idp')

def lambda_handler(event, context):
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,POST'
    }

    if event.get('httpMethod') == 'OPTIONS':
        return {'statusCode': 200, 'headers': headers}

    body = json.loads(event.get('body', '{}'))
    email = body.get('email')
    code = body.get('code')

    if not email or not code:
        return {
            'statusCode': 400,
            'headers': headers,
            'body': json.dumps({'error': 'Faltan email o código de verificación'})
        }

    try:
        client.confirm_sign_up(
            ClientId=os.environ['COGNITO_CLIENT_ID'],
            Username=email,
            ConfirmationCode=code
        )

        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({'message': 'Usuario verificado exitosamente'})
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': str(e)})
        }
