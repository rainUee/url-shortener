const https = require('https');
const readline = require('readline');

// Create readline interface for user input
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

// Replace with your actual API Gateway URL
let API_URL = '';

// Function to make an HTTPS request
function makeRequest(options, data = null) {
  return new Promise((resolve, reject) => {
    const req = https.request(options, (res) => {
      let responseData = '';
      
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          // Handle redirects
          resolve({
            statusCode: res.statusCode,
            headers: res.headers,
            body: null,
            redirectUrl: res.headers.location
          });
        } else {
          // Handle normal responses
          try {
            const parsedData = responseData ? JSON.parse(responseData) : null;
            resolve({
              statusCode: res.statusCode,
              headers: res.headers,
              body: parsedData
            });
          } catch (error) {
            resolve({
              statusCode: res.statusCode,
              headers: res.headers,
              body: responseData
            });
          }
        }
      });
    });
    
    req.on('error', (error) => {
      reject(error);
    });
    
    if (data) {
      req.write(data);
    }
    
    req.end();
  });
}

// Function to create a short URL
async function createShortUrl(longUrl) {
  console.log(`Creating short URL for: ${longUrl}`);
  
  const apiUrlParts = new URL(API_URL);
  
  const options = {
    hostname: apiUrlParts.hostname,
    path: `${apiUrlParts.pathname}/shorten`,
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    }
  };
  
  const data = JSON.stringify({
    url: longUrl
  });
  
  try {
    const response = await makeRequest(options, data);
    
    if (response.statusCode === 200 && response.body && response.body.shortUrl) {
      console.log('\n✅ Success! Short URL created:');
      console.log(`- Original URL: ${response.body.originalUrl}`);
      console.log(`- Short URL: ${response.body.shortUrl}`);
      console.log(`- Short Code: ${response.body.shortCode}`);
      return response.body.shortUrl;
    } else {
      console.error('\n❌ Failed to create short URL:');
      console.error(`- Status code: ${response.statusCode}`);
      console.error(`- Response: ${JSON.stringify(response.body, null, 2)}`);
      return null;
    }
  } catch (error) {
    console.error('\n❌ Error creating short URL:', error.message);
    return null;
  }
}

// Function to test a short URL (follow redirect)
async function testShortUrl(shortUrl) {
  console.log(`\nTesting short URL: ${shortUrl}`);
  
  const shortUrlParts = new URL(shortUrl);
  
  const options = {
    hostname: shortUrlParts.hostname,
    path: shortUrlParts.pathname,
    method: 'GET',
    // Don't follow redirects automatically
    followRedirect: false
  };
  
  try {
    const response = await makeRequest(options);
    
    if (response.statusCode >= 300 && response.statusCode < 400 && response.redirectUrl) {
      console.log('\n✅ Success! Redirect working:');
      console.log(`- Status code: ${response.statusCode}`);
      console.log(`- Redirects to: ${response.redirectUrl}`);
      return response.redirectUrl;
    } else {
      console.error('\n❌ Redirect failed:');
      console.error(`- Status code: ${response.statusCode}`);
      console.error(`- Response: ${JSON.stringify(response.body, null, 2)}`);
      return null;
    }
  } catch (error) {
    console.error('\n❌ Error testing short URL:', error.message);
    return null;
  }
}

// Main function
async function main() {
  // Get API URL from user
  rl.question('Enter your API Gateway URL (e.g., https://abc123.execute-api.us-east-1.amazonaws.com/prod or your CloudFront domain): ', async (url) => {
    API_URL = url.trim();
    
    if (!API_URL) {
      console.error('API URL is required.');
      rl.close();
      return;
    }
    
    // Get long URL from user
    rl.question('Enter a long URL to shorten (e.g., https://example.com/very/long/path): ', async (longUrl) => {
      if (!longUrl) {
        console.error('Long URL is required.');
        rl.close();
        return;
      }
      
      // Create short URL
      const shortUrl = await createShortUrl(longUrl);
      
      if (shortUrl) {
        // Test the short URL
        const redirectUrl = await testShortUrl(shortUrl);
        
        if (redirectUrl) {
          console.log('\n🎉 Test complete! The URL shortener is working properly.');
          console.log(`- Original URL: ${longUrl}`);
          console.log(`- Short URL: ${shortUrl}`);
          console.log(`- Redirects to: ${redirectUrl}`);
        }
      }
      
      rl.close();
    });
  });
}

// Run the main function
main();