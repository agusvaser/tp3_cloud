import boto3
import json
import uuid
import base64
import cgi
import io
import os
import unicodedata
import re

s3 = boto3.client('s3')
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('TablaRecetas')

# Nombre del bucket de imágenes desde variable de entorno
BUCKET_IMAGENES = os.environ['BUCKET_IMAGENES']

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
    # Cabeceras CORS para permitir solicitudes desde el frontend
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'OPTIONS,POST'
    }

    try:
        print("Received event:", json.dumps(event))

        # Manejo de solicitud preflight CORS
        if event.get('httpMethod', '') == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': cors_headers,
                'body': json.dumps({'mensaje': 'Preflight CORS check'})
            }

        # Leer el Content-Type (puede venir en minúsculas)
        content_type = event['headers'].get('Content-Type') or event['headers'].get('content-type')
        
        # Decodificar el body si viene en base64 (lo normal con API Gateway)
        if event.get("isBase64Encoded"):
            body = base64.b64decode(event["body"])
        else:
            body = event["body"].encode()

        # Parsear el body multipart
        environ = {'REQUEST_METHOD': 'POST'}
        headers = {'content-type': content_type}
        fs = cgi.FieldStorage(fp=io.BytesIO(body), environ=environ, headers=headers)

        # Obtener los campos del formulario
        nombre = fs.getvalue("nombre")
        ingredientes = fs.getvalue("ingredientes")
        instrucciones = fs.getvalue("instrucciones")
        categoria = fs.getvalue("categoria")
        tiempo = fs.getvalue("tiempo")
        usuario_email = fs.getvalue("usuario_email")

        # Validación obligatoria
        if not all([nombre, ingredientes, instrucciones, categoria, tiempo, usuario_email]):
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({'mensaje': 'Faltan datos para guardar la receta'})
            }

        # Generar ID único
        id_receta = str(uuid.uuid4())
        imagen_url = None

        # Subida a S3 si se incluye imagen
        if "imagen" in fs and fs["imagen"].filename:
            imagen_file = fs["imagen"]
            extension = os.path.splitext(imagen_file.filename)[1]
            s3_key = f"{id_receta}{extension}"

            s3.upload_fileobj(
                imagen_file.file,
                BUCKET_IMAGENES,
                s3_key,
                ExtraArgs={
                    "ContentType": imagen_file.type,
                    "ACL": "public-read"
                }
            )

            # Construcción de URL pública
            imagen_url = f"https://{BUCKET_IMAGENES}.s3.amazonaws.com/{s3_key}"

        item = {
            'USER': usuario_email,
            'RECETA': id_receta,
            'TIPO': 'ORIGINAL',
            'nombre': nombre,
            'ingredientes': ingredientes,
            'instrucciones': instrucciones,
            'categoria': categoria,
            'tiempo': tiempo,
            'notificado': False,
            'nombre_normalizado': normalizar_texto(nombre),
            'ingredientes_normalizado': normalizar_texto(ingredientes),
            'categoria_normalizada': normalizar_texto(categoria)
        }

        if imagen_url:
            item['imagen'] = imagen_url

        # Guardar en DynamoDB
        table.put_item(Item=item)

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