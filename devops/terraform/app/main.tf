locals {
  name = "${var.project}-${var.env}"

  # Fixed so the gateway config (devops/gateway/kong.yml) can target it.
  backend_private_ip = cidrhost(module.network.private_subnet_cidr, 10)
}

module "network" {
  source   = "../modules/network"
  name     = local.name
  vpc_cidr = var.vpc_cidr
}

module "web" {
  source            = "../modules/web"
  name              = local.name
  api_origin_domain = module.gateway.origin_domain
  api_origin_port   = var.gateway_port
  api_origin_secret = module.gateway.origin_secret
}

module "gateway" {
  source                 = "../modules/gateway"
  name                   = local.name
  vpc_id                 = module.network.vpc_id
  subnet_id              = module.network.public_subnet_ids[0]
  private_cidr           = module.network.private_subnet_cidr
  private_route_table_id = module.network.private_route_table_id
  instance_type          = var.gateway_instance_type
  kong_image             = var.kong_image
  proxy_port             = var.gateway_port
  artifacts_bucket       = module.backend.artifacts_bucket
  artifacts_bucket_arn   = module.backend.artifacts_bucket_arn
}

module "backend" {
  source        = "../modules/backend"
  name          = local.name
  env           = var.env
  vpc_id        = module.network.vpc_id
  subnet_id     = module.network.private_subnet_id
  private_ip    = local.backend_private_ip
  instance_type = var.instance_type
  app_port      = var.app_port
  allowed_from  = { gateway = module.gateway.security_group_id }
  cors_origins  = concat(["https://${module.web.domain}"], var.extra_cors_origins)
}
