variable "name" {
  type = string
  description = "Name of the user pool"
}

variable "name_suffix" {
  type = string
  default = ""
  description = "Suffix to apply to resource names"
}

variable "user_attributes" {
  type    = list(string)
  default = ["email"]
}

variable "resources" {
  type = list(object({
    id              = string
    name            = string
    scopes          = optional(list(string))
    allowed_clients = optional(list(string))
  }))
  description = "Resource servers. `scopes` lists the resource's scopes; without it, a scope is created for each of `allowed_clients`, named after the client"
}

variable "clients" {
  type = list(object({
    name               = string
    flows              = optional(list(string), ["code"])
    identity_providers = optional(list(string), ["COGNITO"])
    scopes             = optional(list(string), [])
    domain             = optional(string)
    login_path         = optional(string)
    logout_path        = optional(string)
    local_port         = optional(number)
    identity_pool = optional(object({
      unauthenticated_policy = object({ json = string })
      authenticated_policy   = object({ json = string })
    }))
  }))
  default     = []
  nullable    = false
  description = "App clients. `flows` is `[\"code\"]` for an application or `[\"client_credentials\"]` for a service; `scopes` are `<resource>/<scope>`"

  validation {
    condition = alltrue([
      for c in var.clients :
      length(c.flows) > 0 &&
      alltrue([for f in c.flows : contains(["code", "client_credentials"], f)]) &&
      !(contains(c.flows, "code") && contains(c.flows, "client_credentials"))
    ])
    error_message = "Each client's flows must be [\"code\"] or [\"client_credentials\"]."
  }

  validation {
    condition = alltrue([
      for c in var.clients :
      !contains(c.flows, "code") || (c.domain != null && c.login_path != null)
    ])
    error_message = "A code client needs domain and login_path."
  }
}

variable "identity_providers" {
  type = map(object({
    issuer     = string
    client_id  = string
    secret     = string
    scopes     = optional(string, "openid email profile")
    attributes = map(string)
  }))
  default     = {}
  nullable    = false
  sensitive   = true
  description = "OpenID Connect providers, keyed by provider name. `attributes` maps pool attributes to provider claims"
}

variable "security" {
  type = object({
    allow_sign_up        = optional(bool, true)
    password_min_length  = optional(number, 6)
    password_complexity  = optional(bool, false)
    mfa                  = optional(string, "OFF")
    access_token_minutes = optional(number, 60)
    refresh_token_days   = optional(number, 365)
    deletion_protection  = optional(bool, false)
  })
  default     = {}
  nullable    = false
  description = "Pool security settings"

  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.security.mfa)
    error_message = "security.mfa must be OFF, ON or OPTIONAL."
  }
}

variable "auth_domain" {
  type    = string
  default = null
}

variable "auth_logo" {
  type        = string
  default     = null
  description = "Filename of logo to use on hosted UI (requires custom domain)"
}

variable "auth_css" {
  type        = string
  default     = null
  description = "CSS to use on hosted UI (requires custom domain)"
}

variable "email" {
  type = object({
    source_arn = string
    from       = string
    reply_to   = string
  })
  default     = null
  description = "SES sending settings. `null` uses Cognito's own email sending"
}

variable "domain_zone_id" {
  type        = string
  default     = null
  description = "Route 53 zone for the custom domain's record. `null` creates no record (use the `domain_cloudfront_target` output)"
}

variable "certificate_arn" {
  type    = string
  default = null
}

variable "auto_confirm" {
  type    = bool
  default = false
}
