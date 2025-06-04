import boto3
import json
import os

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
TABLE_NAME = os.environ.get('DYNAMODB_TABLE', 'TablaRecetas')
table = dynamodb.Table(TABLE_NAME)

def lambda_handler(event, context):
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'OPTIONS,POST,DELETE'
    }

    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({'message': 'CORS preflight check successful'})
        }

    try:
        print(f"START removeFavorite - Received event: {json.dumps(event)}")

        if isinstance(event.get('body'), str):
            body = json.loads(event['body'])
        else:
            body = event.get('body') or {}

        user_email = body.get('user_email')
        recipe_id = body.get('recipe_id')

        print(f"INFO removeFavorite: Extracted user_email: {user_email}, recipe_id: {recipe_id}, type: {type(recipe_id)}")

        if not user_email or not recipe_id or recipe_id == "undefined":
            error_message = 'user_email and a valid recipe_id are required.'
            if recipe_id == "undefined":
                error_message = 'recipe_id cannot be the string "undefined".'
            print(f"FAIL removeFavorite: Validation failed - {error_message} (user_email='{user_email}', recipe_id='{recipe_id}')")
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({
                    'message': error_message,
                    'error': 'MISSING_OR_INVALID_PARAMETERS'
                })
            }

        # This is the SK for the favorite marker item
        favorite_item_sk = f"FAVORITE#{recipe_id}" 

        key_to_delete = {
            'USER': user_email,
            'RECETA': favorite_item_sk
        }
        
        print(f"INFO removeFavorite: Attempting to delete item with key: {json.dumps(key_to_delete)}")
        
        # Consider adding ConditionExpression to ensure item exists or belongs to user if needed
        response = table.delete_item(Key=key_to_delete, ReturnValues='ALL_OLD')
        
        if response.get('Attributes'):
            print(f"INFO removeFavorite: Successfully removed favorite for user {user_email}, recipe_id {recipe_id}. Deleted item: {json.dumps(response.get('Attributes'))}")
            return {
                'statusCode': 200, 
                'headers': cors_headers,
                'body': json.dumps({
                    'message': 'Recipe removed from favorites successfully'
                })
            }
        else:
            # This means the item was not found, which could be okay for a delete operation (idempotency)
            # Or it could indicate an issue if you expected it to be there.
            print(f"WARN removeFavorite: Favorite marker not found for user {user_email}, recipe_id {recipe_id} (key: {json.dumps(key_to_delete)}). No item was deleted.")
            return {
                'statusCode': 200, # Or 404 if you'd rather signal 'not found' as an error for the client
                'headers': cors_headers,
                'body': json.dumps({
                    'message': 'Favorite not found or already removed.'
                })
            }

    except json.JSONDecodeError as je:
        print(f"ERROR removeFavorite - JSON Decode: {str(je)}")
        return {
            'statusCode': 400,
            'headers': cors_headers,
            'body': json.dumps({
                'message': 'Invalid JSON format in request body.',
                'error': str(je),
                'type': type(je).__name__
            })
        }
    except Exception as e:
        print(f"ERROR removeFavorite: Exception: {str(e)}")
        import traceback
        print(f"Traceback: {traceback.format_exc()}")
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({
                'message': 'Error removing recipe from favorites.',
                'error': str(e),
                'type': type(e).__name__
            })
        } 