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
  description = "Extra origins allowed to call the API (e.g. local dev); the web app shares CloudFront's origin"
}

variable "gateway_instance_type" {
  type        = string
  default     = "t4g.micro"
  description = "Graviton (arm64) instance for the Kong gateway (also the private subnet's NAT)"
}

variable "kong_image" {
  type        = string
  default     = "kong:3.9.4"
  description = "Kong OSS image. 3.9.x is the last line Kong publishes as open source."
}

variable "gateway_port" {
  type        = number
  default     = 8000
  description = "Kong proxy port that CloudFront connects to"
}

variable "api_rate_limit_per_second" {
  type        = number
  default     = 20
  description = "Requests per second per client IP, enforced by Kong"
}

variable "api_rate_limit_per_minute" {
  type        = number
  default     = 600
  description = "Requests per minute per client IP, enforced by Kong"
}
