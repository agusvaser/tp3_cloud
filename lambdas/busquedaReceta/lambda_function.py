import boto3
import json

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

        # Manejar solicitudes OPTIONS (preflight de CORS)
        if event.get('httpMethod', '') == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': cors_headers,
                'body': json.dumps({'mensaje': 'Preflight CORS check'})
            }

        params = event.get('queryStringParameters') or {}
        nombre = params.get('nombre')
        categoria = params.get('categoria')
        ingredientes = params.get('ingredientes')
        
        scan_kwargs = {
            'FilterExpression': 'attribute_exists(#r)',
            'ExpressionAttributeNames': {'#r': 'RECETA'}
        }
        
        if nombre:
            # Convertir a minúsculas para búsqueda insensible a mayúsculas
            nombre_lower = nombre.lower()
            scan_kwargs['FilterExpression'] += ' AND contains(lower(#n), :nombre)'
            scan_kwargs['ExpressionAttributeNames']['#n'] = 'nombre'
            scan_kwargs.setdefault('ExpressionAttributeValues', {})[':nombre'] = nombre_lower
        
        if categoria:
            # La categoría se mantiene exacta (case-sensitive)
            scan_kwargs['FilterExpression'] += ' AND #c = :categoria'
            scan_kwargs['ExpressionAttributeNames']['#c'] = 'categoria'
            scan_kwargs.setdefault('ExpressionAttributeValues', {})[':categoria'] = categoria
        
        if ingredientes:
            ingredientes_list = ingredientes.split(',')
            for idx, ing in enumerate(ingredientes_list):
                # Convertir ingredientes a minúsculas para búsqueda insensible a mayúsculas
                ing_lower = ing.strip().lower()
                key = f':ing{idx}'
                scan_kwargs['FilterExpression'] += f' AND contains(lower(#i), {key})'
                scan_kwargs['ExpressionAttributeNames']['#i'] = 'ingredientes'
                scan_kwargs.setdefault('ExpressionAttributeValues', {})[key] = ing_lower
        
        response = table.scan(**scan_kwargs)
        items = response.get('Items', [])

        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps(items)
        }

    except Exception as e:
        print("Error:", str(e))
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': str(e)})
        }