# terraform-aws-user-pool

Create an AWS Cognito User Pool, with its resource servers, app clients,
OpenID Connect identity providers, domain and hosted UI styling.

## Example

```hcl
module "user_pool" {
  source = "github.com/tfext/terraform-aws-user-pool?ref=<tag>"

  name            = "ppta"
  name_suffix     = "-stg"
  auth_domain     = "auth-staging.example.com"
  certificate_arn = aws_acm_certificate.wildcard.arn
  domain_zone_id  = null # no Route 53 record; add a CNAME to domain_cloudfront_target

  security = {
    allow_sign_up       = false
    password_min_length = 14
    password_complexity = true
    mfa                 = "ON"
    refresh_token_days  = 30
  }

  identity_providers = {
    Entra = {
      issuer     = "https://login.microsoftonline.com/<tenant>/v2.0"
      client_id  = "<client id>"
      secret     = "<client secret>"
      attributes = { email = "email", name = "name", username = "sub" }
    }
  }

  resources = [{ id = "data", name = "Data API", scopes = ["read", "write"] }]

  clients = [
    {
      name               = "web"
      identity_providers = ["Entra"]
      domain             = "web.example.com"
      login_path         = "/auth/callback"
      logout_path        = "/"
      scopes             = ["data/read"]
    },
    { name = "worker", flows = ["client_credentials"], scopes = ["data/read", "data/write"] },
  ]
}
```

## Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | required | Name of the user pool |
| `name_suffix` | `string` | `""` | Suffix to apply to resource names |
| `user_attributes` | `list(string)` | `["email"]` | The pool's username attributes |
| `resources` | `list(object)` | required | Resource servers (below) |
| `clients` | `list(object)` | `[]` | App clients (below) |
| `identity_providers` | `map(object)` | `{}` | OpenID Connect providers, keyed by provider name (below). Sensitive |
| `security` | `object` | `{}` | Pool security settings (below) |
| `email` | `object({ source_arn, from, reply_to })` | `null` | SES sending settings. `null` uses Cognito's own email sending |
| `auth_domain` | `string` | `null` | The pool's domain: a custom domain with `certificate_arn`, otherwise a Cognito prefix |
| `certificate_arn` | `string` | `null` | `us-east-1` certificate for a custom `auth_domain` |
| `domain_zone_id` | `string` | `null` | Route 53 zone for the custom domain's alias record. `null` creates no record |
| `auth_logo` | `string` | `null` | Filename of logo to use on hosted UI (requires custom domain) |
| `auth_css` | `string` | `null` | CSS to use on hosted UI (requires custom domain) |
| `auto_confirm` | `bool` | `false` | Adds a pre sign-up Lambda that confirms users and verifies their email and phone |

### `resources`

| Field | Type | Description |
|---|---|---|
| `id` | `string` | The resource server's identifier |
| `name` | `string` | Its name, prefixed with the pool's name |
| `scopes` | `list(string)` | The resource's scopes. Clients get them through their own `scopes` |
| `allowed_clients` | `list(string)` | Used only without `scopes`: a scope is created for each client named, named after it, and that client gets `<id>/<client name>` |

### `clients`

| Field | Type | Default | Description |
|---|---|---|---|
| `name` | `string` | required | Client name, also the key of the `clients` and `client_secrets` outputs |
| `flows` | `list(string)` | `["code"]` | `["code"]` for an application, or `["client_credentials"]` for a service |
| `identity_providers` | `list(string)` | `["COGNITO"]` | Providers the client offers: `COGNITO` and/or keys of `identity_providers` |
| `scopes` | `list(string)` | `[]` | Resource scopes, as `<resource id>/<scope>` |
| `domain` | `string` | `null` | The application's domain. Required for `code` |
| `login_path` | `string` | `null` | Callback path. Required for `code` |
| `logout_path` | `string` | `null` | Sign-out path. No logout URLs when `null` |
| `local_port` | `number` | `null` | Also allows `http://localhost:<port>` callback and logout URLs |
| `identity_pool` | `object({ unauthenticated_policy, authenticated_policy })` | `null` | Creates an identity pool for the client |

A `code` client has callback and logout URLs on `https://<domain>`, the
scopes `email openid profile` plus its `scopes`, and no secret. A
`client_credentials` client has a secret, only its `scopes`, and no URLs.
A client offering an identity provider can read and write the pool
attributes that provider maps.

### `identity_providers`

| Field | Type | Default | Description |
|---|---|---|---|
| `issuer` | `string` | required | The provider's OpenID Connect issuer URL |
| `client_id` | `string` | required | Client id of the pool's registration with the provider |
| `secret` | `string` | required | Its client secret. Stored in the Terraform state |
| `scopes` | `string` | `"openid email profile"` | Scopes requested from the provider, space separated |
| `attributes` | `map(string)` | required | Pool attribute to provider claim, for example `{ email = "email", username = "sub" }` |

### `security`

| Field | Type | Default | Description |
|---|---|---|---|
| `allow_sign_up` | `bool` | `true` | `false` allows only administrators, and federated sign-in, to create users |
| `password_min_length` | `number` | `6` | Minimum password length |
| `password_complexity` | `bool` | `false` | Requires lower and upper case letters, numbers and symbols |
| `mfa` | `string` | `"OFF"` | `OFF`, `ON` or `OPTIONAL`. Software tokens are enabled unless `OFF` |
| `access_token_minutes` | `number` | `60` | Access and ID token lifetime, in minutes |
| `refresh_token_days` | `number` | `365` | Refresh token lifetime, in days |
| `deletion_protection` | `bool` | `false` | Turns on the pool's deletion protection |

## Outputs

| Name | Description |
|---|---|
| `pool_arn` | The pool's ARN |
| `pool_id` | The pool's id |
| `endpoint` | The pool's endpoint, without a scheme |
| `issuer` | The pool's token issuer, `https://<endpoint>` |
| `domain` | The pool's domain, when `auth_domain` is set |
| `domain_cloudfront_target` | CNAME target for a custom domain, when `certificate_arn` is set |
| `clients` | By client name: `id` and `identity_pool_id` |
| `client_secrets` | By client name, for `client_credentials` clients: the client secret. Sensitive |

## Notes

- Cognito won't create a custom domain unless its parent domain has an A
  record.
- The hosted UI styling is created only with a custom domain and
  `auth_logo` or `auth_css`.
