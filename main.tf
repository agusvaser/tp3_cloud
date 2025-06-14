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

# Módulo VPC
module "vpc" {
  source = "./modules/vpc"
  
  name_prefix        = "recetify"
  vpc_cidr          = "10.0.0.0/16"
  private_subnets   = ["10.0.1.0/24", "10.0.2.0/24"]
  availability_zones = ["us-east-1a", "us-east-1b"]
  region            = "us-east-1"
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
    "misRecetas.html"= "${path.module}/frontend/misRecetas.html"
    "favoritos.html"  = "${path.module}/frontend/favoritos.html"
    "config.js"     = "${path.module}/build/config.js"
  }
  content_types = {
    "index.html"    = "text/html"
    "home.html"     = "text/html"
    "receta.html"   = "text/html"
    "misRecetas.html" = "text/html"
    "registro.html" = "text/html"
    "recetas.png"     = "recetas/png"
    "favoritos.html"  = "text/html"
    "config.js"     = "application/javascript"
  }
}


# Crea el bucket S3
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
        Action    = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = [
          "arn:aws:s3:::rectefify-fotos-usuarios-${random_id.bucket_suffix.hex}/*"
        ]
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
  
  # Configuración VPC para las Lambdas que la necesiten
  vpc_config = {
    subnet_ids         = module.vpc.private_subnet_ids
    security_group_ids = [module.vpc.lambda_security_group_id]
  }
  
  lambdas = {
    "guardarReceta" = {
      source_zip = "lambdas/guardarReceta/lambda_function.zip"
      env_vars   = {
        BUCKET_IMAGENES = module.user_photos_bucket.s3_bucket_id
      }
      use_vpc = true  # Necesita VPC para acceder a DynamoDB
    },
    "busquedaRecetas" = {
      source_zip = "lambdas/busquedaReceta/lambda_function.zip"
      env_vars   = {}
      use_vpc = true  # Necesita VPC para acceder a DynamoDB
    },
    "obtenerReceta" = {
      source_zip = "lambdas/obtenerReceta/lambda_function.zip"
      env_vars   = {}
      use_vpc = true  # Necesita VPC para acceder a DynamoDB
    },
    "obtenerRecetasUsuario" = {
      source_zip = "lambdas/obtenerRecetasUsuario/lambda_function.zip"
      env_vars = {}
      use_vpc = true  # Necesita VPC para acceder a DynamoDB
    },
    # Lambdas de Cognito - SIN VPC
    "inicioSesionCognito" = {
      source_zip = "lambdas/inicioSesionCognito/lambda_function.zip"
      env_vars   = {
        COGNITO_CLIENT_ID = module.cognito.client_id
      }
      use_vpc = false  # Cognito funciona mejor sin VPC
    },
    "registroCognito" = {
      source_zip = "lambdas/registroCognito/lambda_function.zip"
      env_vars   = {
        COGNITO_CLIENT_ID = module.cognito.client_id
      }
      use_vpc = false  # Cognito funciona mejor sin VPC
    },
    "confirmarUsuarioCognito" = {
      source_zip = "lambdas/confirmarUsuarioCognito/lambda_function.zip"
      env_vars   = {
        COGNITO_CLIENT_ID = module.cognito.client_id
      }
      use_vpc = false  # Cognito funciona mejor sin VPC
    },
    "logoutCognito" = {
      source_zip = "lambdas/logoutCognito/lambda_function.zip"
      env_vars   = {
        COGNITO_CLIENT_ID = module.cognito.client_id
      }
      use_vpc = false  # Cognito funciona mejor sin VPC
    },
    # Favorite Lambdas - CON VPC
    "addFavorite" = {
      source_zip = "lambdas/addFavorite/lambda_function.zip"
      env_vars   = { 
        DYNAMODB_TABLE = "TablaRecetas"
      }
      use_vpc = true  # Necesita VPC para acceder a DynamoDB
    },
    "removeFavorite" = {
      source_zip = "lambdas/removeFavorite/lambda_function.zip"
      env_vars   = { 
        DYNAMODB_TABLE = "TablaRecetas"
      }
      use_vpc = true  # Necesita VPC para acceder a DynamoDB
    },
    "getFavorites" = {
      source_zip = "lambdas/getFavorites/lambda_function.zip"
      env_vars   = { 
        DYNAMODB_TABLE    = "TablaRecetas",
        DYNAMODB_GSI_NAME = "GSI-RECETA"
      }
      use_vpc = true  # Necesita VPC para acceder a DynamoDB
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
    obtenerRecetasUsuario = module.lambdas.lambda_arns["obtenerRecetasUsuario"]
    registroCognito = module.lambdas.lambda_arns["registroCognito"]
    inicioSesionCognito = module.lambdas.lambda_arns["inicioSesionCognito"]
    confirmarUsuarioCognito = module.lambdas.lambda_arns["confirmarUsuarioCognito"]
    logoutCognito     = module.lambdas.lambda_arns["logoutCognito"]
    addFavorite      = module.lambdas.lambda_arns["addFavorite"]
    removeFavorite   = module.lambdas.lambda_arns["removeFavorite"]
    getFavorites     = module.lambdas.lambda_arns["getFavorites"]
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

module "cognito" {
  source          = "./modules/cognito"
  user_pool_name  = "recetas-user-pool"
}