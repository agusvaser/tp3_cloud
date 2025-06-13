# Variable que contiene el ARN del role existente (Lab Role)
variable "lambda_role_arn" {
  description = "ARN del rol de ejecución Lambda (Lab Role)"
  type        = string
}

# Variable que define las Lambdas a crear
variable "lambdas" {
  description = "Mapa de Lambdas a crear, con su zip, variables de entorno y configuración VPC"
  type = map(object({
    source_zip    = string
    env_vars      = map(string)
    use_vpc       = optional(bool, true)  # Por defecto usan VPC
  }))
}

# Variable para configuración VPC global (opcional)
variable "vpc_config" {
  description = "Configuración VPC para las funciones Lambda que la necesiten"
  type = object({
    subnet_ids         = list(string)
    security_group_ids = list(string)
  })
  default = null
}