variable "bucket_name" {
  description = "Nombre del bucket S3"
  type        = string
  default     = "bucket-recetify-tp3"
}

variable "acl" {
  description = "ACL del bucket y objetos"
  type        = string
  default     = "public-read"  # Por defecto ACL pública
}

variable "tags" {
  description = "Tags del bucket"
  type        = map(string)
  default     = {}
}

variable "files" {
  description = "Mapeo de archivos a subir"
  type        = map(string)
}

variable "content_types" {
  description = "Mapeo de content-types por archivo"
  type        = map(string)
  default = {
    "index.html"    = "text/html"
    "home.html"     = "text/html"
    "receta.html"   = "text/html"
    "registro.html" = "text/html"
    "image.jpg"     = "image/jpeg"
    "error.html"    = "text/html"  # Agregamos un archivo de error por si falla
    "config.js" = "application/javascript"
  }
}

variable "index_document" {
  description = "Documento inicial del sitio estático"
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "Documento de error del sitio estático"
  type        = string
  default     = "error.html"
}
