#########################################
# Define la API HTTP principal
#########################################
resource "aws_apigatewayv2_api" "this" {
  name          = var.api_name
  protocol_type = "HTTP"
  description   = "API Gateway HTTP para Recetify"
  
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_headers = ["content-type"]
  }
}

#########################################
# Integraciones y Rutas para cada Lambda
#########################################

# ---- Guardar Receta (POST) ----
resource "aws_apigatewayv2_integration" "guardar_receta_post" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_arns["guardarReceta"]}/invocations"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "guardar_receta_post" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /guardar_receta"
  target    = "integrations/${aws_apigatewayv2_integration.guardar_receta_post.id}"
}

resource "aws_lambda_permission" "permitir_guardar_receta" {
  statement_id  = "AllowExecutionFromAPIGateway_GuardarReceta"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arns["guardarReceta"]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

# ---- Obtener Receta (GET) ----
resource "aws_apigatewayv2_integration" "recetas_get" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_arns["obtenerReceta"]}/invocations"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "recetas_get" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /recetas/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.recetas_get.id}"
}

resource "aws_lambda_permission" "permitir_obtener_receta" {
  statement_id  = "AllowExecutionFromAPIGateway_ObtenerReceta"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arns["obtenerReceta"]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

# ---- Búsqueda Recetas (GET) ----
resource "aws_apigatewayv2_integration" "busqueda_get" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_arns["busquedaRecetas"]}/invocations"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "busqueda_get" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /busqueda"
  target    = "integrations/${aws_apigatewayv2_integration.busqueda_get.id}"
}

resource "aws_lambda_permission" "permitir_busqueda_recetas" {
  statement_id  = "AllowExecutionFromAPIGateway_BusquedaRecetas"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arns["busquedaRecetas"]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

# ---- Registro Usuario Cognito (POST) ----
resource "aws_apigatewayv2_integration" "registro_cognito" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_arns["registroCognito"]}/invocations"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "registro_cognito" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /registro"
  target    = "integrations/${aws_apigatewayv2_integration.registro_cognito.id}"
}

resource "aws_lambda_permission" "permitir_registro_cognito" {
  statement_id  = "AllowExecutionFromAPIGateway_RegistroCognito"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arns["registroCognito"]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

# ---- Inicio Sesión Usuario Cognito (POST) ----
resource "aws_apigatewayv2_integration" "login_cognito" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_arns["inicioSesionCognito"]}/invocations"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "login_cognito" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /login"
  target    = "integrations/${aws_apigatewayv2_integration.login_cognito.id}"
}

resource "aws_lambda_permission" "permitir_login_cognito" {
  statement_id  = "AllowExecutionFromAPIGateway_LoginCognito"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arns["inicioSesionCognito"]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

# ---- Confirmar Usuario (POST) ----
resource "aws_apigatewayv2_integration" "confirmar_usuario" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = "arn:aws:apigateway:${var.region}:lambda:path/2015-03-31/functions/${var.lambda_arns["confirmarUsuarioCognito"]}/invocations"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "confirmar_usuario" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /confirmar"
  target    = "integrations/${aws_apigatewayv2_integration.confirmar_usuario.id}"
}

resource "aws_lambda_permission" "permitir_confirmar_usuario" {
  statement_id  = "AllowExecutionFromAPIGateway_ConfirmarUsuario"
  action        = "lambda:InvokeFunction"
  function_name = var.lambda_arns["confirmarUsuarioCognito"]
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}


#########################################
# Stage de despliegue (auto deploy)
#########################################
resource "aws_apigatewayv2_stage" "this" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = var.stage_name    # e.g. "dev"
  auto_deploy = true
}

