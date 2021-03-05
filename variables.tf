
variable environment {
  type = string
}

variable project {
  type = string
}

variable root_domain {
  type = string
}

variable create_route_53_subdomain {
  type = bool
  default = true
}

variable domain {
  type = string
}

variable vpc_id {
  type = string
  description = "The ID of an existing VPC to reuse"
  default = null
}

variable loadbalancer_acm_arn {
  type = string
  description = "The ARN of an ACM certificate to attach to the Load Balancer"
  default = ""
}

variable cognito_acm_arn {
  type = string
  description = "The ARN of an ACM certificate to attach to the Cognito App Domain (must be in us-east-1)"
  default = ""
}

variable private_subnets {
  type = list(any)
  description = "A list of private subnets within the existing VPC"
  default = null
}


variable enable_irsa {
  type        = bool
  description = "Set to true to enable IAM Roles for Service Accounts"
  default     = false
}

variable enable_secret_encryption {
  type        = bool
  description = "Set to true to create a KMS key to be used as a CMK (Cluster Master Key) for secret encryption"
  default     = false
}

variable self_sign_acm_certificate {
  type        = bool
  description = "Set to true in order to create a self-signed ACM certificates instead of letting ACM create and validate them"
  default     = false
}

variable "secret_manager_full_access" {
  default     = false
  description = <<EOT
  By setting this to true, the assumable role that is created for the Service Account attached to the External-Secrets application will have full access to all AWS Secret Manager keys prefixed the name of the cluster. 
  We recommend setting this to false and instead creating roles with fine-granular access policies for each ExternalSecret you define, and allow the role created here to assume those roles.
  EOT
}
variable "secret_manager_assume_from_node_role" {
  default     = false
  description = <<EOT
  By setting this to true, we assume that the External-Secrets application will start with the Worker Nodes Role (i.e. the roll that is available to all pods in the cluster). This should be used if IRSA has not yet been activated, so that
  the External-Secrets application cannot be started with a specific role. From here, the Worker Node roll should be set to be assumable by the rolls that have access to the external secrets.
  EOT
}

variable aws_account {
  type = string
}

variable cluster_name {
  type = string
}

variable aws_region {
  type = string
}
variable argocd_branch {
  type = string
}

variable argocd_path_prefix {
  type = string
  default = ""
}

variable argocd_apps_dir {
  type    = string
  default = "apps"
}

variable argocd_repo_url {
  type = string
  default = ""
}

variable argocd_repo_ssh_private_key {
  type = string
  default = ""
}

variable argocd_repo_https_username {
  type = string
  default = ""
}

variable argocd_repo_https_password {
  type = string
  default = ""
}


variable kubeflow_manifests_branch {
  type = string
}

variable kubeflow_manifests_tag {
  type = string
}

variable db_name_mlflow {
  type = string
  description = "Name of the database on the RDS instance that is used for mlflow"
  default = "mlflow"
}
variable db_name_pipelines {
  type = string
  description = "Name of the database on the RDS instance that is used for pipelines"
  default = "mlpipeline"
}

variable db_name_cache{
  type = string
  description = "Name of the database on the RDS instance that is used for cache"
  default = "cachedb"
}

variable db_name_metadata {
  type = string
  description = "Name of the database on the RDS instance that is used for metadata"
  default = "metadb"
}

variable db_name_katib {
  type = string
  description = "Name of the database on the RDS instance that is used for katib"
  default = "katib"
}


variable kubeflow_cognito_groups {
  type = string
}

variable kubeflow_profiles {
  type = list
}

variable kubeflow_cognito_users {
  description = "A mapping of users to groups, with unique hashes "
  type = list(object({
    username    = string
    email       = string
    group       = string //TODO current this entry will have no effect. All users are assigned to "default"
    user_hash   = string // a unique has representation of the user. Must be alphanumeric and max 64 chars. For example sha("user@${username}").
    user_group_hash = string // a unique has representation of the user. Must be alphanumeric and max 64 chars. For example sha("user-group@${username}"). Must differ from user_hash as each must be unique
  }))
  default = []
}

variable aws_private {
  type = bool
  default = false
}

variable aws_auth_user_mapping {
  description = "Additional IAM users to add to the aws-auth configmap."
  type = list(object({
    userarn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable aws_auth_role_mapping {
  description = "Additional IAM roles to add to the aws-auth configmap."
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}

variable cert_manager_email {
  type = string
}

variable kubernetes_version {
  type = string
}

variable cognito_callback_prefix_kubeflow {
  type = string
  default = "kubeflow"
}

variable cognito_callback_prefix_argocd {
  type = string
  default = "argocd"
}

variable availability_zones {
  type = list(any)
}

variable kube2iam_role_arn {
  type = string
}
variable tags {
  type = map(string)
}

variable "rds_database_name" {
  type        = string
  description = "Database name"
  default     = "exampledb"
}

variable "rds_database_multi_az" {
  type        = bool
  description = "Enabled multi_az for RDS"
  default     = "true"
}

variable "rds_database_engine" {
  type        = string
  description = "What server use? postgres | mysql | oracle-ee | sqlserver-ex"
  default     = "postgres"
}

variable "rds_database_engine_version" {
  type        = string
  description = "Engine version"
  default     = "9.6.9"
}

variable "rds_database_major_engine_version" {
  type        = string
  description = "Major Database engine version"
}

variable "rds_database_instance" {
  type        = string
  description = "RDS instance type"
  default     = "db.t3.large"
}

variable "rds_database_username" {
  type        = string
  description = "Database username"
  default     = "sa"
}

variable "rds_database_password" {
  type        = string
  description = "Database password"
  default     = ""
}

variable "rds_kms_key_id" {
  type        = string
  description = "Id of kms key for encrypt database"
  default     = ""
}

variable "rds_allocated_storage" {
  type        = string
  description = "Database storage in GB"
  default     = "10"
}

variable "rds_storage_encrypted" {
  type        = string
  description = "Database must be encrypted?"
  default     = "false"
}

variable "rds_maintenance_window" {
  type        = string
  description = "The window to perform maintenance in. Syntax: 'ddd:hh24:mi-ddd:hh24:mi'"
  default     = "Mon:00:00-Mon:03:00"
}

variable "rds_backup_window" {
  type        = string
  description = ""
  default     = "03:00-06:00"
}

variable "rds_port_mapping" {
  description = "mapping port for engine type"
  default = {
    "postgres"     = "5432",
    "sqlserver-ex" = "1433",
    "mysql"        = "3306",
    "oracle-ee"    = "1521"
  }
}

variable "rds_database_delete_protection" {
  type        = bool
  description = "enabled delete protection for database"
  default     = "false"
}

variable "rds_database_tags" {
  default     = {}
  description = "Additional tags for rds instance"
  type        = map(string)
}

variable "rds_iam_database_authentication_enabled" {
  default     = false
  description = "Set to true to authenticate to RDS using an IAM role"
  type        = bool
}


variable "rds_enabled_cloudwatch_logs_exports" {
  default     = []
  description = "List of cloudwatch log types to enable"
  type        = list(string)
}
variable "rds_instance_name" {
  description = "Name of the RDS instance"
  type        = string
}

variable "rds_publicly_accessible" {
  description = "Set to true to enable accessing the RDS DB from outside the VPC"
  default = false
  type    = bool
}

variable "workers_additional_policies" {
  type  = list
  default = []
  description = "List of ARNs of additional policies to attach to workers"
}

variable "wait_for_cluster_interpreter" {
  type = list
  default = ["/bin/bash", "-c"]
  description = "Interpreter in which to run 'wait for cluster' command"
}

variable "worker_groups" {
  description = "A list of maps defining worker group configurations to be defined using AWS Launch Templates. See workers_group_defaults_defaults in https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/local.tf"
  type        = any
  default     = []
}

variable "worker_groups_launch_template" {
  description = "A list of maps defining worker group configurations to be defined using AWS Launch Templates. See workers_group_defaults_defaults in https://github.com/terraform-aws-modules/terraform-aws-eks/blob/master/local.tf"
  type        = any
  default     = []
}
