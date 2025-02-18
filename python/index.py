import json
import openai
import os

# Set your OpenAI API key
openai.api_key = os.environ.get('OPENAI_KEY')

def lambda_handler(event, context):
    try:
        # Parse the event body
        body = json.loads(event.get('body', '{}'))  # Handle cases where 'body' might be missing
        
        # Extract the prompt
        prompt = body.get('prompt', 'write a haiku about AI')  # Default prompt if none provided

        # Request a completion from the OpenAI API
        completion = openai.ChatCompletion.create(
            model="gpt-4",
            messages=[{"role": "user", "content": prompt}]
        )
        
        # Return the response
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': completion['choices'][0]['message']['content']
            })
        }

    except Exception as e:
        return {
            'statusCode': 500,
            'body': json.dumps({'error': str(e)})
        }
