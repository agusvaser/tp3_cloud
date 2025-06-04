import boto3
import json
import os

# Initialize Cognito client
cognito_client = boto3.client('cognito-idp')

def lambda_handler(event, context):
    # Habilitar CORS
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'OPTIONS,POST'
    }

    try:
        print("=== DEBUG logoutCognito ===")
        print("Received event:", json.dumps(event, indent=2))

        # Manejar OPTIONS request
        if event.get('httpMethod') == 'OPTIONS':
            return {
                'statusCode': 200,
                'headers': cors_headers,
                'body': json.dumps({'mensaje': 'Preflight CORS check'})
            }

        # Obtener el body del evento
        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event.get('body') or {}

        access_token = body.get('access_token')
        
        if not access_token:
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({
                    'mensaje': 'Access token requerido',
                    'error': 'MISSING_ACCESS_TOKEN'
                })
            }

        print(f"Intentando hacer logout con token: {access_token[:20]}...")

        # Invalidar el token de acceso usando global sign out
        try:
            response = cognito_client.global_sign_out(
                AccessToken=access_token
            )
            print("Global sign out exitoso:", response)
            
            return {
                'statusCode': 200,
                'headers': cors_headers,
                'body': json.dumps({
                    'mensaje': 'Logout exitoso',
                    'success': True
                })
            }
            
        except cognito_client.exceptions.NotAuthorizedException as e:
            print("Token ya inválido o expirado:", str(e))
            # Aunque el token ya esté inválido, consideramos el logout exitoso
            return {
                'statusCode': 200,
                'headers': cors_headers,
                'body': json.dumps({
                    'mensaje': 'Logout exitoso (token ya inválido)',
                    'success': True
                })
            }
            
        except Exception as cognito_error:
            print("Error en Cognito:", str(cognito_error))
            return {
                'statusCode': 500,
                'headers': cors_headers,
                'body': json.dumps({
                    'mensaje': 'Error al invalidar token en Cognito',
                    'error': str(cognito_error)
                })
            }

    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'headers': cors_headers,
            'body': json.dumps({
                'mensaje': 'JSON inválido en el body',
                'error': 'INVALID_JSON'
            })
        }
    except Exception as e:
        print("ERROR general:", str(e))
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