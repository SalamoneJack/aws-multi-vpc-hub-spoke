data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ── Helper: creates a VPC, IGW, public subnet, and route table ──────────────

locals {
  vpcs = {
    shared = { cidr = var.shared_cidr, az_suffix = "a" }
    prod   = { cidr = var.prod_cidr, az_suffix = "a" }
    dev    = { cidr = var.dev_cidr, az_suffix = "a" }
  }
}

# ── Shared-Services VPC (hub) ────────────────────────────────────────────────

resource "aws_vpc" "shared" {
  cidr_block           = var.shared_cidr
  enable_dns_hostnames = true
  tags                 = { Name = "hub-spoke-shared" }
}

resource "aws_internet_gateway" "shared" {
  vpc_id = aws_vpc.shared.id
  tags   = { Name = "hub-spoke-shared-igw" }
}

resource "aws_subnet" "shared" {
  vpc_id            = aws_vpc.shared.id
  cidr_block        = cidrsubnet(var.shared_cidr, 8, 1)
  availability_zone = "${var.region}a"
  tags              = { Name = "hub-spoke-shared-subnet" }
}

resource "aws_route_table" "shared" {
  vpc_id = aws_vpc.shared.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.shared.id
  }

  route {
    cidr_block                = var.prod_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.shared_prod.id
  }

  route {
    cidr_block                = var.dev_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.shared_dev.id
  }

  tags = { Name = "hub-spoke-shared-rt" }
}

resource "aws_route_table_association" "shared" {
  subnet_id      = aws_subnet.shared.id
  route_table_id = aws_route_table.shared.id
}

# ── Prod VPC (spoke) ─────────────────────────────────────────────────────────

resource "aws_vpc" "prod" {
  cidr_block           = var.prod_cidr
  enable_dns_hostnames = true
  tags                 = { Name = "hub-spoke-prod" }
}

resource "aws_internet_gateway" "prod" {
  vpc_id = aws_vpc.prod.id
  tags   = { Name = "hub-spoke-prod-igw" }
}

resource "aws_subnet" "prod" {
  vpc_id            = aws_vpc.prod.id
  cidr_block        = cidrsubnet(var.prod_cidr, 8, 1)
  availability_zone = "${var.region}a"
  tags              = { Name = "hub-spoke-prod-subnet" }
}

resource "aws_route_table" "prod" {
  vpc_id = aws_vpc.prod.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.prod.id
  }

  # Prod can reach shared-services — cannot reach dev (no route, no peering)
  route {
    cidr_block                = var.shared_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.shared_prod.id
  }

  tags = { Name = "hub-spoke-prod-rt" }
}

resource "aws_route_table_association" "prod" {
  subnet_id      = aws_subnet.prod.id
  route_table_id = aws_route_table.prod.id
}

# ── Dev VPC (spoke) ──────────────────────────────────────────────────────────

resource "aws_vpc" "dev" {
  cidr_block           = var.dev_cidr
  enable_dns_hostnames = true
  tags                 = { Name = "hub-spoke-dev" }
}

resource "aws_internet_gateway" "dev" {
  vpc_id = aws_vpc.dev.id
  tags   = { Name = "hub-spoke-dev-igw" }
}

resource "aws_subnet" "dev" {
  vpc_id            = aws_vpc.dev.id
  cidr_block        = cidrsubnet(var.dev_cidr, 8, 1)
  availability_zone = "${var.region}a"
  tags              = { Name = "hub-spoke-dev-subnet" }
}

resource "aws_route_table" "dev" {
  vpc_id = aws_vpc.dev.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dev.id
  }

  # Dev can reach shared-services — cannot reach prod (no route, no peering)
  route {
    cidr_block                = var.shared_cidr
    vpc_peering_connection_id = aws_vpc_peering_connection.shared_dev.id
  }

  tags = { Name = "hub-spoke-dev-rt" }
}

resource "aws_route_table_association" "dev" {
  subnet_id      = aws_subnet.dev.id
  route_table_id = aws_route_table.dev.id
}

# ── VPC Peering: shared ↔ prod ───────────────────────────────────────────────

resource "aws_vpc_peering_connection" "shared_prod" {
  vpc_id      = aws_vpc.shared.id
  peer_vpc_id = aws_vpc.prod.id
  auto_accept = true
  tags        = { Name = "hub-spoke-shared-prod-peering" }
}

# ── VPC Peering: shared ↔ dev ────────────────────────────────────────────────

resource "aws_vpc_peering_connection" "shared_dev" {
  vpc_id      = aws_vpc.shared.id
  peer_vpc_id = aws_vpc.dev.id
  auto_accept = true
  tags        = { Name = "hub-spoke-shared-dev-peering" }
}

# NOTE: No prod ↔ dev peering — this is intentional. The absence of a peering
# connection is the security control. Non-transitive peering means prod→shared
# and dev→shared exist, but prod→shared→dev is blocked by AWS.

# ── Security Groups ──────────────────────────────────────────────────────────

resource "aws_security_group" "shared_test" {
  name        = "hub-spoke-shared-test-sg"
  description = "Allow ICMP from prod and dev for connectivity testing"
  vpc_id      = aws_vpc.shared.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.prod_cidr, var.dev_cidr, var.shared_cidr]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "hub-spoke-shared-test-sg" }
}

resource "aws_security_group" "prod_test" {
  name        = "hub-spoke-prod-test-sg"
  description = "Allow ICMP from shared only (not dev)"
  vpc_id      = aws_vpc.prod.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.shared_cidr, var.prod_cidr]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "hub-spoke-prod-test-sg" }
}

resource "aws_security_group" "dev_test" {
  name        = "hub-spoke-dev-test-sg"
  description = "Allow ICMP from shared only (not prod)"
  vpc_id      = aws_vpc.dev.id

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = [var.shared_cidr, var.dev_cidr]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "hub-spoke-dev-test-sg" }
}

# ── Test EC2 Instances ────────────────────────────────────────────────────────

resource "aws_instance" "shared_test" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_pair
  subnet_id                   = aws_subnet.shared.id
  vpc_security_group_ids      = [aws_security_group.shared_test.id]
  associate_public_ip_address = true
  tags                        = { Name = "hub-spoke-shared-test" }
}

resource "aws_instance" "prod_test" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_pair
  subnet_id                   = aws_subnet.prod.id
  vpc_security_group_ids      = [aws_security_group.prod_test.id]
  associate_public_ip_address = true
  tags                        = { Name = "hub-spoke-prod-test" }
}

resource "aws_instance" "dev_test" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  key_name                    = var.key_pair
  subnet_id                   = aws_subnet.dev.id
  vpc_security_group_ids      = [aws_security_group.dev_test.id]
  associate_public_ip_address = true
  tags                        = { Name = "hub-spoke-dev-test" }
}
