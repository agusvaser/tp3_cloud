import boto3
import json

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('TablaRecetas')

def lambda_handler(event, context):
    try:
        params = event.get('queryStringParameters') or {}
        nombre = params.get('nombre')
        categoria = params.get('categoria')
        ingredientes = params.get('ingredientes')
        
        scan_kwargs = {
            'FilterExpression': 'attribute_exists(#r)',
            'ExpressionAttributeNames': {'#r': 'RECETA'}
        }
        
        if nombre:
            scan_kwargs['FilterExpression'] += ' AND contains(#n, :nombre)'
            scan_kwargs['ExpressionAttributeNames']['#n'] = 'nombre'
            scan_kwargs.setdefault('ExpressionAttributeValues', {})[':nombre'] = nombre
        
        if categoria:
            scan_kwargs['FilterExpression'] += ' AND #c = :categoria'
            scan_kwargs['ExpressionAttributeNames']['#c'] = 'categoria'
            scan_kwargs.setdefault('ExpressionAttributeValues', {})[':categoria'] = categoria
        
        if ingredientes:
            ingredientes_list = ingredientes.split(',')
            for idx, ing in enumerate(ingredientes_list):
                key = f':ing{idx}'
                scan_kwargs['FilterExpression'] += f' AND contains(#i, {key})'
                scan_kwargs['ExpressionAttributeNames']['#i'] = 'ingredientes'
                scan_kwargs.setdefault('ExpressionAttributeValues', {})[key] = ing.strip()
        
        response = table.scan(**scan_kwargs)
        items = response.get('Items', [])
        
        return {
            'statusCode': 200,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps(items)
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'headers': {'Access-Control-Allow-Origin': '*'},
            'body': json.dumps({'error': str(e)})
        }
