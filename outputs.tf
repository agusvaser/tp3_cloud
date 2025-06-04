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

output "imagenes_bucket_id" {
  value = module.imagenes_bucket.bucket_id
}

output "bucket_name_imagenes" {
  value = module.imagenes_bucket.bucket_name
}