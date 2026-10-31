# scripts/deploy-*.sh and CI read these with `terraform output -raw <name>`.
output "api_url" { value = "https://${module.web.domain}/api" }
output "web_url" { value = "https://${module.web.domain}" }
output "web_bucket" { value = module.web.bucket }
output "web_distribution_id" { value = module.web.distribution_id }
output "artifacts_bucket" { value = module.backend.artifacts_bucket }
output "instance_id" { value = module.backend.instance_id }

# Gateway (devops/scripts/deploy-gateway.sh renders devops/gateway/kong.yml with these)
output "gateway_instance_id" { value = module.gateway.instance_id }
output "gateway_public_ip" { value = module.gateway.public_ip }
output "gateway_image" { value = var.kong_image }
output "backend_url" { value = "http://${local.backend_private_ip}:${var.app_port}" }
output "api_rate_limit_per_second" { value = var.api_rate_limit_per_second }
output "api_rate_limit_per_minute" { value = var.api_rate_limit_per_minute }
output "gateway_origin_secret" {
  value     = module.gateway.origin_secret
  sensitive = true
}
