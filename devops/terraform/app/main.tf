locals {
  name = "${var.project}-${var.env}"
}

module "network" {
  source   = "../modules/network"
  name     = local.name
  vpc_cidr = var.vpc_cidr
}

module "web" {
  source = "../modules/web"
  name   = local.name
}

module "backend" {
  source        = "../modules/backend"
  name          = local.name
  env           = var.env
  vpc_id        = module.network.vpc_id
  subnet_id     = module.network.public_subnet_ids[0]
  instance_type = var.instance_type
  app_port      = var.app_port
  allowed_from  = [module.api.vpc_link_security_group_id]
  cors_origins  = concat(["https://${module.web.domain}"], var.extra_cors_origins)
}

module "api" {
  source         = "../modules/api"
  name           = local.name
  vpc_id         = module.network.vpc_id
  subnet_ids     = module.network.public_subnet_ids
  cloudmap_arn   = module.backend.cloudmap_service_arn
  cors_origins   = concat(["https://${module.web.domain}"], var.extra_cors_origins)
  throttle_rate  = var.api_throttle_rate
  throttle_burst = var.api_throttle_burst
}
