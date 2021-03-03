output argocd_state {
  value = module.argocd.state
}

output "vpc_id" {
  value = local.vpc_id
}

output "private_subnets" {
  value = local.private_subnets
}
