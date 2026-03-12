provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "portfolio_bucket" {
  bucket = "carlos-portfolio-927b3aff"

}

resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.portfolio_bucket.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "visitor_table" {
  name         = "visitor-count"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}


resource "aws_dynamodb_table" "contact_table" {
  name         = "contact-messages"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "message_id"

  attribute {
    name = "message_id"
    type = "S"
  }
}



resource "aws_iam_role" "lambda_role" {
  name = "visitor_lambda_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name = "lambda_dynamodb_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ]
        Resource = [
          aws_dynamodb_table.visitor_table.arn,
          aws_dynamodb_table.contact_table.arn
        ]
      }
    ]
  })
}


resource "aws_sns_topic" "contact_notifications" {
  name = "portfolio-contact-notifications"
}

resource "aws_sns_topic_subscription" "email_alerts" {
  topic_arn = aws_sns_topic.contact_notifications.arn
  protocol  = "email"
  endpoint  = "carlos.alers.fuentes@gmail.com"
}


resource "aws_iam_policy" "lambda_sns_policy" {

  name = "lambda_sns_policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.contact_notifications.arn
      }
    ]
  })
}


resource "aws_iam_role_policy_attachment" "lambda_sns_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_sns_policy.arn
}



resource "aws_iam_role_policy_attachment" "lambda_dynamodb_attach" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}


resource "aws_lambda_function" "visitor_lambda" {
  function_name = "visitor-counter"

  runtime = "python3.11"
  handler = "visitor_counter.lambda_handler"
  role    = aws_iam_role.lambda_role.arn

  filename         = "../lambda/visitor.zip"
  source_code_hash = filebase64sha256("../lambda/visitor.zip")

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.visitor_table.name
    }
  }
}



resource "aws_lambda_function" "contact_lambda" {

  function_name = "contact-form"

  filename = "../lambda/contact.zip"
  handler  = "contact_form.lambda_handler"
  runtime  = "python3.11"

  role = aws_iam_role.lambda_role.arn

  source_code_hash = filebase64sha256("../lambda/contact.zip")

  environment {
    variables = {
      TABLE_NAME     = aws_dynamodb_table.contact_table.name
      SNS_TOPIC_ARN  = aws_sns_topic.contact_notifications.arn
      ALLOWED_ORIGIN = "*"
    }
  }
}



resource "aws_apigatewayv2_api" "visitor_api" {
  name          = "visitor-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type"]

  }
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.visitor_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.visitor_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "visitor_route" {
  api_id    = aws_apigatewayv2_api.visitor_api.id
  route_key = "GET /visitor"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_lambda_permission" "api_permission" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitor_api.execution_arn}/*/*"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.visitor_api.id
  name        = "$default"
  auto_deploy = true
}


resource "aws_apigatewayv2_integration" "contact_integration" {

  api_id = aws_apigatewayv2_api.visitor_api.id

  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.contact_lambda.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "contact_route" {

  api_id = aws_apigatewayv2_api.visitor_api.id

  route_key = "POST /contact"

  target = "integrations/${aws_apigatewayv2_integration.contact_integration.id}"
}


resource "aws_lambda_permission" "api_contact_permission" {

  statement_id = "AllowAPIGatewayInvokeContact"

  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.contact_lambda.function_name

  principal = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.visitor_api.execution_arn}/*/*"
}



resource "aws_cloudwatch_dashboard" "portfolio_dashboard" {
  dashboard_name = "aws-portfolio-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text",
        x      = 0,
        y      = 0,
        width  = 24,
        height = 1,
        properties = {
          markdown = "# AWS Portfolio Dashboard\nMonitoring Lambda, API Gateway, and DynamoDB"
        }
      },
      {
        type   = "metric",
        x      = 0,
        y      = 1,
        width  = 12,
        height = 6,
        properties = {
          title   = "Lambda Invocations and Errors"
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          stat    = "Sum"
          period  = 300
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.visitor_lambda.function_name],
            [".", "Errors", ".", "."],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.contact_lambda.function_name],
            [".", "Errors", ".", "."]
          ]
        }
      },
      {
        type   = "metric",
        x      = 12,
        y      = 1,
        width  = 12,
        height = 6,
        properties = {
          title   = "Lambda Duration"
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          stat    = "Average"
          period  = 300
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.visitor_lambda.function_name],
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.contact_lambda.function_name]
          ]
        }
      },
      {
        type   = "metric",
        x      = 0,
        y      = 7,
        width  = 12,
        height = 6,
        properties = {
          title   = "API Gateway Requests, 4XX, 5XX"
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          stat    = "Sum"
          period  = 300
          metrics = [
            ["AWS/ApiGateway", "Count", "ApiId", aws_apigatewayv2_api.visitor_api.id],
            [".", "4xx", ".", "."],
            [".", "5xx", ".", "."]
          ]
        }
      },
      {
        type   = "metric",
        x      = 12,
        y      = 7,
        width  = 12,
        height = 6,
        properties = {
          title   = "API Gateway Latency"
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          stat    = "Average"
          period  = 300
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiId", aws_apigatewayv2_api.visitor_api.id]
          ]
        }
      },
      {
        type   = "metric",
        x      = 0,
        y      = 13,
        width  = 12,
        height = 6,
        properties = {
          title   = "DynamoDB User and System Errors"
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          stat    = "Sum"
          period  = 300
          metrics = [
            ["AWS/DynamoDB", "UserErrors", "TableName", aws_dynamodb_table.visitor_table.name],
            [".", "SystemErrors", ".", "."],
            ["AWS/DynamoDB", "UserErrors", "TableName", aws_dynamodb_table.contact_table.name],
            [".", "SystemErrors", ".", "."]
          ]
        }
      },
      {
        type   = "metric",
        x      = 12,
        y      = 13,
        width  = 12,
        height = 6,
        properties = {
          title   = "DynamoDB Successful Request Latency"
          view    = "timeSeries"
          stacked = false
          region  = "us-east-1"
          stat    = "Average"
          period  = 300
          metrics = [
            ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", aws_dynamodb_table.visitor_table.name, "Operation", "UpdateItem"],
            ["AWS/DynamoDB", "SuccessfulRequestLatency", "TableName", aws_dynamodb_table.contact_table.name, "Operation", "PutItem"]
          ]
        }
      }
    ]
  })
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "portfolio-oac"
  description                       = "OAC for portfolio S3 bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}


resource "aws_cloudfront_distribution" "portfolio_cdn" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.portfolio_bucket.bucket_regional_domain_name
    origin_id                = "portfolioS3Origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    target_origin_id       = "portfolioS3Origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}


resource "aws_s3_bucket_policy" "allow_cloudfront" {
  bucket = aws_s3_bucket.portfolio_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.portfolio_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.portfolio_cdn.arn
          }
        }
      }
    ]
  })
}












