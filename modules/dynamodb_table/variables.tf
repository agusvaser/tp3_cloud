variable "table_name" {
  description = "Nombre de la tabla DynamoDB"
  type        = string
}

variable "billing_mode" {
  description = "Modo de facturación"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "partition_key" {
  description = "Partition key de la tabla"
  type        = string
}

variable "sort_key" {
  description = "Sort key de la tabla"
  type        = string
}

variable "gsi_name" {
  description = "Nombre del GSI"
  type        = string
}

variable "gsi_partition_key" {
  description = "Partition key del GSI"
  type        = string
}

#variable "tags" {
#  description = "Tags para la tabla"
#  type        = map(string)
#  default     = {}
#}
