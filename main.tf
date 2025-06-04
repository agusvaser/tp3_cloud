module "s3_frontend" {
  source      = "./modules/s3_frontend"
  bucket_name = var.bucket_name
}

module "dynamodb" {
  source     = "./modules/dynamodb"
  table_name = var.table_name
}

resource "aws_lambda_function" "lambdas" {
  for_each = var.lambda_functions

  function_name = each.key
  role          = aws_iam_role.lab_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  filename      = "${path.module}/${each.value}"
  source_code_hash = filebase64sha256("${path.module}/${each.value}")
  
  environment {
    variables = {
      TABLE_NAME = module.dynamodb.table_name
    }
  }

  depends_on = [module.dynamodb]
}

data "aws_iam_role" "lab_role" {
  name = var.lambda_role
}

resource "aws_api_gateway_rest_api" "recetify_api" {
  name        = "recetify_api"
  description = "API Gateway para Recetify"
}

resource "aws_api_gateway_resource" "recursos" {
  for_each = toset(["registro", "guardar_receta", "recetas"])

  rest_api_id = aws_api_gateway_rest_api.recetify_api.id
  parent_id   = aws_api_gateway_rest_api.recetify_api.root_resource_id
  path_part   = each.key
}

resource "aws_api_gateway_method" "methods" {
  for_each = {
    "POST/registro"           = "POST"
    "POST/guardar_receta"     = "POST"
    "GET/recetas/busqueda"    = "GET"
    "GET/recetas/{id}"        = "GET"
  }

  rest_api_id   = aws_api_gateway_rest_api.recetify_api.id
  resource_id   = lookup(aws_api_gateway_resource.recursos, split("/", each.key)[1]).id
  http_method   = each.value
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "integraciones" {
  for_each = aws_lambda_function.lambdas

  rest_api_id = aws_api_gateway_rest_api.recetify_api.id
  resource_id = lookup(aws_api_gateway_resource.recursos, split("_", each.key)[0]).id
  http_method = aws_api_gateway_method.methods["${split("_", each.key)[0]}/${aws_api_gateway_method.methods.*.http_method[0]}"].http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.lambdas[each.key].invoke_arn
}

resource "aws_api_gateway_stage" "recetify_stage" {
  stage_name    = "stage_api_recetas"
  rest_api_id   = aws_api_gateway_rest_api.recetify_api.id
  deployment_id = aws_api_gateway_deployment.recetify_deployment.id

  variables = {
    lambda_env = "prod"
  }
}

resource "aws_api_gateway_deployment" "recetify_deployment" {
  depends_on = [aws_api_gateway_integration.integraciones]
  rest_api_id = aws_api_gateway_rest_api.recetify_api.id
}

