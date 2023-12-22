locals {
  name = "${var.name}${var.name_suffix}"
}

resource "aws_cognito_user_pool" "pool" {
  name                = local.name
  username_attributes = var.user_attributes
  mfa_configuration   = "OFF"

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  password_policy {
    minimum_length                   = 6
    require_lowercase                = false
    require_numbers                  = false
    require_symbols                  = false
    require_uppercase                = false
    temporary_password_validity_days = 90
  }

  schema {
    attribute_data_type = "String"
    name                = "email"
    mutable             = true

    string_attribute_constraints {
      min_length = "0"
      max_length = "2048"
    }
  }

  email_configuration {
    source_arn             = var.email.source_arn
    email_sending_account  = "DEVELOPER"
    from_email_address     = var.email.from
    reply_to_email_address = var.email.reply_to
  }

  dynamic "lambda_config" {
    for_each = local.auto_confirm
    content {
      pre_sign_up = module.auto_confirm_trigger["auto_confirm"].latest_arn
    }
  }
}

resource "aws_cognito_resource_server" "resource" {
  for_each     = { for r in var.resources : r.id => r }
  identifier   = each.value.id
  name         = "${title(var.name)} ${each.value.name}"
  user_pool_id = aws_cognito_user_pool.pool.id

  dynamic "scope" {
    for_each = toset(each.value.allowed_clients)
    content {
      scope_name        = scope.key
      scope_description = "${title(scope.key)} access"
    }
  }
}

resource "aws_cognito_user_pool_client" "client" {
  for_each                             = { for c in var.clients : c.name => c }
  name                                 = "${var.name}-${each.value.name}${var.name_suffix}"
  user_pool_id                         = aws_cognito_user_pool.pool.id
  supported_identity_providers         = ["COGNITO"]
  allowed_oauth_flows                  = ["code"]
  write_attributes                     = ["email"]
  read_attributes                      = ["email", "email_verified"]
  allowed_oauth_flows_user_pool_client = true
  refresh_token_validity               = 365

  callback_urls = concat(
    ["https://${each.value.domain}${each.value.login_path}"],
    each.value.local_port == null ? [] : ["http://localhost:${each.value.local_port}${each.value.login_path}"]
  )

  logout_urls = concat(
    ["https://${each.value.domain}${each.value.logout_path}"],
    each.value.local_port == null ? [] : ["http://localhost:${each.value.local_port}${each.value.logout_path}"]
  )

  allowed_oauth_scopes = concat(
    ["email", "openid", "profile"],
    [
      for resource in var.resources :
      "${resource.id}/${each.value.name}"
      if contains(resource.allowed_clients, each.value.name)
    ]
  )

  depends_on = [aws_cognito_resource_server.resource]
}
