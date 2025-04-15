const AWS = require('aws-sdk');
const dynamoDB = new AWS.DynamoDB.DocumentClient();

// 配置
const TABLE_NAME = process.env.DYNAMODB_TABLE;
const BASE_URL = process.env.BASE_URL;
const SHORT_CODE_LENGTH = 6;

/**
 * 生成指定长度的随机短码
 * @param {number} length - 短码长度
 * @returns {string} - 随机短码
 */
function generateShortCode(length) {
  const charset = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  let result = '';

  for (let i = 0; i < length; i++) {
    const randomIndex = Math.floor(Math.random() * charset.length);
    result += charset[randomIndex];
  }

  return result;
}

/**
 * 在DynamoDB中存储URL映射
 * @param {string} shortCode - 生成的短码
 * @param {string} originalUrl - 要重定向到的原始URL
 * @returns {Promise} - DynamoDB操作promise
 */
async function storeUrlMapping(shortCode, originalUrl) {
  const timestamp = Math.floor(Date.now() / 1000);

  const params = {
    TableName: TABLE_NAME,
    Item: {
      short_code: shortCode,
      original_url: originalUrl,
      created_at: timestamp,
      visit_count: 0
    },
    // 确保短码不存在
    ConditionExpression: 'attribute_not_exists(short_code)'
  };

  try {
    await dynamoDB.put(params).promise();
    return true;
  } catch (error) {
    // 如果短码已存在，返回false
    if (error.code === 'ConditionalCheckFailedException') {
      return false;
    }
    throw error;
  }
}

/**
 * 用于创建短链接的Lambda处理函数
 */
exports.handler = async (event) => {
  try {
    // 解析请求体
    const body = JSON.parse(event.body);

    // 验证输入
    if (!body.url) {
      return {
        statusCode: 400,
        headers: {
          'Content-Type': 'application/json',
          "Access-Control-Allow-Origin": "http://" + process.env.FRONTEND_DOMAIN,
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type'
        },
        body: JSON.stringify({ error: '需要提供URL' })
      };
    }

    const originalUrl = body.url;

    // 尝试最多3次生成唯一短码
    let shortCode;
    let isStored = false;
    let attempts = 0;

    while (!isStored && attempts < 3) {
      shortCode = generateShortCode(SHORT_CODE_LENGTH);
      isStored = await storeUrlMapping(shortCode, originalUrl);
      attempts++;
    }

    if (!isStored) {
      return {
        statusCode: 500,
        headers: {
          'Content-Type': 'application/json',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type'
        },
        body: JSON.stringify({ error: '无法生成唯一短码' })
      };
    }

    // 构建短链接
    const shortUrl = `${BASE_URL}/${shortCode}`;

    // 返回短链接
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
      },
      body: JSON.stringify({
        originalUrl,
        shortCode,
        shortUrl
      })
    };
  } catch (error) {
    console.error('错误:', error);

    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
      },
      body: JSON.stringify({ error: '内部服务器错误' })
    };
  }
};