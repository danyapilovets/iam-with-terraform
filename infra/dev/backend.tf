# terraform {
#   backend "s3" {
#     bucket         = "terraform-state-iwt-banking"
#     key            = "dev/terraform.tfstate"
#     region         = "eu-central-1"
#     dynamodb_table = "terraform-state-lock"
#     encrypt        = true
#   }
# }
