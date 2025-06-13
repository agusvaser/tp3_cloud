resource "aws_lambda_function" "this" {
  # Crea múltiples Lambdas con for_each a partir del mapa "lambdas" recibido como variable
  for_each = var.lambdas

  # Nombre de la función Lambda
  function_name = each.key

  # Role ARN existente (Lab Role) para permisos de ejecución
  role = var.lambda_role_arn

  # Handler, indica el archivo y función Python a invocar
  handler = "lambda_function.lambda_handler"

  # Runtime, aquí indicamos Python 3.9
  runtime = "python3.9"

  # Ruta al archivo .zip con el código fuente
  filename         = "${path.root}/${each.value.source_zip}"
  # Hash del código para forzar actualización cuando cambie
  source_code_hash = filebase64sha256("${path.root}/${each.value.source_zip}")

  # Variables de entorno opcionales (si se definieron en el mapa)
  environment {
    variables = each.value.env_vars
  }

  # Configuración VPC (condicional por función)
  dynamic "vpc_config" {
    for_each = (var.vpc_config != null && each.value.use_vpc) ? [var.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  # Timeout de ejecución en segundos
  timeout = 30

  tags = {
    Name = each.key
    Type = "Lambda"
    VPC  = each.value.use_vpc ? "true" : "false"
  }
}