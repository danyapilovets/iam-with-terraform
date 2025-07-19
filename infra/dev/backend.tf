terraform {
  backend "s3" {
        bucket         = "terraform-state-743680868500"
        key            = "dev/terraform.tfstate"
        region         = "eu-central-1"
        dynamodb_table = "terraform-locks"
        encrypt        = true
  }
}
