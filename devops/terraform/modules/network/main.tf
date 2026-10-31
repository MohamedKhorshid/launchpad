# Minimal VPC: two public subnets (gateway) + one private subnet (backend).
# No NAT gateway (saves ~$35/month): the Kong gateway instance also does NAT
# for the private subnet (its route is added by modules/gateway). S3 traffic
# from the private subnet uses a free gateway endpoint instead.

variable "name" { type = string }
variable "vpc_cidr" { type = string }

data "aws_availability_zones" "azs" { state = "available" }
data "aws_region" "current" {}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = var.name }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = var.name }
}

# ---------- Public: the gateway (only internet-facing instance) ----------
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.this.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.azs.names[count.index]
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.name}-public-${count.index}" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }
  tags = { Name = "${var.name}-public" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# ---------- Private: the backend (no public IP, no inbound from the internet) ----------
resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 10)
  availability_zone = data.aws_availability_zones.azs.names[0]
  tags              = { Name = "${var.name}-private" }
}

# The default route (0.0.0.0/0 -> gateway instance) lives in modules/gateway.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id
  tags   = { Name = "${var.name}-private" }
}

resource "aws_route_table_association" "private" {
  subnet_id      = aws_subnet.private.id
  route_table_id = aws_route_table.private.id
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.this.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
  tags              = { Name = "${var.name}-s3" }
}

output "vpc_id" { value = aws_vpc.this.id }
output "public_subnet_ids" { value = aws_subnet.public[*].id }
output "private_subnet_id" { value = aws_subnet.private.id }
output "private_subnet_cidr" { value = aws_subnet.private.cidr_block }
output "private_route_table_id" { value = aws_route_table.private.id }
