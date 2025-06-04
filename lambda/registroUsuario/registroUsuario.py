import json
import boto3

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('TablaRecetas')

def lambda_handler(event, context):
    try:
        # Parsear el cuerpo del request
        data = json.loads(event['body'])
        email = data.get('email')
        nombre = data.get('nombre')
        password = data.get('password')

        if not (email and password and nombre):
            return {
                'statusCode': 400,
                'headers': {'Access-Control-Allow-Origin': '*'},
                'body': json.dumps({'mensaje': 'Faltan datos'})
            }

        # Verificar si el usuario ya existe
        response = table.get_item(Key={'USER': email, 'RECETA': 'PROFILE'})
        if 'Item' in response:
            return {
                'statusCode': 400,
                'headers': {'Access-Control-Allow-Origin': '*'},
                'body': json.dumps({'mensaje': 'El usuario ya existe'})
            }

        # Insertar usuario en la tabla
        table.put_item(Item={
            'USER': email,
            'RECETA': 'PROFILE',
            'nombre': nombre,
            'email': email,
            'password': password
        })

        return {
            'statusCode': 201,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'mensaje': 'Usuario registrado correctamente'})
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }
