import boto3
import json
import os

client = boto3.client('cognito-idp')

def lambda_handler(event, context):
    # Encabezados CORS
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,POST'
    }

    # Respuesta preflight CORS
    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': headers
        }

    # Parseo del body
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

        # Llamada a Cognito para autenticar
        response = client.initiate_auth(
            ClientId=os.environ['COGNITO_CLIENT_ID'],
            AuthFlow='USER_PASSWORD_AUTH',
            AuthParameters={
                'USERNAME': email,
                'PASSWORD': password
            }
        )

        auth_result = response['AuthenticationResult']

        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({
                'message': 'Inicio de sesión exitoso',
                'id_token': auth_result.get('IdToken'),
                'access_token': auth_result.get('AccessToken'),
                'refresh_token': auth_result.get('RefreshToken')
            })
        }

    except client.exceptions.NotAuthorizedException:
        return {
            'statusCode': 401,
            'headers': headers,
            'body': json.dumps({'error': 'Credenciales incorrectas'})
        }
    except client.exceptions.UserNotConfirmedException:
        return {
            'statusCode': 403,
            'headers': headers,
            'body': json.dumps({'error': 'Usuario no confirmado. Verificá tu email.'})
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': str(e)})
        }
