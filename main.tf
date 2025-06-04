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
  lambdas = {
    "guardarReceta" = {
      source_zip = "lambdas/guardarReceta/lambda_function.zip"
      env_vars   = {
        BUCKET_IMAGENES = module.user_photos_bucket.s3_bucket_id
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
    "logoutCognito" = {
      source_zip = "lambdas/logoutCognito/lambda_function.zip"
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

# Crear recetas destacadas como recursos de Terraform
resource "aws_dynamodb_table_item" "pizza_casera" {
  depends_on = [module.dynamodb_recetas]
  table_name = "TablaRecetas"
  hash_key   = "USER"
  range_key  = "RECETA"

  item = jsonencode({
    USER = {
      S = "admin@recetascasa.com"
    }
    RECETA = {
      S = "1"
    }
    nombre = {
      S = "Pizza Casera"
    }
    categoria = {
      S = "cena"
    }
    tiempo = {
      N = "45"
    }
    ingredientes = {
      S = "Harina, levadura, sal, aceite de oliva, agua tibia, salsa de tomate, queso mozzarella, orégano"
    }
    instrucciones = {
      S = "Mezclar harina, levadura y sal. Agregar aceite y agua tibia, amasar hasta obtener masa suave. Dejar reposar 1 hora. Extender la masa, agregar salsa de tomate, queso mozzarella y orégano. Hornear a 220°C por 15-20 minutos hasta que esté dorada."
    }
    fecha_creacion = {
      S = formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timestamp())
    }
  })
}

resource "aws_dynamodb_table_item" "galletas_avena" {
  depends_on = [module.dynamodb_recetas]
  table_name = "TablaRecetas"
  hash_key   = "USER"
  range_key  = "RECETA"

  item = jsonencode({
    USER = {
      S = "admin@recetascasa.com"
    }
    RECETA = {
      S = "2"
    }
    nombre = {
      S = "Galletitas de Avena"
    }
    categoria = {
      S = "desayuno"
    }
    tiempo = {
      N = "30"
    }
    ingredientes = {
      S = "Avena, harina integral, miel, aceite de coco, huevo, canela, pasas de uva"
    }
    instrucciones = {
      S = "Mezclar avena, harina y canela en un bowl. En otro bowl, batir huevo con miel y aceite de coco derretido. Combinar ambas mezclas, agregar pasas. Formar bolitas y aplastar en bandeja con papel manteca. Hornear a 180°C por 12-15 minutos."
    }
    fecha_creacion = {
      S = formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timestamp())
    }
  })
}

resource "aws_dynamodb_table_item" "ensalada_quinoa" {
  depends_on = [module.dynamodb_recetas]
  table_name = "TablaRecetas"
  hash_key   = "USER"
  range_key  = "RECETA"

  item = jsonencode({
    USER = {
      S = "admin@recetascasa.com"
    }
    RECETA = {
      S = "3"
    }
    nombre = {
      S = "Ensalada de Quinoa"
    }
    categoria = {
      S = "saludable"
    }
    tiempo = {
      N = "20"
    }
    ingredientes = {
      S = "Quinoa, palta, tomates cherry, pepino, cebolla morada, limón, aceite de oliva, sal, pimienta, cilantro"
    }
    instrucciones = {
      S = "Cocinar quinoa en agua con sal hasta que esté tierna (15 min). Dejar enfriar. Cortar palta, tomates, pepino y cebolla en cubos pequeños. Mezclar quinoa fría con vegetales. Aliñar con limón, aceite de oliva, sal y pimienta. Decorar con cilantro fresco."
    }
    fecha_creacion = {
      S = formatdate("YYYY-MM-DD'T'hh:mm:ssZ", timestamp())
    }
  })
}

module "api_gateway" {
  source      = "./modules/api_gateway"
  api_name    = "recetify_api"
  stage_name  = "dev"
  region      = "us-east-1"

  lambda_arns = {
    guardarReceta    = module.lambdas.lambda_arns["guardarReceta"]
    obtenerReceta    = module.lambdas.lambda_arns["obtenerReceta"]
    busquedaRecetas  = module.lambdas.lambda_arns["busquedaRecetas"]  // ✅ Fixed typo
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