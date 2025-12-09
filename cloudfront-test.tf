provider "aws" {
  region = "us-east-2"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

resource "aws_s3_bucket" "spa_bucket" {
  bucket = "students-spa-djuni-test123"
}

resource "aws_cloudfront_origin_access_control" "oac" {
  provider = aws.us_east_1

  name                              = "oac-test"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "test_cf" {
  provider = aws.us_east_1

  enabled             = true
  default_root_object = "index.html"

  # S3 Origin
  origin {
    domain_name              = aws_s3_bucket.spa_bucket.bucket_regional_domain_name
    origin_id                = "s3origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id

    s3_origin_config {
      origin_access_identity = null
    }
  }

  # API Origin
  origin {
    domain_name = "example.execute-api.us-east-2.amazonaws.com"
    origin_id   = "apigw"
    origin_path = "/prod"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3origin"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["GET", "HEAD"]
    cached_methods  = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
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
