locals {
  auto_confirm = var.auto_confirm ? { "auto_confirm" = 1 } : {}
}

module "auto_confirm_trigger" {
  for_each   = local.auto_confirm
  source     = "github.com/tfext/terraform-aws-lambda-function"
  name       = "${var.name}-autoconfirm${var.name_suffix}"
  source_dir = "${path.module}/auto_confirm_lambda"
  entrypoint = "index"
  runtime    = "nodejs18.x"
}

resource "aws_lambda_permission" "auto_confirm_trigger" {
  for_each   = local.auto_confirm
  function_name = module.auto_confirm_trigger["auto_confirm"].function_name
  qualifier     = module.auto_confirm_trigger["auto_confirm"].latest_qualifier
  action        = "lambda:InvokeFunction"
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.pool.arn
}
