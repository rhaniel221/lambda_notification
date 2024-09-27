# Cria o tópico SNS
resource "aws_sns_topic" "sns_alert" {
  name = "alertas-quicksight"
}

# Cria uma função Lambda
resource "aws_lambda_function" "postgres_lambda" {
  function_name = "PostgresLambda"
  role          = aws_iam_role.lambda_exec_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"

  environment {
    variables = {
      DB_HOST       = "your-rds-endpoint",
      DB_NAME       = "postgres",
      DB_USER       = "master",
      DB_PASSWORD   = "password",
      SNS_TOPIC_ARN = aws_sns_topic.sns_alert.arn,
      AWS_REGION    = "us-east-1"
    }
  }
}

# Permissões do Lambda para acessar SNS e RDS
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
}

# Anexa políticas de acesso para a função Lambda
resource "aws_iam_role_policy_attachment" "lambda_sns_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

resource "aws_iam_role_policy_attachment" "lambda_rds_policy" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonRDSFullAccess"
}

# Configuração do RDS PostgreSQL
resource "aws_db_instance" "postgres_rds" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "14.12"
  instance_class       = "db.t3.micro"
  name                 = "postgres"
  username             = "master"
  password             = "password"
  parameter_group_name = "default.postgres14"
  publicly_accessible  = false
  skip_final_snapshot  = true
}

# Permitir que a função Lambda seja acionada a cada 5 minutos
resource "aws_cloudwatch_event_rule" "lambda_schedule" {
  name                = "lambda_schedule"
  schedule_expression = "rate(5 minutes)"
}

resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.lambda_schedule.name
  target_id = "PostgresLambda"
  arn       = aws_lambda_function.postgres_lambda.arn
}

# Permissão para que CloudWatch invoque a função Lambda
resource "aws_lambda_permission" "allow_cloudwatch_to_call_lambda" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.postgres_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.lambda_schedule.arn
}
