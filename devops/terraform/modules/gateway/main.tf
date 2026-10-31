# Public API gateway: Kong (OSS, DB-less) in Docker on one small EC2 instance.
#   CloudFront /api/* --HTTP:8000 + X-Origin-Verify--> Kong --> private backend
# The instance is the only internet-facing box: its security group accepts the
# proxy port from CloudFront's origin-facing IP ranges only, and it doubles as
# the NAT for the private subnet (source/dest check off + nftables masquerade).
# Routes and plugins live in devops/gateway/kong.yml (deployed by CI, no restart).

variable "name" { type = string }
variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "private_cidr" { type = string }
variable "private_route_table_id" { type = string }
variable "instance_type" { type = string }
variable "kong_image" { type = string }
variable "proxy_port" { type = number }
variable "artifacts_bucket" { type = string }
variable "artifacts_bucket_arn" { type = string }

data "aws_region" "current" {}

data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# CloudFront sends this header to Kong; Kong only routes requests that carry
# it, so other CloudFront distributions can't use this gateway.
resource "random_password" "origin_secret" {
  length  = 40
  special = false
}

# ---------- Network ----------
resource "aws_security_group" "gateway" {
  name        = "${var.name}-gateway"
  description = "Kong gateway: proxy port from CloudFront only; NAT for the private subnet"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "cloudfront" {
  security_group_id = aws_security_group.gateway.id
  description       = "Kong proxy from CloudFront edge locations"
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  ip_protocol       = "tcp"
  from_port         = var.proxy_port
  to_port           = var.proxy_port
}

resource "aws_vpc_security_group_ingress_rule" "nat" {
  security_group_id = aws_security_group.gateway.id
  description       = "Outbound traffic from the private subnet (NAT)"
  cidr_ipv4         = var.private_cidr
  ip_protocol       = "-1"
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.gateway.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# A standalone network interface keeps the Elastic IP and the private subnet's
# NAT route stable when the instance is replaced.
resource "aws_network_interface" "gateway" {
  subnet_id         = var.subnet_id
  security_groups   = [aws_security_group.gateway.id]
  source_dest_check = false # required to forward (NAT) traffic
  tags              = { Name = "${var.name}-gateway" }
}

resource "aws_eip" "gateway" {
  domain            = "vpc"
  network_interface = aws_network_interface.gateway.id
  tags              = { Name = "${var.name}-gateway" }
}

resource "aws_route" "private_default" {
  route_table_id         = var.private_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_network_interface.gateway.id
}

# ---------- IAM: SSM (deploys), CloudWatch Logs, read gateway config ----------
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "gateway" {
  name               = "${var.name}-gateway"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.gateway.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_cloudwatch_log_group" "kong" {
  name              = "/${var.name}/gateway"
  retention_in_days = 14
}

resource "aws_iam_role_policy" "gateway" {
  role = aws_iam_role.gateway.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = "${var.artifacts_bucket_arn}/gateway/*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.kong.arn}:*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "gateway" {
  name = "${var.name}-gateway"
  role = aws_iam_role.gateway.name
}

# ---------- Instance ----------
resource "aws_instance" "gateway" {
  ami                  = data.aws_ssm_parameter.al2023_arm64.insecure_value
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.gateway.name

  primary_network_interface {
    network_interface_id = aws_network_interface.gateway.id
  }

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 10
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    private_cidr = var.private_cidr
    kong_image   = var.kong_image
    proxy_port   = var.proxy_port
    bucket       = var.artifacts_bucket
    log_group    = aws_cloudwatch_log_group.kong.name
    region       = data.aws_region.current.region
  })

  tags = { Name = "${var.name}-gateway" }

  # Boot with the Elastic IP already attached, so NAT and image pulls work.
  depends_on = [aws_eip.gateway]

  lifecycle {
    ignore_changes = [ami]
  }
}

output "instance_id" { value = aws_instance.gateway.id }
output "security_group_id" { value = aws_security_group.gateway.id }
output "public_ip" { value = aws_eip.gateway.public_ip }
output "origin_domain" { value = aws_eip.gateway.public_dns }
output "origin_secret" {
  value     = random_password.origin_secret.result
  sensitive = true
}
