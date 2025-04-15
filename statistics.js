const AWS = require('aws-sdk');
const dynamoDB = new AWS.DynamoDB.DocumentClient();

// Configuration
const TABLE_NAME = process.env.DYNAMODB_TABLE;

/**
 * Update the visit count for a short URL
 * @param {string} shortCode - The short code to update
 * @returns {Promise} - DynamoDB update operation promise
 */
async function updateVisitCount(shortCode) {
  const params = {
    TableName: TABLE_NAME,
    Key: {
      short_code: shortCode
    },
    UpdateExpression: 'ADD visit_count :inc',
    ExpressionAttributeValues: {
      ':inc': 1
    },
    ReturnValues: 'UPDATED_NEW'
  };
  
  return dynamoDB.update(params).promise();
}

/**
 * Lambda handler for processing statistics events from SQS
 */
exports.handler = async (event) => {
  try {
    // Process each message from SQS
    const processPromises = event.Records.map(async (record) => {
      try {
        // Parse the message body
        const body = JSON.parse(record.body);
        const { shortCode, timestamp } = body;
        
        // Log for debugging
        console.log(`Processing statistics for short code: ${shortCode}, timestamp: ${timestamp}`);
        
        // Update the visit count
        const result = await updateVisitCount(shortCode);
        
        console.log(`Updated visit count for ${shortCode}:`, result);
        
        return {
          recordId: record.messageId,
          status: 'Success'
        };
      } catch (error) {
        console.error('Error processing record:', error);
        return {
          recordId: record.messageId,
          status: 'ProcessingFailed',
          error: error.message
        };
      }
    });
    
    // Wait for all promises to resolve
    const results = await Promise.all(processPromises);
    
    // Count successes and failures
    const successful = results.filter(r => r.status === 'Success').length;
    const failed = results.filter(r => r.status === 'ProcessingFailed').length;
    
    console.log(`Successfully processed ${successful} records, failed to process ${failed} records`);
    
    return {
      batchItemFailures: results
        .filter(r => r.status === 'ProcessingFailed')
        .map(r => ({
          itemIdentifier: r.recordId
        }))
    };
  } catch (error) {
    console.error('Error processing batch:', error);
    throw error;
  }
};