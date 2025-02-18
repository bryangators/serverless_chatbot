provider "aws" {
  region = "us-east-1"
}

resource "aws_iam_role" "lambda_role" {
  name               = "serverless_chatbot_role"
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "lambda.amazonaws.com"
     },
     "Effect": "Allow",
     "Sid": ""
   }
 ]
}
EOF
}

resource "aws_iam_policy" "iam_policy_for_lambda" {

  name        = "aws_iam_policy_for_terraform_aws_lambda_role"
  path        = "/"
  description = "AWS IAM Policy for managing aws lambda role"
  policy      = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": [
       "logs:CreateLogGroup",
       "logs:CreateLogStream",
       "logs:PutLogEvents"
     ],
     "Resource": "arn:aws:logs:*:*:*",
     "Effect": "Allow"
   }
 ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "attach_iam_policy_to_iam_role" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.iam_policy_for_lambda.arn
}

resource "null_resource" "install_dependencies" {
  provisioner "local-exec" {
    command = "pip install -r ${path.module}/python/requirements.txt -t ${path.module}/python/"
  }

  triggers = {
    dependencies_versions = filemd5("${path.module}/python/requirements.txt")
    source_versions       = filemd5("${path.module}/python/index.py")
  }
}

resource "random_uuid" "lambda_src_hash" {
  keepers = {
    for filename in setunion(
      fileset(path.module, "function.py"),
      fileset(path.module, "requirements.txt")
    ) :
    filename => filemd5("${path.module}/${filename}")
  }
}

data "archive_file" "lambda_source" {
  depends_on = [null_resource.install_dependencies]
  excludes = [
    "__pycache__",
    "venv",
  ]

  source_dir  = "${path.module}/python/"
  output_path = "${random_uuid.lambda_src_hash.result}.zip"
  type        = "zip"
}

resource "aws_lambda_function" "terraform_lambda_func" {
  filename      = "${path.module}/python/serverless_python.zip"
  function_name = "Serverless_Chatbot_Lambda_Function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.8"
  depends_on    = [aws_iam_role_policy_attachment.attach_iam_policy_to_iam_role]
}

resource "aws_lambda_function_url" "lambda_url" {
  function_name      = aws_lambda_function.terraform_lambda_func.function_name
  authorization_type = "NONE"
}