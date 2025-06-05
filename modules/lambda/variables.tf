# Variable que contiene el ARN del role existente (Lab Role)
variable "lambda_role_arn" {
  description = "ARN del rol de ejecución Lambda (Lab Role)"
  type        = string
}

# Variable que define las Lambdas a crear
variable "lambdas" {
  description = "Mapa de Lambdas a crear, con su zip y variables de entorno"
  type = map(object({
    source_zip = string
    env_vars   = map(string)
  }))
}
