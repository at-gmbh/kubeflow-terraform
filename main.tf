
module network {
  count = var.vpc_id == null ? 1 : 0
  source             = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/network?ref=feature/self_signed_cert"
  availability_zones = var.availability_zones
  environment        = var.environment
  project            = var.project
  cluster_name       = var.cluster_name
  tags               = var.tags
}



locals  {
  vpc_id = var.vpc_id == null ? module.network[0].vpc.vpc_id : var.vpc_id
  private_subnets = var.vpc_id == null ? module.network[0].vpc.private_subnets : var.private_subnets
}


// Worker additional policy (to allow read/write access to S3 bucket for Pipelines)
resource "aws_iam_policy" "worker_group_policy" {
  name        = "${var.cluster_name}-worker-policy"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "ListObjectsInBucket",
            "Effect": "Allow",
            "Action": ["s3:ListBucket"],
            "Resource": ["${module.s3.s3_bucket_arn}"]
        },
        {
            "Sid": "AllObjectActions",
            "Effect": "Allow",
            "Action": "s3:*Object",
            "Resource": ["${module.s3.s3_bucket_arn}/*"]
        }
    ]
}
EOF
}

// Kubernetes Cluster
module kubernetes {
  source             = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/kubernetes?ref=feature/self_signed_cert"
  availability_zones = var.availability_zones
  environment        = var.environment
  project            = var.project
  cluster_name       = var.cluster_name
  cluster_version    = var.kubernetes_version
  vpc_id             = local.vpc_id
  subnets            = local.private_subnets
  aws_auth_user_mapping    = var.aws_auth_user_mapping
  aws_auth_role_mapping    = var.aws_auth_role_mapping
  wait_for_cluster_interpreter = var.wait_for_cluster_interpreter

  enable_irsa = var.enable_irsa
  enable_secret_encryption = var.enable_secret_encryption

  workers_additional_policies = concat([aws_iam_policy.worker_group_policy.arn], var.workers_additional_policies)
  
  worker_groups = var.worker_groups
  worker_groups_launch_template = var.worker_groups_launch_template

  tags = var.tags

}



// ACM certificate for load balancer

# create normal certifcate
module acm {
  source       = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/acm/?ref=feature/self_signed_cert"

  # create_certificate        = local.create_acm_certificate ? true : false  //only create if an existing ACM certificate hasn't been provided and not creating a self-signed cert
  loadbalancer_acm_arn      = var.loadbalancer_acm_arn
  self_sign_acm_certificate = var.self_sign_acm_certificate
  domain_name               = var.domain
  subject_alternative_names = ["*.${var.domain}"]
  zone_id                   = module.external_dns.zone_id
  validate_certificate      = var.aws_private == false ? true : false
  tags                      = var.tags

}





// Create Cognito User Pool
module cognito {
  source       = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/cognito/user-pool?ref=feature/self_signed_cert"
  domain       = var.domain //TODO make "auth" parameterisable? Currently it is hardcode in the "cognito" module
  zone_id      = module.external_dns.zone_id
  cluster_name = module.kubernetes.cluster_name
  acm_arn      = var.cognito_acm_arn
  self_sign_acm_certificate = var.self_sign_acm_certificate
  tags         = var.tags
  invite_template = {
    email_subject = "You've been invited to https://${var.cognito_callback_prefix_kubeflow}.${var.domain}"
    email_message = <<EOT
Hi {username}, welcome to https://${var.cognito_callback_prefix_kubeflow}.${var.domain}. Your temporary password is {####}
EOT
    sms_message   = <<EOT
Hi {username}, you have been invited to access Alexander Thamm's Kubeflow cluster. Your temporary password is {####}
EOT
  }
}

// Create Cognito User Pool Client (Kubeflow)
resource aws_cognito_user_pool_client kubeflow {
  name                                 = "kubeflow"
  user_pool_id                         = module.cognito.pool_id
  callback_urls                        = ["https://${var.cognito_callback_prefix_kubeflow}.${var.domain}/oauth2/idpresponse"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile", "aws.cognito.signin.user.admin"]
  allowed_oauth_flows                  = ["code"]
  supported_identity_providers         = ["COGNITO"]
  generate_secret                      = true

}

// Create Cognito User Pool Client (ArgoCD)
resource aws_cognito_user_pool_client argocd {
  //TODO shouldn't this go to a separate user pool?
  name                                 = "argocd"
  user_pool_id                         = module.cognito.pool_id
  callback_urls                        = ["https://${var.cognito_callback_prefix_argocd}.${var.domain}/auth/callback"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["openid", "profile", "email"]
  allowed_oauth_flows                  = ["code"]
  supported_identity_providers         = ["COGNITO"]
  generate_secret                      = true

}


// Create Cognito Users
module cognito_users {
  source = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/cognito/users?ref=feature/self_signed_cert"
  cloudformation_stack_name = "${var.cluster_name}-cognito-users"
  pool_id  = module.cognito.pool_id
  user_groups = ["default"] //TODO
  users = var.kubeflow_cognito_users
  tags = var.tags
}


// Create RDS instance
module "rds" {
  source  = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/rds?ref=feature/self_signed_cert"

  environment  = var.environment
  project      = var.project
  cluster_name = module.kubernetes.cluster_name

  vpc_id = local.vpc_id
  subnets =  local.private_subnets
  worker_security_group_id = module.kubernetes.worker_security_group_id

  
  rds_publicly_accessible = var.rds_publicly_accessible
  rds_database_name = var.rds_database_name
  rds_instance_name = var.rds_instance_name
  rds_database_multi_az = var.rds_database_multi_az
  rds_database_engine = var.rds_database_engine
  rds_database_major_engine_version = var.rds_database_major_engine_version
  rds_database_engine_version = var.rds_database_engine_version
  rds_database_instance = var.rds_database_instance
  rds_iam_database_authentication_enabled = var.rds_iam_database_authentication_enabled
  rds_allocated_storage = var.rds_allocated_storage
  rds_storage_encrypted = var.rds_storage_encrypted
  rds_database_delete_protection = var.rds_database_delete_protection
  rds_enabled_cloudwatch_logs_exports = var.rds_enabled_cloudwatch_logs_exports
  rds_database_tags = var.rds_database_tags
  rds_database_username = var.rds_database_username
  rds_database_password = var.rds_database_password
}


// Create S3 bucket
module "s3" {
  source            = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/storage/s3?ref=feature/self_signed_cert"
  module_depends_on = []
  s3_bucket_name    = "${var.aws_account}-${var.cluster_name}-kubeflow"
  cluster_name      = var.cluster_name
  tags              = var.tags
  trusted_role_arns = [var.kube2iam_role_arn]
}





////  Kubernetes Resources




// Namespace for knative-serving
resource "kubernetes_namespace" "knative_serving" {
  depends_on = [module.kubernetes]
  metadata {
    labels = {
      "serving.knative.dev/release": "v0.14.3"
    }
    name = "knative-serving"
  }
}


// knative configmap to point to correct domain
resource "kubernetes_config_map" "knative_config_map" {
  depends_on = [kubernetes_namespace.knative_serving]
  metadata {
    name = "config-domain"
    namespace = "knative-serving"
    labels = {
      "serving.knative.dev/release" = "v0.14.3"
    }
  }
  data = {
    (var.domain) = ""
  }
}

// knative configmap to point to use corret domainTemplate
resource "kubernetes_config_map" "knative_network_config_map" {
  depends_on = [kubernetes_namespace.knative_serving]
  metadata {
    name = "config-network"
    namespace = "knative-serving"
    labels = {
      "serving.knative.dev/release" = "v0.14.3"
    }
  }
  data = {
    "domainTemplate" = "{{.Name}}-{{.Namespace}}.{{.Domain}}"
  }
}

// ArgoCD
module argocd {
  source                    = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/cicd/argo-cd?ref=feature/self_signed_cert"
  module_depends_on         = [module.kubernetes]
  sync_branch               = var.argocd_branch
  sync_path_prefix          = var.argocd_path_prefix
  sync_apps_dir             = var.argocd_apps_dir
  sync_repo_url             = var.argocd_repo_url
  sync_repo_ssh_private_key = var.argocd_repo_ssh_private_key
  sync_repo_https_username = var.argocd_repo_https_username
  sync_repo_https_password = var.argocd_repo_https_password


  cluster_name  = module.kubernetes.cluster_name
  domains       = [var.domain]
  helm_chart_version = "2.7.4"
  oidc = {
    secret = aws_cognito_user_pool_client.argocd.client_secret
    pool   = module.cognito.pool_id
    name   = "Cognito"
    id     = aws_cognito_user_pool_client.argocd.id
  }
  ingress_annotations = {
    "kubernetes.io/ingress.class"               = "alb"
    "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
    "alb.ingress.kubernetes.io/certificate-arn" = module.acm.loadbalancer_acm_arn
    "alb.ingress.kubernetes.io/listen-ports" = jsonencode(
      [{ "HTTPS" = 443 }]
    )
  }

  tags        = var.tags
}



//// Kubernetes YAML Specs for Applications managed by ArgoCD

// Create YAML specs for MLFLow
module mlflow {
  source = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/mlflow?ref=feature/self_signed_cert"
  argocd = module.argocd.state
  rds_username = module.rds.this_db_instance_username
  rds_password = module.rds.this_db_instance_password  
  rds_host = module.rds.this_db_instance_address
  rds_port = module.rds.this_db_instance_port

  db_name = var.db_name_mlflow

  s3_bucket_name = module.s3.s3_bucket_name

  cluster_name = module.kubernetes.cluster_name

  tags = var.tags

  external_secrets_deployment_role_arn = local.external_secrets_deployment_role_arn
  //external_secrets_secret_role_arn = module.external_secrets.external_secrets_role_arn

}

// Create YAML specs for Kubeflow Profiles
module profiles {
  source = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/kubeflow-profiles?ref=feature/self_signed_cert"
  argocd = module.argocd.state
  profiles = var.kubeflow_profiles
}

// Create YAML specs for kube2iam
module kube2iam {
  source = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/system/kube2iam?ref=feature/self_signed_cert"
  argocd = module.argocd.state
  base_role_arn = var.kube2iam_role_arn
}

// Create YAML specs for KFServing
module kfserving {
  source = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/kfserving/0-3-0/?ref=feature/self_signed_cert"
  argocd = module.argocd.state
}

// Create YAML specs for External-Secrets
module external_secrets {
  source = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/system/external-secrets?ref=feature/self_signed_cert"
  argocd = module.argocd.state  
  cluster_name = var.cluster_name
  cluster_oidc_url = module.kubernetes.cluster_oidc_url

  // Set to false create and attach role to external_secrets service account that has no policies attached to it. This role will then be used to assume other role with fine granular access. This is the recommended approach
  // Set to true to with the external_secrets service account full access to all secrets prefixed with the cluster name. This is more convenient but less secure.
  secret_manager_full_access = var.secret_manager_full_access
}


// Create YAML specs for Kubeflow Operator and KFDef
module kubeflow {
  source = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/kubeflow-operator?ref=feature/self_signed_cert"
  rds_username = module.rds.this_db_instance_username
  rds_password = module.rds.this_db_instance_password  
  rds_host = module.rds.this_db_instance_address
  rds_port = module.rds.this_db_instance_port

  db_name_pipelines = var.db_name_pipelines
  db_name_katib = var.db_name_katib
  db_name_cache = var.db_name_cache
  db_name_metadata = var.db_name_metadata

  pipelines_role_to_assume_role_arn = module.s3.s3_role_arn //TODO, must set up pipelines serviceaccount to be able to assume this role!

  s3_bucket_name = module.s3.s3_bucket_name
  s3_user_access_key = module.s3.s3_user_access_key

  cluster_name = module.kubernetes.cluster_name

  tags = var.tags

  external_secrets_deployment_role_arn = local.external_secrets_deployment_role_arn
  //external_secrets_secret_role_arn = module.external_secrets.external_secrets_role_arn

  ingress_annotations = {
    "kubernetes.io/ingress.class"               = "alb"
    "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
    "alb.ingress.kubernetes.io/certificate-arn" = module.acm.loadbalancer_acm_arn
    "alb.ingress.kubernetes.io/auth-type"       = "cognito"
    "alb.ingress.kubernetes.io/auth-idp-cognito" = jsonencode({
      "UserPoolArn"      = module.cognito.pool_arn
      "UserPoolClientId" = aws_cognito_user_pool_client.kubeflow.id
      "UserPoolDomain"   = module.cognito.domain
    })
    "alb.ingress.kubernetes.io/listen-ports" = jsonencode(
      [{ "HTTPS" = 443 }]
    )
  }
  domain = "kubeflow.${var.domain}"
  argocd = module.argocd.state


  repository = "https://github.com/at-gmbh/kubeflow-manifests"
  ref        =  var.kubeflow_manifests_branch
  kfdef = <<EOT
apiVersion: kfdef.apps.kubeflow.org/v1
kind: KfDef
metadata:
  namespace: kubeflow
  name: kubeflow
spec:
  applications:
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: namespaces/base
      name: namespaces
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: stacks/aws/application/istio-stack
      name: istio-stack
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: stacks/aws/application/cluster-local-gateway
      name: cluster-local-gateway
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: stacks/aws/application/istio
      name: istio
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: application/v3
      name: application
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: metacontroller/base
      name: metacontroller
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: admission-webhook/bootstrap/overlays/application
      name: bootstrap
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: spark/spark-operator/overlays/application
      name: spark-operator
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: knative/installs/generic
      name: knative
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: stacks/aws/application/spartakus
      name: spartakus
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: stacks/aws
      name: kubeflow-apps
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: stacks/aws/application/istio-ingress-cognito
      name: istio-ingress
    - kustomizeConfig:
        repoRef:
          name: manifests
          path: aws/aws-istio-authz-adaptor/base_v3
      name: aws-istio-authz-adaptor
  repos:
    - name: manifests
      uri: 'https://github.com/at-gmbh/manifests/archive/${var.kubeflow_manifests_tag}.tar.gz'
  version: ${var.kubeflow_manifests_branch}
EOT
 
}

// Create YAML specs for Cluster Autoscaler
module cluster_autoscaler {
  source            = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/system/cluster-autoscaler?ref=feature/self_signed_cert"
  image_tag         = "v1.15.7"
  cluster_name      = module.kubernetes.cluster_name
  module_depends_on = [module.kubernetes]
  argocd            = module.argocd.state
  tags              = var.tags
}

// Create YAML specs for Certificate Manager
module cert_manager {
  module_depends_on = [module.kubernetes]
  source            = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/system/cert-manager?ref=feature/self_signed_cert"
  cluster_name      = module.kubernetes.cluster_name
  domains           = [var.domain]
  vpc_id            = local.vpc_id
  environment       = var.environment
  project           = var.project
  zone_id           = module.external_dns.zone_id
  email             = var.cert_manager_email
  argocd            = module.argocd.state
}


// Create YAML specs for ALB Ingress
module alb_ingress {
  module_depends_on = [module.kubernetes]
  source            = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/ingress/aws-alb?ref=feature/self_signed_cert"
  cluster_name      = module.kubernetes.cluster_name
  domains           = [var.domain]
  vpc_id            = local.vpc_id
  certificates_arns = [module.acm.loadbalancer_acm_arn]
  argocd            = module.argocd.state
}

// Create YAML specs for External DNS
module external_dns {
  source       = "git::https://github.com/at-gmbh/swiss-army-kube.git//modules/system/external-dns?ref=feature/self_signed_cert"
  cluster_name = module.kubernetes.cluster_name
  vpc_id       = local.vpc_id
  aws_private  = var.aws_private
  hosted_zone_domain      = var.root_domain
  hosted_zone_subdomain   = var.create_route_53_subdomain ? var.domain : null
  argocd       = module.argocd.state
  tags         = var.tags
}