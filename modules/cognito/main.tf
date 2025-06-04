# Crea el User Pool (base de datos de usuarios)
resource "aws_cognito_user_pool" "this" {
  name = var.user_pool_name

  auto_verified_attributes = ["email"]  # Cognito verificará los emails automáticamente

  password_policy {
    minimum_length    = 6
    require_lowercase = false
    require_uppercase = false
    require_numbers   = false
    require_symbols   = false
  }

  account_recovery_setting {
    recovery_mechanism {
      name     = "verified_email"
      priority = 1
    }
  }

  admin_create_user_config {
    allow_admin_create_user_only = false
  }

  schema {
    attribute_data_type      = "String"
    name                     = "email"
    required                 = true
    mutable                  = true
    developer_only_attribute = false
  }

  tags = {
    Name = var.user_pool_name
  }
}

# App Client (sin client secret porque no usás OAuth ni Hosted UI)
resource "aws_cognito_user_pool_client" "this" {
  name         = "${var.user_pool_name}-client"
  user_pool_id = aws_cognito_user_pool.this.id

  generate_secret       = false  # importante: sin client secret
  explicit_auth_flows   = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH", "ALLOW_ADMIN_USER_PASSWORD_AUTH"]

  prevent_user_existence_errors = "ENABLED"

  depends_on = [aws_cognito_user_pool.this]
}
