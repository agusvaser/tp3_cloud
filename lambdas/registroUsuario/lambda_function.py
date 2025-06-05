import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('TablaRecetas')

def lambda_handler(event, context):
    print("Received event:", json.dumps(event))  # Debug

    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,POST'
    }

    try:
        # Extraer método HTTP (API HTTP usa requestContext)
        method = event.get('requestContext', {}).get('http', {}).get('method', '')

        if method == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': cors_headers,
                'body': json.dumps({'mensaje': 'Preflight CORS check'})
            }

        # Parsear el body dependiendo si es string o dict
        body = event.get('body', {})
        if isinstance(body, str):
            data = json.loads(body)
        else:
            data = body

        email = data.get('email')
        nombre = data.get('nombre')
        password = data.get('password')

        if not (email and nombre and password):
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'mensaje': 'Faltan datos'})
            }

        # Verificar si el usuario ya existe
        response = table.get_item(Key={'USER': email, 'RECETA': 'PROFILE'})
        if 'Item' in response:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'mensaje': 'El usuario ya existe'})
            }

        # Insertar usuario
        table.put_item(Item={
            'USER': email,
            'RECETA': 'PROFILE',
            'nombre': nombre,
            'email': email,
            'password': password
        })

        return {
            'statusCode': 201,
            'headers': cors_headers,
            'body': json.dumps({'mensaje': 'Usuario registrado correctamente'})
        }

    except Exception as e:
        print("Error:", str(e))  # Log para CloudWatch
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': str(e)})
        }
