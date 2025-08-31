terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  required_version = ">= 1.5.0"
}

provider "aws" {
  region = var.region
}

# VPC
resource "aws_vpc" "production_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "Production-VPC"
  })
}

# Subnets
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.production_vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = var.az
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "Public-Subnet-1"
  })
}

resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.production_vpc.id
  cidr_block        = var.private_subnet_cidr
  availability_zone = var.az

  tags = merge(var.tags, {
    Name = "Private-Subnet-1"
  })
}

# Route tables
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.production_vpc.id

  tags = merge(var.tags, {
    Name = "Public-Route-Table"
  })
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.production_vpc.id

  tags = merge(var.tags, {
    Name = "Private-Route-Table"
  })
}

# Associations
resource "aws_route_table_association" "public_subnet_association" {
  route_table_id = aws_route_table.public_route_table.id
  subnet_id      = aws_subnet.public_subnet.id
}

resource "aws_route_table_association" "private_subnet_association" {
  route_table_id = aws_route_table.private_route_table.id
  subnet_id      = aws_subnet.private_subnet.id
}

# Internet Gateway
resource "aws_internet_gateway" "production_igw" {
  vpc_id = aws_vpc.production_vpc.id

  tags = merge(var.tags, {
    Name = "Production-IGW"
  })
}

# Public route to Internet
resource "aws_route" "public_internet_gw_route" {
  route_table_id         = aws_route_table.public_route_table.id
  gateway_id             = aws_internet_gateway.production_igw.id
  destination_cidr_block = "0.0.0.0/0"
}

# NAT for private subnet egress
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = merge(var.tags, {
    Name = "Production-EIP"
  })
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet.id

  tags = merge(var.tags, {
    Name = "Production-NAT-GW"
  })

  depends_on = [aws_internet_gateway.production_igw]
}

resource "aws_route" "nat_gw_route" {
  route_table_id         = aws_route_table.private_route_table.id
  nat_gateway_id         = aws_nat_gateway.nat_gw.id
  destination_cidr_block = "0.0.0.0/0"
}
