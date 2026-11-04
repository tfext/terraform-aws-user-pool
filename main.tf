locals {
  name = "${var.name}${var.name_suffix}"

  # Scopes created for each resource: its own list, or else one per allowed client
  resource_scopes = {
    for r in var.resources :
    r.id => r.scopes != null ? r.scopes : (r.allowed_clients == null ? [] : r.allowed_clients)
  }

  # Pool attributes mapped from each identity provider, which a client offering it must read and write
  provider_attributes = {
    for name in nonsensitive(keys(var.identity_providers)) :
    name => [for a in nonsensitive(keys(var.identity_providers[name].attributes)) : a if a != "username"]
  }
}

resource "aws_cognito_user_pool" "pool" {
  name                = local.name
  username_attributes = var.user_attributes
  mfa_configuration   = var.security.mfa
  deletion_protection = var.security.deletion_protection ? "ACTIVE" : "INACTIVE"

  admin_create_user_config {
    allow_admin_create_user_only = !var.security.allow_sign_up
  }

  password_policy {
    minimum_length                   = var.security.password_min_length
    require_lowercase                = var.security.password_complexity
    require_numbers                  = var.security.password_complexity
    require_symbols                  = var.security.password_complexity
    require_uppercase                = var.security.password_complexity
    temporary_password_validity_days = 90
  }

  dynamic "software_token_mfa_configuration" {
    for_each = var.security.mfa == "OFF" ? [] : [1]
    content {
      enabled = true
    }
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

  dynamic "email_configuration" {
    for_each = var.email == null ? [] : [var.email]
    content {
      source_arn             = email_configuration.value.source_arn
      email_sending_account  = "DEVELOPER"
      from_email_address     = email_configuration.value.from
      reply_to_email_address = email_configuration.value.reply_to
    }
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
    for_each = toset(local.resource_scopes[each.key])
    content {
      scope_name        = scope.key
      scope_description = "${title(scope.key)} access"
    }
  }
}

resource "aws_cognito_identity_provider" "provider" {
  for_each      = nonsensitive(toset(keys(var.identity_providers)))
  user_pool_id  = aws_cognito_user_pool.pool.id
  provider_name = each.key
  provider_type = "OIDC"

  provider_details = {
    client_id                 = var.identity_providers[each.key].client_id
    client_secret             = var.identity_providers[each.key].secret
    attributes_request_method = "GET"
    oidc_issuer               = var.identity_providers[each.key].issuer
    authorize_scopes          = var.identity_providers[each.key].scopes
  }

  attribute_mapping = var.identity_providers[each.key].attributes

  lifecycle {
    # Filled in by Cognito from the issuer's discovery document
    ignore_changes = [
      provider_details["attributes_url"],
      provider_details["attributes_url_add_attributes"],
      provider_details["authorize_url"],
      provider_details["jwks_uri"],
      provider_details["token_url"],
    ]
  }
}

resource "aws_cognito_user_pool_client" "client" {
  for_each                             = { for c in var.clients : c.name => c }
  name                                 = "${var.name}-${each.value.name}${var.name_suffix}"
  user_pool_id                         = aws_cognito_user_pool.pool.id
  supported_identity_providers         = each.value.identity_providers
  allowed_oauth_flows                  = each.value.flows
  generate_secret                      = contains(each.value.flows, "client_credentials") ? true : null
  allowed_oauth_flows_user_pool_client = true
  access_token_validity                = var.security.access_token_minutes
  id_token_validity                    = var.security.access_token_minutes
  refresh_token_validity               = var.security.refresh_token_days

  write_attributes = distinct(concat(
    ["email"],
    flatten([for p in each.value.identity_providers : lookup(local.provider_attributes, p, [])])
  ))

  read_attributes = distinct(concat(
    ["email", "email_verified"],
    flatten([for p in each.value.identity_providers : lookup(local.provider_attributes, p, [])])
  ))

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }

  callback_urls = contains(each.value.flows, "code") ? concat(
    ["https://${each.value.domain}${each.value.login_path}"],
    each.value.local_port == null ? [] : ["http://localhost:${each.value.local_port}${each.value.login_path}"]
  ) : null

  logout_urls = contains(each.value.flows, "code") && each.value.logout_path != null ? concat(
    ["https://${each.value.domain}${each.value.logout_path}"],
    each.value.local_port == null ? [] : ["http://localhost:${each.value.local_port}${each.value.logout_path}"]
  ) : null

  allowed_oauth_scopes = concat(
    contains(each.value.flows, "code") ? ["email", "openid", "profile"] : [],
    [
      for resource in var.resources :
      "${resource.id}/${each.value.name}"
      if resource.scopes == null && contains(local.resource_scopes[resource.id], each.value.name)
    ],
    each.value.scopes
  )

  depends_on = [aws_cognito_resource_server.resource, aws_cognito_identity_provider.provider]
}
