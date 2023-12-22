locals {
  has_auth_logo   = try(length(var.auth_logo) > 0, false)
  has_auth_css    = try(length(var.auth_css) > 0, false)
  custom_ui_count = local.custom_domain_count * (local.has_auth_logo || local.has_auth_css ? 1 : 0)
}

resource "aws_cognito_user_pool_ui_customization" "main" {
  user_pool_id = aws_cognito_user_pool.pool.id
  image_file   = local.has_auth_logo ? filebase64(var.auth_logo) : null
  css          = local.has_auth_css ? var.auth_css : null
}
