resource "aws_sqs_queue" "this" {
  name                        = var.name
  visibility_timeout_seconds  = var.visibility_timeout_seconds
  message_retention_seconds   = var.message_retention_seconds
  delay_seconds               = var.delay_seconds
  receive_wait_time_seconds   = var.receive_wait_time_seconds
}

resource "aws_sqs_queue_policy" "this" {
  count = var.attach_policy ? 1 : 0

  queue_url = aws_sqs_queue.this.id
  policy    = var.policy_json
}
