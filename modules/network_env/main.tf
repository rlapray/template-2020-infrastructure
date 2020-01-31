/*******************************************************************************
********** VPC
*******************************************************************************/

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "vpc-${var.environment}"
    Environment = var.environment
  }
}

/*******************************************************************************
********** Internet Gateway
*******************************************************************************/

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "igw-${var.environment}"
    Environment = var.environment
  }
}


resource "aws_eip" "nat_eip" {
  count      = var.enabled ? var.cheap_nat ? 1 : length(var.public_subnets_cidr) : 0
  vpc        = true
  depends_on = [aws_internet_gateway.ig]
  tags = {
    Name        = "eip-${var.environment}-${count.index + 1}"
    Environment = var.environment
  }
}


/*******************************************************************************
********** NAT
*******************************************************************************/

resource "aws_nat_gateway" "nat" {
  count         = var.enabled ? var.cheap_nat ? 1 : length(var.public_subnets_cidr) : 0
  allocation_id = element(aws_eip.nat_eip.*.id, count.index)
  subnet_id     = element(aws_subnet.public_subnet.*.id, count.index)
  depends_on    = [aws_internet_gateway.ig]

  tags = {
    Name        = "nat-${var.environment}-${count.index + 1}"
    Environment = var.environment
  }
}

/*******************************************************************************
********** Subnets
*******************************************************************************/

resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.public_subnets_cidr)
  cidr_block              = element(var.public_subnets_cidr, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = true

  tags = {
    Name        = "sub-public-${var.environment}-${element(var.availability_zones, count.index)}"
    Environment = var.environment
  }
}

resource "aws_subnet" "private_subnet" {
  vpc_id                  = aws_vpc.vpc.id
  count                   = length(var.private_subnets_cidr)
  cidr_block              = element(var.private_subnets_cidr, count.index)
  availability_zone       = element(var.availability_zones, count.index)
  map_public_ip_on_launch = false

  tags = {
    Name        = "sub-private-${var.environment}-${element(var.availability_zones, count.index)}"
    Environment = var.environment
  }
}

/*******************************************************************************
********** Routing
*******************************************************************************/

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id
  count  = length(var.private_subnets_cidr)

  tags = {
    Name        = "rt-private-${var.environment}-${count.index + 1}"
    Environment = var.environment
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "rt-public-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_route" "public_internet_gateway" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.ig.id
}

resource "aws_route" "private_nat_gateway" {
  count                  = var.enabled ? length(var.private_subnets_cidr) : 0
  route_table_id         = element(aws_route_table.private.*.id, count.index)
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.cheap_nat ? element(aws_nat_gateway.nat.*.id, 0) : element(aws_nat_gateway.nat.*.id, count.index)
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnets_cidr)
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(var.private_subnets_cidr)
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.private.*.id, count.index)
}

/*******************************************************************************
********** Security Groups
*******************************************************************************/

resource "aws_security_group" "default" {
  name        = "secgrp-default-${var.environment}"
  description = "Default security group to allow inbound/outbound from the VPC"
  vpc_id      = aws_vpc.vpc.id
  depends_on  = [aws_vpc.vpc]

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    self        = true
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    self        = "true"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "secgrp-default-${var.environment}"
    Environment = var.environment
  }
}