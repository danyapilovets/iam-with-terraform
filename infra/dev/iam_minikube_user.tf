resource "aws_iam_user" "external_secrets_minikube" {
  name = "${local.name_prefix}-external-secrets-minikube-user"
  tags = {
    Environment = var.environment
    Purpose     = "minikube-external-secrets"
  }
}
resource "aws_iam_user_policy_attachment" "external_secrets_minikube" {
  user       = aws_iam_user.external_secrets_minikube.name
  policy_arn = module.policy_external_secrets.policy_arn
}
resource "aws_iam_access_key" "external_secrets_minikube" {
  user = aws_iam_user.external_secrets_minikube.name
}