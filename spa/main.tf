##########################################################
# PROVIDERS
##########################################################
provider "aws" {
  region = var.aws_region # us-east-2 (S3 + API)
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1" # CloudFront, WAF, VPC Link, API GW
}

##########################################################
# REMOTE STATE REFERENCES
##########################################################
data "terraform_remote_state" "hosted_zones" {
  backend = "s3"
  config = {
    bucket = var.hosted_zones_state_bucket
    key    = var.hosted_zones_state_key
    region = "us-east-1"
  }
}

data "terraform_remote_state" "network" {
  backend = "s3"
  config = {
    bucket = var.network_state_bucket
    key    = var.network_state_key
    region = "us-east-1"
  }
}

data "terraform_remote_state" "ecs" {
  backend = "s3"
  config = {
    bucket = var.ecs_state_bucket
    key    = var.ecs_state_key
    region = "us-east-1"
  }
}

locals {
  root_domain         = data.terraform_remote_state.hosted_zones.outputs.root_domain
  public_zone_id      = data.terraform_remote_state.hosted_zones.outputs.public_zone_id
  cloudfront_cert_arn = data.terraform_remote_state.hosted_zones.outputs.cloudfront_cert_arn
  backend_nlb_arn     = data.terraform_remote_state.ecs.outputs.backend_alb_arn # NLB ARN
  backend_nlb_dns     = data.terraform_remote_state.ecs.outputs.backend_alb_dns_name
  ecs_tasks_sg_id     = data.terraform_remote_state.ecs.outputs.ecs_tasks_sg_id
  private_subnet_ids  = data.terraform_remote_state.network.outputs.private_subnet_ids
}

##########################################################
# S3 BUCKET (us-east-2)
##########################################################
resource "aws_s3_bucket" "spa_bucket" {
  provider      = aws
  bucket        = "students-spa-djuni"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "spa_public_access" {
  provider = aws
  bucket   = aws_s3_bucket.spa_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "spa_encryption" {
  provider = aws
  bucket   = aws_s3_bucket.spa_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

##########################################################
# API GATEWAY (us-east-1) + VPC LINK TO NLB
##########################################################
resource "aws_api_gateway_vpc_link" "backend_vpc_link" {
  provider    = aws.us_east_1
  name        = "students-vpc-link"
  target_arns = [local.backend_nlb_arn]
  //security_group_ids = ecs_tasks_sg_id
  //private_subnet_ids = data.terraform_remote_state.network.outputs.private_subnet_ids
}

resource "aws_api_gateway_rest_api" "students_api" {
  provider = aws.us_east_1
  name     = "students-api"
}

resource "aws_api_gateway_resource" "api_root" {
  provider    = aws.us_east_1
  rest_api_id = aws_api_gateway_rest_api.students_api.id
  parent_id   = aws_api_gateway_rest_api.students_api.root_resource_id
  path_part   = "api"
}

resource "aws_api_gateway_resource" "students_resource" {
  provider    = aws.us_east_1
  rest_api_id = aws_api_gateway_rest_api.students_api.id
  parent_id   = aws_api_gateway_resource.api_root.id
  path_part   = "students"
}

resource "aws_api_gateway_method" "get_students" {
  provider      = aws.us_east_1
  rest_api_id   = aws_api_gateway_rest_api.students_api.id
  resource_id   = aws_api_gateway_resource.students_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "students_integration" {
  provider                = aws.us_east_1
  rest_api_id             = aws_api_gateway_rest_api.students_api.id
  resource_id             = aws_api_gateway_resource.students_resource.id
  http_method             = aws_api_gateway_method.get_students.http_method
  type                    = "HTTP"
  integration_http_method = "GET"
  uri                     = "http://${local.backend_nlb_dns}/students"

  connection_type = "VPC_LINK"
  connection_id   = aws_api_gateway_vpc_link.backend_vpc_link.id
}

resource "aws_api_gateway_deployment" "students_deploy" {
  provider    = aws.us_east_1
  rest_api_id = aws_api_gateway_rest_api.students_api.id

  depends_on = [aws_api_gateway_integration.students_integration]
  triggers = {
    redeploy = sha1(timestamp())
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "students_stage" {
  provider      = aws.us_east_1
  stage_name    = "prod"
  rest_api_id   = aws_api_gateway_rest_api.students_api.id
  deployment_id = aws_api_gateway_deployment.students_deploy.id
}

##########################################################
# CLOUD FRONT + WAF (us-east-1 REQUIRED)
##########################################################
resource "aws_cloudfront_origin_access_control" "oac" {
  name        = "students-spa-oac"
  provider    = aws.us_east_1
  description = "API Gateway origin"
  //origin_type                       = "web"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "never"
  signing_protocol                  = "sigv4"
}

resource "aws_wafv2_web_acl" "cf_waf" {
  provider = aws.us_east_1

  name        = "students-cf-waf"
  description = "WAF for CloudFront"
  scope       = "CLOUDFRONT"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "studentsWAF"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "commonRules"
      sampled_requests_enabled   = true
    }
  }
}

resource "aws_s3_bucket_policy" "spa_bucket_policy" {
  provider = aws
  bucket   = aws_s3_bucket.spa_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontAccess"
        Effect    = "Allow"
        Principal = { Service = "cloudfront.amazonaws.com" }
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.spa_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.spa_cf.arn
          }
        }
      }
    ]
  })
}

resource "aws_cloudfront_distribution" "spa_cf" {
  provider = aws.us_east_1

  enabled             = true
  aliases             = ["${var.students_subdomain}.${local.root_domain}"]
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.spa_bucket.bucket_regional_domain_name
    origin_id                = "spa-s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id

    s3_origin_config {
      origin_access_identity = ""
    }
  }

  origin {
    domain_name = "${aws_api_gateway_rest_api.students_api.id}.execute-api.us-east-1.amazonaws.com"
    origin_id   = "api-gw-origin"
    origin_path = "/prod"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "spa-s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "api-gw-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      cookies { forward = "none" }
    }
  }

  #  REQUIRED BLOCK — You were missing this!
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = local.cloudfront_cert_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  web_acl_id = aws_wafv2_web_acl.cf_waf.arn
}



resource "aws_route53_record" "students_app" {
  zone_id = local.public_zone_id
  name    = "${var.students_subdomain}.${local.root_domain}"
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.spa_cf.domain_name
    zone_id                = aws_cloudfront_distribution.spa_cf.hosted_zone_id
    evaluate_target_health = false
  }
}

# Build & upload frontend React SPA to S3
resource "null_resource" "build_and_upload_frontend" {
  # Rebuild when SPA bucket changes or frontend code changes
  triggers = {
    spa_bucket = aws_s3_bucket.spa_bucket.id
    # ensure change when package-lock or webpack changes
    frontend_hash = filesha256("${path.module}/../frontend-app/package-lock.json")
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]

    command = <<-EOT
      set -e
      echo "Building frontend React app..."

      cd "${path.module}/../frontend-app"

      npm install
      npm run build

      echo "Uploading dist/ to S3 bucket ${aws_s3_bucket.spa_bucket.id}..."
      aws s3 sync dist "s3://${aws_s3_bucket.spa_bucket.id}" --delete

      echo "Frontend deployment completed."
    EOT
  }
}

output "spa_bucket_name" {
  value = aws_s3_bucket.spa_bucket.id
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.spa_cf.domain_name
}

