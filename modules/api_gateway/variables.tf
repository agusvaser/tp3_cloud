variable "api_name" {
  description = "Nombre del API Gateway"
  type        = string
}

variable "stage_name" {
  description = "Nombre del stage (por ejemplo dev)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "lambda_arns" {
  description = "Mapa con los ARNs de las funciones Lambda para las integraciones"
  type        = map(string)
}

