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
    allowed_clients = list(string)
  }))
}

variable "clients" {
  type = list(object({
    name        = string
    domain      = string
    login_path  = string
    logout_path = string
    local_port  = optional(number)
    identity_pool = optional(object({
      unauthenticated_policy = object({ json = string })
      authenticated_policy   = object({ json = string })
    }))
  }))
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
}

variable "domain_zone_id" {
  type = string
}

variable "certificate_arn" {
  type    = string
  default = null
}

variable "auto_confirm" {
  type    = bool
  default = false
}
