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
    "recetas.png"     = "recetas/png"
    "favoritos.html"  = "text/html"
    "config.js"     = "application/javascript"
  }
}

# Nombre generado del bucket S3 de imagenes
locals {
  generated_bucket_name_2 = "imagenes-recetas-${random_id.bucket_suffix.hex}"
}

# Módulo para el bucket S3 de imágenes
module "imagenes_bucket" {
  source      = "./modules/s3_bucket"
  bucket_name = local.generated_bucket_name_2
  acl         = "public-read"

  files = {}  
  content_types = {
    "jpg"  = "image/jpeg"
    "jpeg" = "image/jpeg"
    "png"  = "image/png"
    "gif"  = "image/gif"
    "webp" = "image/webp"
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
    "guardarReceta" = {
      source_zip = "lambdas/guardarReceta/lambda_function.zip"      
      env_vars   = {
        BUCKET_IMAGENES = module.imagenes_bucket.bucket_name
      }
    },
    "busquedaRecetas" = {
      source_zip = "lambdas/busquedaReceta/lambda_function.zip"
      env_vars   = {}
    },
    "obtenerReceta" = {
      source_zip = "lambdas/obtenerReceta/lambda_function.zip"
      env_vars   = {}
    },
    "obtenerRecetasUsuario" = {
      source_zip = "lambdas/obtenerRecetasUsuario/lambda_function.zip"
      env_vars = {}
    },
    "inicioSesionCognito" = {
      source_zip = "lambdas/inicioSesionCognito/lambda_function.zip"
      env_vars   = {
        COGNITO_CLIENT_ID = module.cognito.client_id
      }
    },
    "registroCognito" = {
      source_zip = "lambdas/registroCognito/lambda_function.zip"
      env_vars   = {
        COGNITO_CLIENT_ID = module.cognito.client_id
      }
    },
    "confirmarUsuarioCognito" = {
      source_zip = "lambdas/confirmarUsuarioCognito/lambda_function.zip"
      env_vars   = {
        COGNITO_CLIENT_ID = module.cognito.client_id
      }
    },
    # Favorite Lambdas
    "addFavorite" = {
      source_zip = "lambdas/addFavorite/lambda_function.zip"
      env_vars   = { 
        DYNAMODB_TABLE = "TablaRecetas"
      }
    },
    "removeFavorite" = {
      source_zip = "lambdas/removeFavorite/lambda_function.zip"
      env_vars   = { 
        DYNAMODB_TABLE = "TablaRecetas"
      }
    },
    "getFavorites" = {
      source_zip = "lambdas/getFavorites/lambda_function.zip"
      env_vars   = { 
        DYNAMODB_TABLE    = "TablaRecetas",
        DYNAMODB_GSI_NAME = "GSI-RECETA"
      }
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
    # Favorite Lambda ARNs for API Gateway
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

