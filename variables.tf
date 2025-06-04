variable "aws_region" {
  description = "AWS region"
  default     = "us-east-1"
}

variable "bucket_name" {
  description = "Nombre del bucket S3"
  default     = "s3recetify0106"
}

variable "table_name" {
  description = "Nombre de la tabla DynamoDB"
  default     = "TablaRecetas"
}

variable "lambda_role" {
  description = "Nombre del rol de ejecución para las Lambdas"
  default     = "LabRole"
}

variable "lambda_functions" {
  description = "Nombres y rutas de los archivos zip de las Lambdas"
  type        = map(string)
  default = {
    registroUsuario  = "registroUsuario.zip"
    guardarReceta    = "guardarReceta.zip"
    busquedaRecetas  = "busquedaRecetas.zip"
    obtenerReceta    = "obtenerReceta.zip"
  }
}
