# Configuración del proveedor AWS (puede estar en versions.tf o aquí)
provider "aws" {
  region = "us-east-1"
}

# Genera un sufijo aleatorio hexadecimal (4 caracteres)
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Nombre generado del bucket S3
locals {
  generated_bucket_name = "bucket-recetify-${random_id.bucket_suffix.hex}"
}

# Módulo para el bucket S3 (ya creado previamente)
module "frontend_bucket" {
  source      = "./modules/s3_bucket"
  bucket_name = local.generated_bucket_name
  acl         = "public-read"
  files = {
    "index.html"    = "${path.module}/frontend/index.html"
    "home.html"     = "${path.module}/frontend/home.html"
    "receta.html"   = "${path.module}/frontend/receta.html"
    "registro.html" = "${path.module}/frontend/registro.html"
    "recetas.png"     = "${path.module}/frontend/recetas.png"
    "config.js"     = "${path.module}/build/config.js"
  }
  content_types = {
    "index.html"    = "text/html"
    "home.html"     = "text/html"
    "receta.html"   = "text/html"
    "registro.html" = "text/html"
    "recetas.png"     = "recetas/png"
    "config.js"     = "application/javascript"
  }
}


# Módulo para la tabla DynamoDB (creado previamente)
module "dynamodb_recetas" {
  source            = "./modules/dynamodb_table"
  table_name        = "TablaRecetas"
  partition_key     = "USER"
  sort_key          = "RECETA"
  gsi_name          = "GSI-RECETA"
  gsi_partition_key = "RECETA"
  #tags = {
   # Environment = "dev"
   # Owner       = "recetify-team"
  #}
}

data "aws_caller_identity" "current" {}

# Módulo para las Lambdas
module "lambdas" {
  source = "./modules/lambda"

  # ARN real del LabRole
  
  
lambda_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
  lambdas = {
    "registroUsuario" = {
      source_zip = "lambdas/registroUsuario/lambda_function.zip"
      env_vars   = {}
    },
    "guardarReceta" = {
      source_zip = "lambdas/guardarReceta/lambda_function.zip"
      env_vars   = {}
    },
    "busquedaRecetas" = {
      source_zip = "lambdas/busquedaReceta/lambda_function.zip"
      env_vars   = {}
    },
    "obtenerReceta" = {
      source_zip = "lambdas/obtenerReceta/lambda_function.zip"
      env_vars   = {}
    }
  }
}

module "api_gateway" {
  source      = "./modules/api_gateway"
  api_name    = "recetify_api"
  stage_name  = "dev"
  region      = "us-east-1"

  lambda_arns = {
    guardarReceta    = module.lambdas.lambda_arns["guardarReceta"]
    obtenerReceta    = module.lambdas.lambda_arns["obtenerReceta"]
    busquedaRecetas  = module.lambdas.lambda_arns["busquedaRecetas"]
    registroUsuario  = module.lambdas.lambda_arns["registroUsuario"]
  }
}

output "api_invoke_url" {
  # Cambiar a API HTTP invoke_url
  value = module.api_gateway.invoke_url
}

resource "local_file" "api_config" {
  content = <<-EOT
    const apiConfig = {
      apiBaseUrl: "${module.api_gateway.invoke_url}"
    };
  EOT
  filename = "${path.module}/build/config.js"
}