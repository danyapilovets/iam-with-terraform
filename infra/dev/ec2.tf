# Demo EC2 instance (optional)

module "ec2_instance" {
  source                    = "../modules/ec2"
  name                      = "${local.name_prefix}-instance"
  ami                       = var.ec2_ami_id
  instance_type             = var.ec2_instance_type
  subnet_id                 = var.ec2_public_subnet_id
  security_group_ids        = [var.ec2_security_group_id]
  iam_instance_profile_name = aws_iam_instance_profile.ec2_profile.name
  tags = {
    Environment = var.environment
  }
}
