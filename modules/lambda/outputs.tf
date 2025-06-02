# Output para devolver los ARN de las Lambdas creadas
output "lambda_arns" {
  value = { for k, v in aws_lambda_function.this : k => v.arn }
}
