# The Go modular monolith on one EC2 instance, managed by systemd.
# Deploys: CI uploads a binary to the artifacts bucket, then runs
# /opt/app/deploy.sh on the instance through SSM (no SSH, no open ports).

variable "name" { type = string }
variable "env" { type = string }
variable "vpc_id" { type = string }
variable "subnet_id" { type = string }
variable "instance_type" { type = string }
variable "app_port" { type = number }
variable "allowed_from" {
  type        = map(string)
  description = "Security groups allowed to reach the app port, as { static_name = sg_id }. Keys must be static so for_each works when the ids are only known after apply."
}
variable "cors_origins" { type = list(string) }

data "aws_ssm_parameter" "al2023_arm64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-arm64"
}

# ---------- Artifacts bucket (backend binaries) ----------
resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "${var.name}-artifacts-"
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id
  rule {
    id     = "expire-old-builds"
    status = "Enabled"
    filter { prefix = "backend/builds/" }
    expiration { days = 30 }
  }
}

# ---------- IAM: SSM access + read artifacts ----------
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name               = "${var.name}-backend"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy" "artifacts_read" {
  role = aws_iam_role.instance.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = "${aws_s3_bucket.artifacts.arn}/backend/*"
    }]
  })
}

resource "aws_iam_instance_profile" "instance" {
  name = "${var.name}-backend"
  role = aws_iam_role.instance.name
}

# ---------- Network ----------
resource "aws_security_group" "instance" {
  name        = "${var.name}-backend"
  description = "Go backend: app port from API Gateway VPC link only"
  vpc_id      = var.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "app" {
  for_each                     = var.allowed_from
  security_group_id            = aws_security_group.instance.id
  referenced_security_group_id = each.value
  ip_protocol                  = "tcp"
  from_port                    = var.app_port
  to_port                      = var.app_port
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.instance.id
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------- Instance ----------
resource "aws_instance" "app" {
  ami                    = data.aws_ssm_parameter.al2023_arm64.insecure_value
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.instance.id]
  iam_instance_profile   = aws_iam_instance_profile.instance.name

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  user_data = templatefile("${path.module}/user_data.sh.tftpl", {
    env          = var.env
    port         = var.app_port
    bucket       = aws_s3_bucket.artifacts.bucket
    cors_origins = join(",", var.cors_origins)
  })

  tags = { Name = "${var.name}-backend" }

  lifecycle {
    # New AMI releases should not replace the box on every apply.
    ignore_changes = [ami]
  }
}

# ---------- Cloud Map (lets API Gateway find the instance via VPC link) ----------
resource "aws_service_discovery_private_dns_namespace" "this" {
  name = "${var.name}.internal"
  vpc  = var.vpc_id
}

resource "aws_service_discovery_service" "backend" {
  name = "backend"
  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.this.id
    dns_records {
      type = "SRV"
      ttl  = 10
    }
    routing_policy = "MULTIVALUE"
  }
}

resource "aws_service_discovery_instance" "app" {
  instance_id = aws_instance.app.id
  service_id  = aws_service_discovery_service.backend.id
  attributes = {
    AWS_INSTANCE_IPV4 = aws_instance.app.private_ip
    AWS_INSTANCE_PORT = tostring(var.app_port)
  }
}

output "cloudmap_service_arn" { value = aws_service_discovery_service.backend.arn }
output "artifacts_bucket" { value = aws_s3_bucket.artifacts.bucket }
output "instance_id" { value = aws_instance.app.id }
