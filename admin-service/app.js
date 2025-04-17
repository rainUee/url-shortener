const express = require('express');
const AWS = require('aws-sdk');
const path = require('path');
const cors = require('cors');
const morgan = require('morgan');
const moment = require('moment');

// Initialize Express app
const app = express();
const port = process.env.PORT || 3000;

// Configure AWS SDK
AWS.config.update({
  region: process.env.AWS_REGION || 'us-east-1',
  // When running in Fargate, no need to explicitly provide credentials, task execution role will be used
});

// Create DynamoDB client
const dynamodb = new AWS.DynamoDB.DocumentClient();
const tableName = process.env.DYNAMODB_TABLE || 'url-shortener-table';

// Middleware
app.use(cors());
app.use(morgan('combined'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));

// Set view engine
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Homepage - Dashboard
app.get('/', (req, res) => {
  res.render('dashboard');
});

// API Route - Get total clicks
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
    console.error('Failed to get total clicks:', error);
    res.status(500).json({ error: 'Failed to get data' });
  }
});

// API Route - Get hourly click trends
app.get('/api/stats/hourly-trends', async (req, res) => {
  try {
    const params = {
      TableName: tableName,
      ProjectionExpression: "created_at"
    };
    
    const data = await dynamodb.scan(params).promise();
    
    // Group click data by hour
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
    console.error('Failed to get hourly trend data:', error);
    res.status(500).json({ error: 'Failed to get data' });
  }
});

// API Route - Get top short links
app.get('/api/stats/top-links', async (req, res) => {
  try {
    const params = {
      TableName: tableName,
      ProjectionExpression: "short_code, original_url, visit_count",
    };
    
    const data = await dynamodb.scan(params).promise();
    
    // Sort by visit count
    const sortedLinks = data.Items
      .filter(item => item.visit_count !== undefined)
      .sort((a, b) => (b.visit_count || 0) - (a.visit_count || 0))
      .slice(0, 10);
    
    res.json(sortedLinks);
  } catch (error) {
    console.error('Failed to get top links:', error);
    res.status(500).json({ error: 'Failed to get data' });
  }
});

// API Route - Get recently created short links
app.get('/api/stats/recent-links', async (req, res) => {
  try {
    const params = {
      TableName: tableName,
      ProjectionExpression: "short_code, original_url, created_at",
    };
    
    const data = await dynamodb.scan(params).promise();
    
    // Sort by creation time
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
    console.error('Failed to get recent links:', error);
    res.status(500).json({ error: 'Failed to get data' });
  }
});

// Start server
app.listen(port, () => {
  console.log(`Admin dashboard running on port ${port}`);
});