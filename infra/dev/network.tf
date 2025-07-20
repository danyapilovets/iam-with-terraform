# Network resources

# Public subnet reference
data "aws_subnet" "public" {
  id = var.public_subnet_id
}

# =================== INTERFACE VPC ENDPOINT ===================
# Interface VPC Endpoint для S3 (через ENI с приватным IP)
# 💰 СТОИМОСТЬ: ~$7.20/месяц за endpoint + $0.01 за GB transfer
# 🔒 БЕЗОПАСНОСТЬ: Можно настроить Security Groups и NACLs
# 📍 РАСПОЛОЖЕНИЕ: Внутри subnet, имеет ENI с приватным IP
module "vpce_s3" {
  source               = "../modules/vpc-endpoint"
  vpc_id               = data.aws_subnet.public.vpc_id
  service_name         = "com.amazonaws.${var.aws_region}.s3"
  endpoint_type        = "Interface"  # ВАЖНО: Interface endpoint
  subnet_ids           = [var.public_subnet_id]
  security_group_ids   = [var.sg_id]
  private_dns_enabled  = var.private_dns_enabled
  tags = {
    Environment = var.environment
    Type       = "Interface"
    Service    = "S3"
  }
}

# НОВОЕ: Interface VPC Endpoint для Secrets Manager
# 🎯 ПОЛЬЗА: Для External Secrets Operator в K8s
module "vpce_secrets_manager" {
  source               = "../modules/vpc-endpoint"
  vpc_id               = data.aws_subnet.public.vpc_id
  service_name         = "com.amazonaws.${var.aws_region}.secretsmanager"
  endpoint_type        = "Interface"
  subnet_ids           = [var.public_subnet_id]
  security_group_ids   = [var.sg_id]
  private_dns_enabled  = true
  tags = {
    Environment = var.environment
    Type       = "Interface"
    Service    = "SecretsManager"
    Purpose    = "ExternalSecretsOperator"
  }
}

# =================== GATEWAY VPC ENDPOINT ===================
# ⚠️ ПРИМЕЧАНИЕ: Gateway endpoints для S3 НЕ РАБОТАЮТ с Interface endpoints
# Если нужен Gateway endpoint для S3, надо убрать Interface endpoint выше
# 💰 СТОИМОСТЬ: БЕСПЛАТНО (только за transfer данных)
# 🔒 БЕЗОПАСНОСТЬ: Используют route tables, не поддерживают Security Groups

# ПРИМЕР Gateway endpoint (закомментирован, т.к. конфликтует с Interface)
# resource "aws_vpc_endpoint" "s3_gateway" {
#   vpc_id       = data.aws_subnet.public.vpc_id
#   service_name = "com.amazonaws.${var.aws_region}.s3"
#   
#   # ВАЖНО: Gateway type
#   vpc_endpoint_type = "Gateway"
#   
#   # Gateway endpoints используют route tables вместо subnets
#   route_table_ids = [data.aws_route_table.public.id]
#   
#   # Gateway endpoints не поддерживают:
#   # - security_group_ids
#   # - subnet_ids  
#   # - private_dns_enabled
#   
#   tags = {
#     Environment = var.environment
#     Type       = "Gateway"
#     Service    = "S3"
#   }
# }

# =================== КОГДА ИСПОЛЬЗОВАТЬ КАКОЙ ТИП ===================

# 🏆 INTERFACE ENDPOINTS - используйте когда:
# - Нужны Security Groups для точного контроля доступа
# - Приложения в приватных подсетях без NAT Gateway
# - Cross-VPC доступ через VPC Peering/Transit Gateway
# - Нужен Private DNS для прозрачного подключения
# - Готовы платить за стабильность и безопасность

# 🏆 GATEWAY ENDPOINTS - используйте когда:  
# - Нужна максимальная экономия (бесплатные)
# - S3 или DynamoDB доступ из той же VPC
# - Простая архитектура без сложных сетевых требований
# - Не нужны Security Groups на уровне endpoint

# НОВОЕ: Data source для route table (если понадобится Gateway endpoint)
# data "aws_route_table" "public" {
#   subnet_id = var.public_subnet_id
# }

# НОВОЕ: Security Group для Interface Endpoints (лучшая практика)
resource "aws_security_group" "vpce_sg" {
  name_prefix = "${local.name_prefix}-vpce-"
  vpc_id      = data.aws_subnet.public.vpc_id
  description = "Security group for VPC Interface Endpoints"

  # Входящий HTTPS трафик только от ресурсов в VPC
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.main.cidr_block]
    description = "HTTPS from VPC resources"
  }

  # Исходящий трафик для DNS разрешения
  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS TCP queries"
  }

  egress {
    from_port   = 53
    to_port     = 53
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "DNS UDP queries"
  }

  tags = {
    Environment = var.environment
    Purpose     = "VPCEndpoints"
  }
}

# VPC data source для CIDR
data "aws_vpc" "main" {
  id = data.aws_subnet.public.vpc_id
}
