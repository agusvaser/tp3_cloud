import boto3
import json
import uuid

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('TablaRecetas')

def lambda_handler(event, context):
    # Habilitar CORS
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,POST'
    }

    try:
        print("Received event:", json.dumps(event))

        # Manejar solicitudes OPTIONS (preflight de CORS)
        if event.get('httpMethod', '') == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': cors_headers,
                'body': json.dumps({'mensaje': 'Preflight CORS check'})
            }

        data = json.loads(event.get('body', '{}'))

        nombre = data.get('nombre')
        ingredientes = data.get('ingredientes')
        instrucciones = data.get('instrucciones')
        categoria = data.get('categoria')
        tiempo = data.get('tiempo')
        usuario_email = data.get('usuario_email')

        if not (nombre and ingredientes and instrucciones and categoria and tiempo and usuario_email):
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'mensaje': 'Faltan datos para guardar la receta'})
            }

        id_receta = str(uuid.uuid4())

        table.put_item(Item={
            'USER': usuario_email,
            'RECETA': id_receta,
            'nombre': nombre,
            'ingredientes': ingredientes,
            'instrucciones': instrucciones,
            'categoria': categoria,
            'tiempo': tiempo
        })

        return {
            'statusCode': 201,
            'headers': cors_headers,
            'body': json.dumps({'mensaje': 'Receta guardada correctamente', 'id_receta': id_receta})
        }

    except Exception as e:
        print("Error:", str(e))
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': str(e)})
        }
