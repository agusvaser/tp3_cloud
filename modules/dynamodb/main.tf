resource "aws_dynamodb_table" "recetas" {
  name           = var.table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "USER"
  range_key      = "RECETA"

  attribute {
    name = "USER"
    type = "S"
  }

  attribute {
    name = "RECETA"
    type = "S"
  }

  global_secondary_index {
    name            = "GSI-RECETA"
    hash_key        = "RECETA"
    projection_type = "ALL"
  }

  lifecycle {
    ignore_changes = [global_secondary_index]
  }
}

output "table_name" {
  value = aws_dynamodb_table.recetas.name
}
