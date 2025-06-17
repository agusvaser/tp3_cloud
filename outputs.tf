output "frontend_bucket_id" {
  value = module.frontend_bucket.bucket_id
}

output "frontend_bucket_arn" {
  value = module.frontend_bucket.bucket_arn
}

output "dynamodb_table_id" {
  value = module.dynamodb_recetas.table_id
}

output "dynamodb_table_arn" {
  value = module.dynamodb_recetas.table_arn
}

output "lambda_arns" {
  value = module.lambdas.lambda_arns
}

output "queue_url" {
  value = module.sqs_favoritos.queue_url   # id = QueueURL
}
