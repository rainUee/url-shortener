import json
import boto3
import os
import random
import string
import time
from typing import Dict, Any, Optional
import logging
from botocore.exceptions import ClientError

# Setup logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Configuration
TABLE_NAME = os.environ['DYNAMODB_TABLE']
BASE_URL = os.environ['BASE_URL']
SHORT_CODE_LENGTH = 6

# AWS clients
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(TABLE_NAME)

def generate_short_code(length: int) -> str:
    """
    Generate a random short code of specified length
    
    Args:
        length (int): Length of the short code
        
    Returns:
        str: Random short code
    """
    charset = string.ascii_letters + string.digits
    return ''.join(random.choice(charset) for _ in range(length))

def store_url_mapping(short_code: str, original_url: str) -> bool:
    """
    Store URL mapping in DynamoDB
    
    Args:
        short_code (str): Generated short code
        original_url (str): Original URL to redirect to
        
    Returns:
        bool: True if stored successfully, False if short code already exists
    """
    timestamp = int(time.time())
    
    try:
        table.put_item(
            Item={
                'short_code': short_code,
                'original_url': original_url,
                'created_at': timestamp,
                'visit_count': 0
            },
            # Ensure short code doesn't exist
            ConditionExpression='attribute_not_exists(short_code)'
        )
        return True
    except ClientError as e:
        # If short code already exists, return False
        if e.response['Error']['Code'] == 'ConditionalCheckFailedException':
            return False
        raise e

def create_cors_headers(origin: Optional[str] = None) -> Dict[str, str]:
    """
    Create CORS headers for the response
    
    Args:
        origin (Optional[str]): Specific origin to allow, defaults to wildcard
        
    Returns:
        Dict[str, str]: CORS headers
    """
    allowed_origin = origin if origin else '*'
    if 'FRONTEND_DOMAIN' in os.environ and origin:
        allowed_origin = f"http://{os.environ['FRONTEND_DOMAIN']}"
    
    return {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': allowed_origin,
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
    }

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for creating short links
    
    Args:
        event (Dict[str, Any]): Lambda event containing request data
        context (Any): Lambda context object
        
    Returns:
        Dict[str, Any]: HTTP response with short URL or error
    """
    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        
        # Validate input
        if not body.get('url'):
            return {
                'statusCode': 400,
                'headers': create_cors_headers(),
                'body': json.dumps({'error': 'URL is required'})
            }
        
        original_url = body['url']
        
        # Attempt to generate unique short code up to 3 times
        short_code = None
        is_stored = False
        attempts = 0
        
        while not is_stored and attempts < 3:
            short_code = generate_short_code(SHORT_CODE_LENGTH)
            is_stored = store_url_mapping(short_code, original_url)
            attempts += 1
        
        if not is_stored:
            return {
                'statusCode': 500,
                'headers': create_cors_headers(),
                'body': json.dumps({'error': 'Unable to generate unique short code'})
            }
        
        # Build short URL
        short_url = f"{BASE_URL}/{short_code}"
        
        # Return short URL
        return {
            'statusCode': 200,
            'headers': create_cors_headers(),
            'body': json.dumps({
                'originalUrl': original_url,
                'shortCode': short_code,
                'shortUrl': short_url
            })
        }
        
    except json.JSONDecodeError:
        return {
            'statusCode': 400,
            'headers': create_cors_headers(),
            'body': json.dumps({'error': 'Invalid JSON in request body'})
        }
    except Exception as error:
        logger.error(f"Error: {str(error)}")
        
        return {
            'statusCode': 500,
            'headers': create_cors_headers(),
            'body': json.dumps({'error': 'Internal server error'})
        }