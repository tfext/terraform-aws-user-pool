locals {
  domain_count = try(length(var.auth_domain) > 0, false) ? 1 : 0
  custom_domain_count = (local.domain_count > 0) && try(length(var.certificate_arn) > 0, false) ? 1 : 0
}

resource "aws_cognito_user_pool_domain" "domain" {
  count           = local.domain_count
  domain          = var.auth_domain
  user_pool_id    = aws_cognito_user_pool.pool.id
  certificate_arn = var.certificate_arn
}

resource "aws_route53_record" "domain" {
  count   = local.custom_domain_count
  name    = var.auth_domain
  zone_id = var.domain_zone_id
  type    = "A"

  alias {
    evaluate_target_health = false
    name                   = aws_cognito_user_pool_domain.domain.0.cloudfront_distribution_arn
    zone_id                = aws_cognito_user_pool_domain.domain.0.cloudfront_distribution_zone_id
  }
}
