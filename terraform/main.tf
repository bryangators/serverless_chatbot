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

resource "null_resource" "install_layer_dependencies" {
  provisioner "local-exec" {
    command = "pip install -r layer/requirements.txt -t layer/python/lib/python3.12/site-packages"
  }
  triggers = {
    trigger = timestamp()
  }
}

data "archive_file" "layer_zip" {
  type        = "zip"
  source_dir  = "layer"
  output_path = "layer.zip"
  depends_on = [
    null_resource.install_layer_dependencies
  ]
}

resource "aws_lambda_layer_version" "lambda_layer" {
  filename         = "layer.zip"
  source_code_hash = data.archive_file.layer_zip.output_base64sha256
  layer_name       = "serverless_chatbot_layer"

  compatible_runtimes = ["python3.12"]
  depends_on = [
    data.archive_file.layer_zip
  ]
}

resource "random_uuid" "lambda_src_hash" {
  keepers = {
    for filename in setunion(
      fileset(path.module, "python/index.py")
    ) :
    filename => filemd5("${path.module}/${filename}")
  }
}

data "archive_file" "lambda_source" {
  excludes = [
    "__pycache__",
    "venv",
  ]

  source_dir  = "python/"
  output_path = "python/${random_uuid.lambda_src_hash.result}.zip"
  type        = "zip"
}

resource "aws_lambda_function" "terraform_lambda_func" {
  filename      = "python/${random_uuid.lambda_src_hash.result}.zip" # This should now contain only your script
  function_name = "Serverless_Chatbot_Lambda_Function"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.12"

  layers = [
    aws_lambda_layer_version.lambda_layer.arn
  ]

  depends_on = [data.archive_file.lambda_source,
  aws_lambda_layer_version.lambda_layer]
}

resource "aws_lambda_function_url" "lambda_url" {
  function_name      = aws_lambda_function.terraform_lambda_func.function_name
  authorization_type = "NONE"
}