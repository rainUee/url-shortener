import json
import boto3
import os
from typing import Dict, List, Any
import logging

# Setup logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table(os.environ['DYNAMODB_TABLE'])

def update_visit_count(short_code: str) -> Dict[str, Any]:
    """
    Update the visit count for a short URL
    
    Args:
        short_code (str): The short code to update
        
    Returns:
        Dict[str, Any]: DynamoDB update operation response
    """
    try:
        response = table.update_item(
            Key={'short_code': short_code},
            UpdateExpression='ADD visit_count :inc',
            ExpressionAttributeValues={':inc': 1},
            ReturnValues='UPDATED_NEW'
        )
        return response
    except Exception as e:
        logger.error(f"Error updating visit count for {short_code}: {str(e)}")
        raise

def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Lambda handler for processing statistics events from SQS
    
    Args:
        event (Dict[str, Any]): Lambda event containing SQS records
        context (Any): Lambda context object
        
    Returns:
        Dict[str, Any]: Batch processing results
    """
    try:
        results = []
        
        # Process each message from SQS
        for record in event.get('Records', []):
            try:
                # Parse the message body
                body = json.loads(record['body'])
                short_code = body.get('shortCode')
                timestamp = body.get('timestamp')
                
                # Log for debugging
                logger.info(f"Processing statistics for short code: {short_code}, timestamp: {timestamp}")
                
                # Update the visit count
                result = update_visit_count(short_code)
                
                logger.info(f"Updated visit count for {short_code}: {result}")
                
                results.append({
                    'recordId': record['messageId'],
                    'status': 'Success'
                })
                
            except Exception as error:
                logger.error(f"Error processing record: {str(error)}")
                results.append({
                    'recordId': record['messageId'],
                    'status': 'ProcessingFailed',
                    'error': str(error)
                })
        
        # Count successes and failures
        successful = len([r for r in results if r['status'] == 'Success'])
        failed = len([r for r in results if r['status'] == 'ProcessingFailed'])
        
        logger.info(f"Successfully processed {successful} records, failed to process {failed} records")
        
        # Return batch item failures for SQS retry mechanism
        return {
            'batchItemFailures': [
                {'itemIdentifier': r['recordId']} 
                for r in results if r['status'] == 'ProcessingFailed'
            ]
        }
        
    except Exception as error:
        logger.error(f"Error processing batch: {str(error)}")
        raise error