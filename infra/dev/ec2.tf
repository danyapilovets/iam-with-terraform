# Demo EC2 instance (optional)

module "ec2_instance" {
  source                    = "../modules/ec2"
  name                      = "${local.name_prefix}-instance"
  ami                       = var.ami_id
  instance_type             = var.instance_type
  subnet_id                 = var.public_subnet_id
  security_group_ids        = [var.sg_id]
  iam_instance_profile_name = aws_iam_instance_profile.ec2_profile.name
  tags = {
    Environment = var.environment
  }
}
