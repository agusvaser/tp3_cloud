resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  
}

# Configuración de static website hosting
resource "aws_s3_bucket_website_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  index_document {
    suffix = var.index_document
  }

  error_document {
    key = var.error_document
  }
}

# Sube los archivos del front-end (index.html, etc.)
resource "aws_s3_object" "files" {
  for_each = var.files

  bucket = aws_s3_bucket.this.id
  key    = each.key
  source = each.value
# acl    = "public-read"  # Asegura que cada objeto sea público
  content_type = lookup(var.content_types, each.key, null)
}

resource "aws_s3_object" "config_js" {
  bucket       = aws_s3_bucket.this.id
  key          = "config.js"
  source       = "${path.module}/../../build/config.js"
  content_type = "application/javascript"
#  acl          = "public-read"
}

# Opcional: outputs para obtener el website endpoint
#output "website_endpoint" {
#  value = aws_s3_bucket_website_configuration.this.website_endpoint
#}

resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "public_read" {
  bucket = aws_s3_bucket.this.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = [
          "s3:GetObject"
        ]
        Resource  = [
          "arn:aws:s3:::${aws_s3_bucket.this.id}/*"
        ]
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.this]
}
