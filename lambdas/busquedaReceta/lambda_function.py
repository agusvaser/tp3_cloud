import boto3
import json
import unicodedata
import re

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('TablaRecetas')

def normalizar_texto(texto):
    if not texto:
        return ""
    
    texto = texto.lower()
    texto = unicodedata.normalize('NFD', texto)
    texto = ''.join(char for char in texto if unicodedata.category(char) != 'Mn')
    texto = re.sub(r"[''`´]", "", texto)
    texto = re.sub(r'\s+', ' ', texto).strip()
    
    return texto

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
        
        # Normalizar los términos de búsqueda
        nombre_normalizado = normalizar_texto(nombre) if nombre else None
        categoria_normalizada = normalizar_texto(categoria) if categoria else None
        ingredientes_normalizados = []
        if ingredientes:
            ingredientes_normalizados = [normalizar_texto(ing.strip()) for ing in ingredientes.split(',') if ing.strip()]
        
        print(f"Búsqueda normalizada:")
        if nombre_normalizado:
            print(f"  - Nombre: '{nombre}' -> '{nombre_normalizado}'")
        if categoria_normalizada:
            print(f"  - Categoría: '{categoria}' -> '{categoria_normalizada}'")
        if ingredientes_normalizados:
            print(f"  - Ingredientes: {ingredientes_normalizados}")
        
        # Hacer un scan de todas las recetas (o usar filtros básicos si no hay términos de búsqueda)
        scan_kwargs = {
            'FilterExpression': 'attribute_exists(#r)',
            'ExpressionAttributeNames': {'#r': 'RECETA'}
        }
        
        if categoria_normalizada:
            scan_kwargs['FilterExpression'] += ' AND (contains(#cn, :categoria_norm) OR contains(#c, :categoria_orig))'
            scan_kwargs['ExpressionAttributeNames']['#cn'] = 'categoria_normalizada'
            scan_kwargs['ExpressionAttributeNames']['#c'] = 'categoria'
            scan_kwargs.setdefault('ExpressionAttributeValues', {})
            scan_kwargs['ExpressionAttributeValues'][':categoria_norm'] = categoria_normalizada
            scan_kwargs['ExpressionAttributeValues'][':categoria_orig'] = categoria.lower()
        
        response = table.scan(**scan_kwargs)
        items = response.get('Items', [])
        
        print(f"Scan inicial encontró {len(items)} recetas")
        
        items_filtrados = []
        
        for item in items:
            incluir_item = True
            
            # Filtrar por nombre
            if nombre_normalizado and incluir_item:
                nombre_item_norm = item.get('nombre_normalizado', '')
                if not nombre_item_norm:
                    nombre_item_norm = normalizar_texto(item.get('nombre', ''))
                
                if nombre_normalizado not in nombre_item_norm:
                    incluir_item = False
                    print(f"  - Descartando '{item.get('nombre')}': '{nombre_item_norm}' no contiene '{nombre_normalizado}'")
            
            if ingredientes_normalizados and incluir_item:
                ingredientes_item_norm = item.get('ingredientes_normalizado', '')
                if not ingredientes_item_norm:
                    ingredientes_item_norm = normalizar_texto(item.get('ingredientes', ''))
                
                for ing_norm in ingredientes_normalizados:
                    if ing_norm and ing_norm not in ingredientes_item_norm:
                        incluir_item = False
                        print(f"  - Descartando '{item.get('nombre')}': no contiene ingrediente '{ing_norm}'")
                        break
            
            if incluir_item:
                print(f"  ✓ Incluyendo: '{item.get('nombre')}'")
                items_filtrados.append(item)
        
        for item in items_filtrados:
            item.pop('nombre_normalizado', None)
            item.pop('ingredientes_normalizado', None)
            item.pop('categoria_normalizada', None)
        
        print(f"Resultado final: {len(items_filtrados)} recetas")
        
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps(items_filtrados)
        }

    except Exception as e:
        print("Error:", str(e))
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({'error': str(e)})
        }