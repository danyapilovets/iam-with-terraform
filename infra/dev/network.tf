# Network resources

# Public subnet reference
data "aws_subnet" "public" {
  id = var.public_subnet_id
}

# VPC Endpoint to S3
module "vpce_s3" {
  source               = "../modules/vpc-endpoint"
  vpc_id               = data.aws_subnet.public.vpc_id
  service_name         = "com.amazonaws.${var.aws_region}.s3"
  endpoint_type        = var.endpoint_type
  subnet_ids           = [var.public_subnet_id]
  security_group_ids   = [var.sg_id]
  private_dns_enabled  = var.private_dns_enabled
  tags = {
    Environment = var.environment
  }
}
