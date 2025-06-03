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

    try:
        body = json.loads(event.get('body', '{}'))
        email = body.get('email')
        password = body.get('password')

        if not email or not password:
            return {
                'statusCode': 400,
                'headers': headers,
                'body': json.dumps({'error': 'Faltan email o contraseña'})
            }

        response = client.sign_up(
            ClientId=os.environ['COGNITO_CLIENT_ID'],
            Username=email,
            Password=password,
            UserAttributes=[
                {
                    'Name': 'email',
                    'Value': email
                }
            ]
        )

        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({'message': 'Registro exitoso, verificar email.'})
        }

    except client.exceptions.UsernameExistsException:
        return {
            'statusCode': 400,
            'headers': headers,
            'body': json.dumps({'error': 'El usuario ya existe'})
        }
    except client.exceptions.InvalidPasswordException as e:
        return {
            'statusCode': 400,
            'headers': headers,
            'body': json.dumps({'error': 'Contraseña no válida: ' + str(e)})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': str(e)})
        }