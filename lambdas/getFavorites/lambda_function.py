import boto3
import json
import os
import decimal
from boto3.dynamodb.conditions import Key

# Initialize DynamoDB client
dynamodb = boto3.resource('dynamodb')
TABLE_NAME = os.environ.get('DYNAMODB_TABLE', 'TablaRecetas')
GSI_NAME = os.environ.get('DYNAMODB_GSI_NAME', 'GSI-RECETA')
table = dynamodb.Table(TABLE_NAME)

# Helper to convert DynamoDB decimal types to JSON serializable numbers
class DecimalEncoder(json.JSONEncoder):
    def default(self, o):
        if isinstance(o, decimal.Decimal):
            if o % 1 == 0:
                return int(o)
            else:
                return float(o)
        return super(DecimalEncoder, self).default(o)

def lambda_handler(event, context):
    cors_headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type,Authorization',
        'Access-Control-Allow-Methods': 'OPTIONS,GET'
    }

    if event.get('httpMethod') == 'OPTIONS':
        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({'message': 'CORS preflight check successful'})
        }

    try:
        print(f"START getFavorites - Received event: {json.dumps(event)}")

        query_params = event.get('queryStringParameters') or {}
        user_email = query_params.get('user_email')

        if not user_email:
            print(f"FAIL getFavorites: user_email is required. Query params: {query_params}")
            return {
                'statusCode': 400,
                'headers': cors_headers,
                'body': json.dumps({
                    'message': 'user_email is required as a query parameter.',
                    'error': 'MISSING_USER_EMAIL'
                })
            }

        print(f"INFO getFavorites: Fetching favorites for user: {user_email}")

        response = table.query(
            KeyConditionExpression=Key('USER').eq(user_email) & Key('RECETA').begins_with('FAVORITE#')
        )
        
        favorite_items_markers = response.get('Items', [])
        print(f"INFO getFavorites: Found {len(favorite_items_markers)} favorite markers: {json.dumps(favorite_items_markers, cls=DecimalEncoder)}")

        if not favorite_items_markers:
            print(f"INFO getFavorites: No favorite markers found for user {user_email}. Returning empty list.")
            return {
                'statusCode': 200,
                'headers': cors_headers,
                'body': json.dumps({
                    'favorites': [],
                    'total': 0,
                    'message': 'No favorite recipes found for this user.'
                }, cls=DecimalEncoder)
            }

        original_recipe_ids = []
        for item_marker in favorite_items_markers:
            original_id = item_marker.get('originalRecipeId')
            if original_id and original_id != "undefined": # Added check for string "undefined"
                original_recipe_ids.append(original_id)
            else:
                print(f"WARN getFavorites: Favorite marker found with missing or invalid originalRecipeId: {item_marker}")
        
        if not original_recipe_ids:
            print(f"INFO getFavorites: No valid originalRecipeIds extracted from markers for user {user_email}. Markers: {json.dumps(favorite_items_markers, cls=DecimalEncoder)}")
            return {
                'statusCode': 200,
                'headers': cors_headers,
                'body': json.dumps({
                    'favorites': [],
                    'total': 0,
                    'message': 'No valid recipe IDs found in favorites after filtering.'
                }, cls=DecimalEncoder)
            }
            
        print(f"INFO getFavorites: Extracted {len(original_recipe_ids)} valid originalRecipeIds: {original_recipe_ids}")

        detailed_favorites = []
        for i, recipe_id_to_fetch in enumerate(original_recipe_ids):
            print(f"INFO getFavorites: [{i+1}/{len(original_recipe_ids)}] Fetching details for originalRecipeId: {recipe_id_to_fetch}")
            gsi_response = table.query(
                IndexName=GSI_NAME,
                KeyConditionExpression=Key('RECETA').eq(recipe_id_to_fetch)
            )
            recipe_details_items = gsi_response.get('Items', [])
            
            if recipe_details_items:
                recipe_data = recipe_details_items[0]
                print(f"INFO getFavorites: Details found for {recipe_id_to_fetch}: {json.dumps(recipe_data, cls=DecimalEncoder)}")
                
                # Ensure the recipe_data has 'originalRecipeId' for the frontend.
                # recipe_id_to_fetch is the actual originalRecipeId.
                recipe_data['originalRecipeId'] = recipe_id_to_fetch

                # Basic check for essential fields
                if not recipe_data.get('nombre') or not recipe_data.get('RECETA') or recipe_data.get('RECETA') != recipe_id_to_fetch:
                    print(f"WARN getFavorites: Recipe data for {recipe_id_to_fetch} is incomplete or RECETA field mismatch. Data: {json.dumps(recipe_data, cls=DecimalEncoder)}")
                    # Decide if you want to skip this item or include it as is
                    # For now, let's skip if it's critically incomplete, e.g. no 'nombre'
                    if not recipe_data.get('nombre'):
                        print(f"WARN getFavorites: Skipping recipe {recipe_id_to_fetch} due to missing 'nombre'.")
                        continue # Skip this iteration
                detailed_favorites.append(recipe_data)
            else:
                print(f"WARN getFavorites: Could not find details for originalRecipeId: {recipe_id_to_fetch} using GSI {GSI_NAME}. This favorite marker will be skipped.")

        print(f"INFO getFavorites: Retrieved {len(detailed_favorites)} detailed favorite recipes for user {user_email}. Final list: {json.dumps(detailed_favorites, cls=DecimalEncoder)}")

        return {
            'statusCode': 200,
            'headers': cors_headers,
            'body': json.dumps({
                'favorites': detailed_favorites,
                'total': len(detailed_favorites)
            }, cls=DecimalEncoder)
        }

    except Exception as e:
        print(f"ERROR getFavorites: Exception: {str(e)}")
        import traceback
        print(f"Traceback: {traceback.format_exc()}")
        return {
            'statusCode': 500,
            'headers': cors_headers,
            'body': json.dumps({
                'message': 'Error fetching favorite recipes.',
                'error': str(e),
                'type': type(e).__name__
            })
        } 