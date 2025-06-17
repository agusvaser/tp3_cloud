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

data "aws_caller_identity" "current" {}

# Módulo VPC
module "vpc" {
  source             = "./modules/vpc"
  name_prefix        = "recetify"
  vpc_cidr           = "10.0.0.0/16"
  private_subnets    = ["10.0.1.0/24", "10.0.2.0/24"]
  availability_zones = ["us-east-1a", "us-east-1b"]
  region             = "us-east-1"
}

# Módulo para la cola SQS y política de permisos para publicación
module "sqs_favoritos" {
  source = "./modules/sqs"

  name                       = "SNSQueues"
  visibility_timeout_seconds = 30
  message_retention_seconds  = 345600
  delay_seconds              = 0
  receive_wait_time_seconds  = 0

  attach_policy = true
  policy_json = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid    = "AllowAddFavoriteLambdaToSend"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"
        }
        Action   = "sqs:SendMessage"
        Resource = "arn:aws:sqs:${"us-east-1"}:${data.aws_caller_identity.current.account_id}:SNSQueues"
      }
    ]
  })
}

# Módulo para el bucket S3 (ya creado previamente)
module "frontend_bucket" {
  source      = "./modules/s3_bucket"
  bucket_name = local.generated_bucket_name
  acl         = "public-read"
  files = {
    "index.html"      = "${path.module}/frontend/index.html"
    "home.html"       = "${path.module}/frontend/home.html"
    "receta.html"     = "${path.module}/frontend/receta.html"
    "registro.html"   = "${path.module}/frontend/registro.html"
    "recetas.png"     = "${path.module}/frontend/recetas.png"
    "misRecetas.html" = "${path.module}/frontend/misRecetas.html"
    "favoritos.html"  = "${path.module}/frontend/favoritos.html"
    "config.js"       = "${path.module}/build/config.js"
  }
  content_types = {
    "index.html"      = "text/html"
    "home.html"       = "text/html"
    "receta.html"     = "text/html"
    "registro.html"   = "text/html"
    "misRecetas.html" = "text/html"
    "favoritos.html"  = "text/html"
    "recetas.png"     = "image/png"
    "config.js"       = "application/javascript"
  }
}

# Crea el bucket S3 para imágenes de usuario
module "user_photos_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 4.10.0"

  bucket = "rectefify-fotos-usuarios-${random_id.bucket_suffix.hex}"
  acl    = "public-read"

  control_object_ownership = true
  object_ownership         = "BucketOwnerPreferred"

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  attach_policy = true
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadWrite",
        Effect    = "Allow",
        Principal = "*",
        Action    = ["s3:GetObject", "s3:PutObject"],
        Resource  = ["arn:aws:s3:::rectefify-fotos-usuarios-${random_id.bucket_suffix.hex}/*"]
      }
    ]
  })

  force_destroy = true
}

# Módulo para la tabla DynamoDB (creado previamente)
module "dynamodb_recetas" {
  source            = "./modules/dynamodb_table"
  table_name        = "TablaRecetas"
  partition_key     = "USER"
  sort_key          = "RECETA"
  gsi_name          = "GSI-RECETA"
  gsi_partition_key = "RECETA"
}

# Módulo para las Lambdas
module "lambdas" {
  source = "./modules/lambda"

  lambda_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/LabRole"

  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.lambda_security_group_id]
  }

  lambdas = {
    "guardarReceta" = {
      source_zip = "lambdas/guardarReceta/lambda_function.zip"
      env_vars   = { BUCKET_IMAGENES = module.user_photos_bucket.s3_bucket_id }
      use_vpc    = true
    },
    "busquedaRecetas" = {
      source_zip = "lambdas/busquedaReceta/lambda_function.zip"
      env_vars   = {}
      use_vpc    = true
    },
    "obtenerReceta" = {
      source_zip = "lambdas/obtenerReceta/lambda_function.zip"
      env_vars   = {}
      use_vpc    = true
    },
    "obtenerRecetasUsuario" = {
      source_zip = "lambdas/obtenerRecetasUsuario/lambda_function.zip"
      env_vars   = {}
      use_vpc    = true
    },
    # Lambdas de Cognito - SIN VPC
    "inicioSesionCognito" = {
      source_zip = "lambdas/inicioSesionCognito/lambda_function.zip"
      env_vars   = { COGNITO_CLIENT_ID = module.cognito.client_id }
      use_vpc    = false
    },
    "registroCognito" = {
      source_zip = "lambdas/registroCognito/lambda_function.zip"
      env_vars   = { COGNITO_CLIENT_ID = module.cognito.client_id }
      use_vpc    = false
    },
    "confirmarUsuarioCognito" = {
      source_zip = "lambdas/confirmarUsuarioCognito/lambda_function.zip"
      env_vars   = { COGNITO_CLIENT_ID = module.cognito.client_id }
      use_vpc    = false
    },
    "logoutCognito" = {
      source_zip = "lambdas/logoutCognito/lambda_function.zip"
      env_vars   = { COGNITO_CLIENT_ID = module.cognito.client_id }
      use_vpc    = false
    },
    # Favorite Lambdas - CON VPC
    "addFavorite" = {
      source_zip = "lambdas/addFavorite/lambda_function.zip"
      env_vars = {
        DYNAMODB_TABLE = "TablaRecetas",
        SQS_URL        = module.sqs_favoritos.queue_url
      }
      use_vpc = true
    },
    "removeFavorite" = {
      source_zip = "lambdas/removeFavorite/lambda_function.zip"
      env_vars   = { DYNAMODB_TABLE = "TablaRecetas" }
      use_vpc    = true
    },
    "getFavorites" = {
      source_zip = "lambdas/getFavorites/lambda_function.zip"
      env_vars = {
        DYNAMODB_TABLE    = "TablaRecetas",
        DYNAMODB_GSI_NAME = "GSI-RECETA"
      }
      use_vpc = true
    },
    "publicarSNS" = {
      source_zip = "lambdas/snsPublisher/lambda_function.zip"
      env_vars   = { SQS_URL = module.sqs_favoritos.queue_url }
      use_vpc    = false
    }
  }
}

# Módulo para API Gateway que expone las Lambdas
module "api_gateway" {
  source     = "./modules/api_gateway"
  api_name   = "recetify_api"
  stage_name = "dev"
  region     = "us-east-1"

  lambda_arns = {
    guardarReceta           = module.lambdas.lambda_arns["guardarReceta"]
    obtenerReceta           = module.lambdas.lambda_arns["obtenerReceta"]
    busquedaRecetas         = module.lambdas.lambda_arns["busquedaRecetas"]
    obtenerRecetasUsuario   = module.lambdas.lambda_arns["obtenerRecetasUsuario"]
    registroCognito         = module.lambdas.lambda_arns["registroCognito"]
    inicioSesionCognito     = module.lambdas.lambda_arns["inicioSesionCognito"]
    confirmarUsuarioCognito = module.lambdas.lambda_arns["confirmarUsuarioCognito"]
    logoutCognito           = module.lambdas.lambda_arns["logoutCognito"]
    addFavorite             = module.lambdas.lambda_arns["addFavorite"]
    removeFavorite          = module.lambdas.lambda_arns["removeFavorite"]
    getFavorites            = module.lambdas.lambda_arns["getFavorites"]
  }
}

# Enlace entre SQS y Lambda publicarSNS
resource "aws_lambda_event_source_mapping" "sns_queue_to_lambda" {
  event_source_arn = module.sqs_favoritos.queue_arn
  function_name    = module.lambdas.lambda_arns["publicarSNS"]
  batch_size       = 1
  enabled          = true
}

# Módulo para Cognito
module "cognito" {
  source         = "./modules/cognito"
  user_pool_name = "recetas-user-pool"
}

output "api_invoke_url" {
  value = module.api_gateway.invoke_url
}

# Generación del archivo config.js con la URL de la API
resource "local_file" "api_config" {
  content = <<-EOT
    const apiConfig = {
      apiBaseUrl: "${module.api_gateway.invoke_url}"
    };
  EOT
  filename = "${path.module}/build/config.js"
}
