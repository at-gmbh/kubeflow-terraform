locals {

  external_secrets_deployment_role_arn = var.secret_manager_assume_from_node_role ? module.kubernetes.worker_iam_role_arn : module.external_secrets.external_secrets_role_arn

}