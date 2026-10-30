# scripts/deploy-*.sh and CI read these with `terraform output -raw <name>`.
output "api_url" { value = module.api.url }
output "web_url" { value = "https://${module.web.domain}" }
output "web_bucket" { value = module.web.bucket }
output "web_distribution_id" { value = module.web.distribution_id }
output "artifacts_bucket" { value = module.backend.artifacts_bucket }
output "instance_id" { value = module.backend.instance_id }
