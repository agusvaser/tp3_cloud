variable "name" {
  description = "Name of the SQS queue"
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout in seconds"
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "Message retention period in seconds"
  type        = number
  default     = 345600  # 4 días
}

variable "delay_seconds" {
  description = "Delay for message delivery in seconds"
  type        = number
  default     = 0
}

variable "receive_wait_time_seconds" {
  description = "Long polling wait time"
  type        = number
  default     = 0
}

variable "attach_policy" {
  description = "Whether to attach a policy"
  type        = bool
  default     = false
}

variable "policy_json" {
  description = "JSON-formatted SQS policy to attach"
  type        = string
  default     = ""
}
