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

#output "domain" {
#  value = aws_cognito_user_pool_domain.domain.domain
#}