# Recetify - Infraestructura Cloud

## Descripción General del Proyecto
Recetify es una aplicación serverless de gestión de recetas construida sobre infraestructura AWS usando Terraform. La aplicación permite a los usuarios gestionar recetas, subir fotos, marcar favoritos y realizar búsquedas de recetas a través de una interfaz web.


## Arquitectura y Componentes

### Infraestructura como Código (IaC)

#### 1. Módulo API Gateway (`modules/api_gateway`)
- Gestiona los endpoints HTTP API de la aplicación
- Maneja la integración de solicitudes/respuestas con funciones Lambda
- Implementa políticas CORS y autorización de API
- Configura etapas y despliegues de API


#### 2. Módulo Cognito (`modules/cognito`)
- Gestiona la autenticación y autorización de usuarios
- Implementa pools de usuarios y pools de identidad
- Maneja flujos de registro e inicio de sesión
- Configura políticas de contraseñas y atributos de usuario


#### 3. Módulo DynamoDB (`modules/dynamodb_table`)
- Gestiona tablas de base de datos NoSQL
- Implementa índices y atributos de tabla
- Maneja persistencia de datos para recetas y datos de usuario
- Soporta búsquedas eficientes mediante GSI (Global Secondary Index)


#### 4. Módulo Lambda (`modules/lambda`)
- Gestiona despliegues de funciones serverless
- Configura permisos y roles de funciones
- Maneja variables de entorno (Entrada) de funciones
- Implementa versionado y alias de funciones


#### 5. Módulo S3 Bucket (`modules/s3_bucket`)
- Gestiona el alojamiento del sitio web estático
- Configura políticas y permisos de bucket
- Maneja almacenamiento de activos estáticos y fotos de usuarios
- Implementa configuración de sitio web y CORS


### Funciones Lambda

#### Gestión de Usuarios
- `registroCognito`: Registro de nuevos usuarios
- `inicioSesionCognito`: Autenticación de usuarios
- `confirmarUsuarioCognito`: Confirmación de cuentas
- `logoutCognito`: Cierre de sesión

#### Gestión de Recetas
- `guardarReceta`: Creación y actualización de recetas con soporte para imágenes
- `obtenerReceta`: Obtención de detalles de recetas individuales
- `obtenerRecetasUsuario`: Listado de recetas por usuario
- `busquedaReceta`: Búsqueda avanzada de recetas

#### Gestión de Favoritos
- `addFavorite`: Agregar recetas a favoritos
- `getFavorites`: Obtener lista de favoritos
- `removeFavorite`: Eliminar recetas de favoritos

## Meta-argumentos Utilizados

### 1. `for_each`
Utilizado en múltiples recursos para crear instancias dinámicas:
```hcl
# En módulo Lambda para crear múltiples funciones
resource "aws_lambda_function" "this" {
  for_each = var.lambdas
  function_name = each.key
  # ...
}

# En módulo S3 para subir múltiples archivos
resource "aws_s3_object" "files" {
  for_each = var.files
  key = each.key
  source = each.value
  # ...
}
```

### 2. `depends_on`
Implementado para manejar dependencias explícitas:
```hcl
# En Cognito User Pool Client
resource "aws_cognito_user_pool_client" "this" {
  # ...
  depends_on = [aws_cognito_user_pool.this]
}

# En S3 Bucket Policy
resource "aws_s3_bucket_policy" "public_read" {
  # ...
  depends_on = [aws_s3_bucket_public_access_block.this]
}

# En DynamoDB Items
resource "aws_dynamodb_table_item" "pizza_casera" {
  depends_on = [module.dynamodb_recetas]
  # ...
}
```

### 3. `lifecycle`
Utilizado para proteger recursos críticos:
```hcl
# En tabla DynamoDB
resource "aws_dynamodb_table" "this" {
  # ...
  lifecycle {
    prevent_destroy = true
  }
}
```

## Guía de Implementación

### Prerrequisitos
1. AWS CLI instalado y configurado
2. Terraform v1.0.0 o superior
3. Python 3.8 o superior
5. Git

### Pasos de Implementación

1. **Clonar el Repositorio**
   ```bash
   git clone <repositorio>
   cd tp3_cloud
   ```

2. **Configurar Variables de Entorno**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Editar terraform.tfvars con tus valores (Opcional si se le quiere cambiar el nombre a alguna variable)
   ```

3. **Inicializar Terraform**
   ```bash
   terraform init
   ```

4. **Validar la Configuración**
   ```bash
   terraform plan
   ```

5. **Desplegar la Infraestructura**
   ```bash
   terraform apply
   ```

6. **Verificar el Despliegue**
   - Acceder a la URL del frontend
   - Probar el registro de usuario
   - Luego de verificar el registro vía autenticación por mail, iniciar sesión en la pestaña correspondiente.

### Variables de Configuración

#### Requeridas
- `aws_region`: Región de AWS (default: "us-east-1")
- `project_name`: Nombre del proyecto
- `environment`: Entorno (dev/prod)

## Características Avanzadas

### Gestión de Imágenes
- Soporte para subida de fotos de recetas
- Almacenamiento seguro en S3
- Optimización automática de imágenes

### Sistema de Favoritos
- Marcado/desmarcado de recetas
- Lista personalizada por usuario

### Recetas Destacadas
- Contenido precargado mediante Terraform
- Actualización dinámica

## Seguridad

### Autenticación y Autorización
- Cognito User Pools y app client para gestión de usuarios
