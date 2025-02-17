terraform {
  backend "s3" {
    bucket         = "serverless-chatbot-tfstate"
    key            = "global/s3/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "serverless-chatbot-tfstate-locking"
    encrypt        = true
  }
}