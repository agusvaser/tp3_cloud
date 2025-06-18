import boto3
import json
import decimal
from boto3.dynamodb.conditions import Key

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('TablaRecetas')

def lambda_handler(event, context):
    # Habilitar CORS
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'OPTIONS,GET'
    }

    try:
        print("=== DEBUG obtenerRecetasUsuario ===")
        print("Received event:", json.dumps(event, indent=2))

        # Manejar OPTIONS request
        if event.get('httpMethod') == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': cors_headers,
                'body': json.dumps({'mensaje': 'Preflight CORS check'})
            }

        # Obtener email del usuario de los query parameters
        query_params = event.get('queryStringParameters') or {}
        user_email = query_params.get('email')
        
        print(f"Email del usuario: {user_email}")

        if not user_email:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({
                    'mensaje': 'Email del usuario requerido',
                    'error': 'EMAIL_REQUERIDO'
                })
            }

        print(f"Consultando recetas para usuario: {user_email}")
        
        # Consultar todas las recetas del usuario usando el índice principal
        response = table.query(
            KeyConditionExpression=Key('USER').eq(user_email)
        )
        
        items = response.get('Items', [])
        print(f"Recetas encontradas: {len(items)}")


        recetas_usuario = []
        for item in items:
            recipe_id = item.get('RECETA')
            tipo = item.get('TIPO')
            
            if (recipe_id and 
                recipe_id != 'PROFILE' and 
                recipe_id != 'SNS_TOPIC' and 
                not recipe_id.startswith('FAVORITE#') and
                tipo == 'ORIGINAL'):
                recetas_usuario.append(item)
                print(f"  ✓ Incluyendo receta: {item.get('nombre', 'Sin nombre')} (ID: {recipe_id})")
            else:
                print(f"  ✗ Excluyendo entrada: RECETA={recipe_id}, TIPO={tipo}")

        print(f"Recetas del usuario (sin perfil y sin favoritos duplicados): {len(recetas_usuario)}")

        # Convertir Decimal a tipos JSON serializables
        def convert_decimals(obj):
            if isinstance(obj, decimal.Decimal):
                return int(obj) if obj % 1 == 0 else float(obj)
            elif isinstance(obj, dict):
                return {k: convert_decimals(v) for k, v in obj.items()}
            elif isinstance(obj, list):
                return [convert_decimals(i) for i in obj]
            return obj

        recetas_convertidas = convert_decimals(recetas_usuario)

        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({
                'recetas': recetas_convertidas,
                'total': len(recetas_convertidas)
            })
        }

    except Exception as e:
        print("ERROR:", str(e))
        import traceback
        print("Traceback:", traceback.format_exc())
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({
                'error': str(e),
                'type': type(e).__name__
            })
        }