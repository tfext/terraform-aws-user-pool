output "pool_arn" {
  value = aws_cognito_user_pool.pool.arn
}

output "pool_id" {
  value = aws_cognito_user_pool.pool.id
}

output "clients" {
  value = {
    for client in var.clients :
    client.name => {
      id = aws_cognito_user_pool_client.client[client.name].id
      identity_pool_id = try(module.identity_pool[client.name].id, null)
    }
  }
}

output "endpoint" {
  value       = aws_cognito_user_pool.pool.endpoint
  description = "The pool's endpoint, without a scheme"
}

output "issuer" {
  value       = "https://${aws_cognito_user_pool.pool.endpoint}"
  description = "The pool's token issuer"
}

output "domain" {
  value       = try(aws_cognito_user_pool_domain.domain[0].domain, null)
  description = "The pool's domain, when `auth_domain` is set"
}

output "domain_cloudfront_target" {
  value       = try(aws_cognito_user_pool_domain.domain[0].cloudfront_distribution, null)
  description = "CNAME target for the custom domain, when `certificate_arn` is set"
}

output "client_secrets" {
  value = {
    for client in var.clients :
    client.name => aws_cognito_user_pool_client.client[client.name].client_secret
    if contains(client.flows, "client_credentials")
  }
  sensitive   = true
  description = "Client secrets of client_credentials clients, by client name"
}
