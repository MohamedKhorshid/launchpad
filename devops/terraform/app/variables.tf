variable "project" {
  type        = string
  description = "Short project slug; prefixes every resource name"
}

variable "env" {
  type        = string
  description = "Environment name: dev, prod, ..."
}

variable "region" { type = string }

variable "vpc_cidr" {
  type    = string
  default = "10.20.0.0/16"
}

variable "instance_type" {
  type        = string
  default     = "t4g.small"
  description = "Graviton (arm64) instance for the Go monolith"
}

variable "app_port" {
  type    = number
  default = 8080
}

variable "extra_cors_origins" {
  type        = list(string)
  default     = ["http://localhost:5173"]
  description = "Origins allowed to call the API besides the CloudFront web app"
}

variable "api_throttle_rate" {
  type    = number
  default = 50
}

variable "api_throttle_burst" {
  type    = number
  default = 100
}
