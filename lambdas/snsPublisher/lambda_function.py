import boto3
import json

sns = boto3.client('sns')

def lambda_handler(event, context):
    for record in event['Records']:
        try:
            mensaje = json.loads(record['body'])

            topic_arn = mensaje.get('topic_arn')
            subject = mensaje.get('subject', 'Notificación')
            message = mensaje.get('message')

            sns.publish(
                TopicArn=topic_arn,
                Message=message,
                Subject=subject
            )

        except Exception as e:
            return {
                'statusCode': 500,
                'body': json.dumps({'error': str(e)})
            }