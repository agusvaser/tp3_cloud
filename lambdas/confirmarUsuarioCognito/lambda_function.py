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


        return {
            'statusCode': 200,
            'headers': headers,
            'body': json.dumps({'message': 'Usuario verificado, por favor inicie sesión'})
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': headers,
            'body': json.dumps({'error': str(e)})
        }