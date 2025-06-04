resource "aws_s3_bucket" "frontend" {
  bucket = var.bucket_name

  website {
    index_document = "index.html"
    error_document = "error.html"
  }

  acl = "public-read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "PublicReadGetObject"
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "arn:aws:s3:::${var.bucket_name}/*"
    }]
  })

  lifecycle {
    prevent_destroy = true
  }
}

output "website_endpoint" {
  value = aws_s3_bucket.frontend.website_endpoint
}
