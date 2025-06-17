import boto3
import json
import os

client = boto3.client('cognito-idp')
sns = boto3.client('sns')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ.get('DYNAMODB_TABLE', 'TablaRecetas'))

def generar_nombre_topic(email):
    return email.replace("@", "at").replace(".", "_")

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
    password = body.get('password')  # Agregamos el password para el auto-login

    if not email or not code:
        return {
            'statusCode': 400,
            'headers': headers,
            'body': json.dumps({'error': 'Faltan email o código de verificación'})
        }

    try:
        # Confirmar usuario con Cognito
        client.confirm_sign_up(
            ClientId=os.environ['COGNITO_CLIENT_ID'],
            Username=email,
            ConfirmationCode=code
        )

        # Crear topic SNS
        topic_name = generar_nombre_topic(email)
        topic_response = sns.create_topic(Name=topic_name)
        topic_arn = topic_response['TopicArn']

        # Suscribir usuario al topic
        sns.subscribe(
            TopicArn=topic_arn,
            Protocol='email',
            Endpoint=email
        )

        # Guardar ARN del topic en DynamoDB
        table.put_item(
            Item={
                'USER': email,
                'RECETA': 'SNS_TOPIC',
                'topic_arn': topic_arn
            }
        )

        # AUTO-LOGIN: Iniciar sesión automáticamente después de la confirmación
        auto_login_result = None
        if password:
            try:
                auth_response = client.initiate_auth(
                    ClientId=os.environ['COGNITO_CLIENT_ID'],
                    AuthFlow='USER_PASSWORD_AUTH',
                    AuthParameters={
                        'USERNAME': email,
                        'PASSWORD': password
                    }
                )
                auto_login_result = auth_response['AuthenticationResult']
            except Exception as login_error:
                # Si falla el auto-login, no devolvemos error, solo continuamos sin tokens
                print(f"Error en auto-login: {login_error}")

        response_body = {
            'message': 'Usuario verificado exitosamente'
        }

        # Si el auto-login fue exitoso, incluir los tokens en la respuesta
        if auto_login_result:
            response_body.update({
                'auto_login': True,
                'id_token': auto_login_result.get('IdToken'),
                'access_token': auto_login_result.get('AccessToken'),
                'refresh_token': auto_login_result.get('RefreshToken')
            })
        else:
            response_body['auto_login'] = False

        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps(response_body)
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': str(e)})
        }