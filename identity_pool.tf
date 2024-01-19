locals {
  identity_pools = {
    for client in var.clients :
    client.name => client
    if client.identity_pool != null
  }
}

data "aws_iam_policy_document" "identity_authenticated" {
  for_each                = local.identity_pools
  source_policy_documents = [each.value.identity_pool.authenticated_policy.json]

  statement {
    sid       = "userPool"
    resources = [aws_cognito_user_pool.pool.arn]
    actions = [
      "userpool:SignUp",
      "userpool:ForgotPassword",
      "userpool:ConfirmForgotPassword"
    ]
  }
}

data "aws_iam_policy_document" "identity_unauthenticated" {
  for_each                = local.identity_pools
  source_policy_documents = [each.value.identity_pool.unauthenticated_policy.json]

  statement {
    sid       = "userPool"
    resources = [aws_cognito_user_pool.pool.arn]
    actions = [
      "userpool:SignUp",
      "userpool:ForgotPassword",
      "userpool:ConfirmForgotPassword"
    ]
  }
}

module "identity_pool" {
  for_each               = local.identity_pools
  source                 = "github.com/tfext/terraform-aws-identity-pool"
  name                   = "${var.name}-${each.key}${var.name_suffix}"
  unauthenticated_policy = data.aws_iam_policy_document.identity_unauthenticated[each.key]
  authenticated_policy   = data.aws_iam_policy_document.identity_authenticated[each.key]
  depends_on             = [aws_cognito_user_pool_client.client]

  clients = [
    {
      name      = aws_cognito_user_pool.pool.endpoint
      client_id = aws_cognito_user_pool_client.client[each.key].id
    }
  ]
}
