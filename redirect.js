const AWS = require('aws-sdk');
const dynamoDB = new AWS.DynamoDB.DocumentClient();
const sqs = new AWS.SQS();

// 配置
const TABLE_NAME = process.env.DYNAMODB_TABLE;
const STATS_QUEUE_URL = process.env.STATS_QUEUE;

/**
 * 根据短码从DynamoDB获取原始URL
 * @param {string} shortCode - 要查找的短码
 * @returns {Promise<string>} - 原始URL
 */
async function getOriginalUrl(shortCode) {
  const params = {
    TableName: TABLE_NAME,
    Key: {
      short_code: shortCode
    }
  };
  
  const result = await dynamoDB.get(params).promise();
  
  if (!result.Item) {
    throw new Error('找不到短链接');
  }
  
  return result.Item.original_url;
}

/**
 * 发送消息到SQS进行统计处理
 * @param {string} shortCode - 访问的短码
 * @returns {Promise} - SQS发送操作promise
 */
async function sendStatisticsEvent(shortCode) {
  const params = {
    QueueUrl: STATS_QUEUE_URL,
    MessageBody: JSON.stringify({
      shortCode,
      timestamp: Date.now()
    })
  };
  
  return sqs.sendMessage(params).promise();
}

/**
 * 用于重定向短链接的Lambda处理函数
 */
exports.handler = async (event) => {
  try {
    // 从路径参数获取短码
    const shortCode = event.pathParameters.shortCode;
    
    if (!shortCode) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type'
        },
        body: JSON.stringify({ error: '需要提供短码' })
      };
    }
    
    // 查询原始URL
    const originalUrl = await getOriginalUrl(shortCode);
    
    // 异步发送统计事件（不等待）
    sendStatisticsEvent(shortCode).catch(error => {
      console.error('发送统计事件错误:', error);
    });
    
    // 返回301重定向到原始URL
    return {
      statusCode: 301,
      headers: {
        'Location': originalUrl,
        'Cache-Control': 'no-cache',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
      },
      body: ''
    };
  } catch (error) {
    console.error('错误:', error);
    
    if (error.message === '找不到短链接') {
      return {
        statusCode: 404,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type'
        },
        body: JSON.stringify({ error: '找不到短链接' })
      };
    }
    
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
      },
      body: JSON.stringify({ error: '内部服务器错误' })
    };
  }
};