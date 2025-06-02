resource "aws_dynamodb_table" "this" {
  name           = var.table_name
  billing_mode   = var.billing_mode
  hash_key       = var.partition_key
  range_key      = var.sort_key

  attribute {
    name = var.partition_key
    type = "S"
  }

  attribute {
    name = var.sort_key
    type = "S"
  }

  # Definimos el GSI
  global_secondary_index {
    name            = var.gsi_name
    hash_key        = var.gsi_partition_key
    projection_type = "ALL"
  }

  #tags = var.tags

  # Meta-argumento opcional para proteger la tabla
  lifecycle {
    prevent_destroy = true
  }
}
