terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  backend "s3" {
    bucket         = "djuni-terraform-state"
    key            = "hosted-zones/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "djuni-terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_route53_zone" "public" {
  name = var.root_domain
}

resource "aws_acm_certificate" "cloudfront_cert" {
  domain_name       = "*.${var.root_domain}"
  validation_method = "DNS"
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in tolist(aws_acm_certificate.cloudfront_cert.domain_validation_options) :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = aws_route53_zone.public.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}



resource "aws_acm_certificate_validation" "validated" {
  certificate_arn         = aws_acm_certificate.cloudfront_cert.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

output "public_zone_id" {
  value = aws_route53_zone.public.zone_id
}

output "cloudfront_cert_arn" {
  value = aws_acm_certificate.cloudfront_cert.arn
}

output "root_domain" {
  value = var.root_domain
}
