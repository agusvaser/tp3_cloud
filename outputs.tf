output "s3_website_url" {
  description = "URL del sitio web estático"
  value       = module.s3_frontend.website_endpoint
}

output "dynamodb_table_name" {
  description = "Nombre de la tabla DynamoDB"
  value       = module.dynamodb.table_name
}

output "api_gateway_invoke_url" {
  description = "Invoke URL de API Gateway"
  value       = aws_api_gateway_stage.recetify_stage.invoke_url
}
