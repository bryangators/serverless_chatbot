import json
import openai
import os

# Set your OpenAI API key from env var
client = openai.OpenAI(api_key=os.environ.get('OPENAI_KEY'))

def lambda_handler(event, context):
    try:
        if "body" in event:
            body = json.loads(event['body']) if isinstance(event['body'], str) else event['body']
        else:
            body = event

        # Extract the prompt
        prompt = body.get('prompt', 'write a haiku about AI')  # Default prompt if none provided

        # Request a completion from the OpenAI API
        completion = client.chat.completions.create(
            model="gpt-4o",
            messages=[{"role": "user", "content": prompt}]
        )
        
        message_content = completion.choices[0].message.content

        # Return the response
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': json.dumps({'message': message_content})
            })
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
