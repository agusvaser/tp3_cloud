variable "region" {
    type= string
    description= "AWS Region"
    default= "us-east-1"
}

variable "iam_role_name" {
  description = "Nombre del IAM Role existente"
  type        = string
}