const express = require('express');
const AWS = require('aws-sdk');
const path = require('path');
const cors = require('cors');
const morgan = require('morgan');
const moment = require('moment');

// 初始化 Express 应用
const app = express();
const port = process.env.PORT || 3000;

// 配置 AWS SDK
AWS.config.update({
  region: process.env.AWS_REGION || 'us-east-1',
  // 在 Fargate 中运行时，无需显式提供凭证，将使用任务执行角色
});

// 创建 DynamoDB 客户端
const dynamodb = new AWS.DynamoDB.DocumentClient();
const tableName = process.env.DYNAMODB_TABLE || 'url-shortener-table';

// 中间件
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));

// 设置视图引擎
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// 首页 - 仪表板
app.get('/', (req, res) => {
  res.render('dashboard');
});

// API 路由 - 获取总点击数
app.get('/api/stats/total-clicks', async (req, res) => {
  try {
    const params = {
      TableName: tableName,
      Select: 'COUNT'
    };
    
    const data = await dynamodb.scan(params).promise();
    
    res.json({
      totalClicks: data.Count,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('获取总点击数失败:', error);
    res.status(500).json({ error: '获取数据失败' });
  }
});

// API 路由 - 获取按小时的点击趋势
app.get('/api/stats/hourly-trends', async (req, res) => {
  try {
    const params = {
      TableName: tableName,
      ProjectionExpression: "created_at"
    };
    
    const data = await dynamodb.scan(params).promise();
    
    // 按小时分组点击数据
    const hourlyData = Array(24).fill(0);
    
    data.Items.forEach(item => {
      if (item.created_at) {
        const hour = new Date(item.created_at).getHours();
        hourlyData[hour]++;
      }
    });
    
    const labels = Array(24).fill().map((_, i) => `${i}:00`);
    
    res.json({
      labels: labels,
      data: hourlyData
    });
  } catch (error) {
    console.error('获取小时趋势数据失败:', error);
    res.status(500).json({ error: '获取数据失败' });
  }
});

// API 路由 - 获取最热门的短链接
app.get('/api/stats/top-links', async (req, res) => {
  try {
    const params = {
      TableName: tableName,
      ProjectionExpression: "short_code, original_url, visit_count",
    };
    
    const data = await dynamodb.scan(params).promise();
    
    // 按访问次数排序
    const sortedLinks = data.Items
      .filter(item => item.visit_count !== undefined)
      .sort((a, b) => (b.visit_count || 0) - (a.visit_count || 0))
      .slice(0, 10);
    
    res.json(sortedLinks);
  } catch (error) {
    console.error('获取热门链接失败:', error);
    res.status(500).json({ error: '获取数据失败' });
  }
});

// API 路由 - 获取最近创建的短链接
app.get('/api/stats/recent-links', async (req, res) => {
  try {
    const params = {
      TableName: tableName,
      ProjectionExpression: "short_code, original_url, created_at",
    };
    
    const data = await dynamodb.scan(params).promise();
    
    // 按创建时间排序
    const recentLinks = data.Items
      .filter(item => item.created_at !== undefined)
      .sort((a, b) => new Date(b.created_at) - new Date(a.created_at))
      .slice(0, 10)
      .map(item => ({
        ...item,
        created_at_formatted: moment(item.created_at).format('YYYY-MM-DD HH:mm:ss')
      }));
    
    res.json(recentLinks);
  } catch (error) {
    console.error('获取最近链接失败:', error);
    res.status(500).json({ error: '获取数据失败' });
  }
});

// 启动服务器
app.listen(port, () => {
  console.log(`Admin dashboard running on port ${port}`);
});