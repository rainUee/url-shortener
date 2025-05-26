# URL Shortener - AWS Serverless Project

A serverless URL shortener built with AWS services, similar to bit.ly. This project allows users to convert long URLs into short, easy-to-share links that redirect to the original destination.

## Architecture

┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Web Frontend  │───▶│   API Gateway    │───▶│  Lambda: Create │
│   (index.html)  │    │                  │    │   (create.py)   │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                │                        ▼
                                │               ┌─────────────────┐
                                │               │    DynamoDB     │
                                │               │   (URL Store)   │
                                │               └─────────────────┘
                                │                        │
                                ▼                        │
                       ┌─────────────────┐              │
                       │ Lambda: Redirect │◀─────────────┘
                       │  (redirect.py)   │
                       └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐    ┌─────────────────┐
                       │   SQS Queue     │───▶│Lambda: Statistics│
                       │  (Analytics)    │    │ (statistics.py) │
                       └─────────────────┘    └─────────────────┘
                       
This project uses a serverless architecture on AWS with the following services:

- **AWS Lambda**: Handles URL shortening and redirection logic
- **AWS Fargate/ECS**: Container service for hosting management backend, providing a statistical analysis interface for URL short links
- **API Gateway**: Provides REST API endpoints and handles HTTP redirects
- **DynamoDB**: Stores URL mappings (short code → original URL)
- **S3**: Stores front-end static web page files and provides a user interface
- **SQS**: Handles asynchronous processing of visit statistics

## Core Features

- **URL Shortening**: Convert long URLs to short, easy-to-share links
- **URL Redirection**: Automatically redirect from short URLs to original destinations
- **Visit Statistics**: Track the number of times each short link is accessed

## Project Structure

```
.
├── main.tf                    # Terraform infrastructure configuration
├── create.py                  # Lambda function for creating short URLs
├── redirect.py                # Lambda function for redirection
├── statistics.py              # Lambda function for processing statistics
├── index.html                 # Simple web frontend
├── package.sh                 # Script to package Lambda functions
└── README.md                  # Project documentation
```

## Setup Instructions

### Prerequisites

- AWS Account with appropriate permissions
- [AWS CLI](https://aws.amazon.com/cli/) configured with your credentials
- [Terraform](https://www.terraform.io/downloads.html) installed
- [Node.js](https://nodejs.org/) (for local testing)

### Deployment Steps

1. **Clone the repository**

   ```bash
   cd url-shortener
   ```

2. **Package Lambda functions**

   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

3. **Initialize Terraform**

   ```bash
   terraform init
   ```

4. **Deploy the infrastructure**

   ```bash
   terraform apply
   ```

5. **Take note of the outputs**

   After deployment, Terraform will output the API Gateway URL and CloudFront domain name. Save these for accessing your URL shortener.

## Implementation Details

### Short Code Generation

The system generates short codes using a random Base62 algorithm (a-z, A-Z, 0-9), creating 6-character codes by default. This provides approximately 56.8 billion possible combinations, making collisions extremely unlikely.

### DynamoDB Schema

| Field         | Type           | Description                           |
|---------------|----------------|---------------------------------------|
| short_code    | String (Key)   | The generated short code              |
| original_url  | String         | The original URL to redirect to       |
| created_at    | Number         | Timestamp of creation (Unix time)     |
| visit_count   | Number         | Number of times the link was accessed |

### API Endpoints

- **POST /shorten**: Create a new short URL
  - Request: `{ "url": "https://example.com/long/url" }`
  - Response: `{ "originalUrl": "https://example.com/long/url", "shortUrl": "https://short.com/abc123", "shortCode": "abc123" }`

- **GET /{shortCode}**: Redirect to the original URL
  - Response: HTTP 301 redirect to the original URL

## Costs and Scalability

This serverless architecture is designed to be cost-effective and highly scalable:

- **Pay-per-use**: You only pay for the actual usage (API calls, DynamoDB storage, etc.)
- **Auto-scaling**: The system scales automatically with traffic
- **Low maintenance**: No servers to manage or update

### Estimated Monthly Costs (1,000 generations, 100,000 redirects)

- API Gateway: ~$3.50
- Lambda: ~$0.20
- DynamoDB: ~$0.50
- SQS: Free tier likely covers usage
- Total: ~$4.30/month

## Future Enhancements

- Custom short codes (let users choose their preferred short code)
- User authentication and management (for premium features)
- Analytics dashboard for link performance
- URL expiration settings
- QR code generation for short links

## Security Considerations

- API rate limiting to prevent abuse
- Input validation to prevent malicious URLs
- DynamoDB encryption at rest

## Acknowledgments

- AWS for providing the serverless infrastructure
- Terraform for infrastructure as code capabilities