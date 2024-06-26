# Data source to get available availability zones
data "aws_availability_zones" "available" {
  state    = "available"
  provider = aws.default
}

resource "aws_vpc" "this_vpc" {
  provider             = aws.default
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Type = "this_vpc"
    Name = "${var.project_name}-vpc"
  }
}

# Conditionally create public subnets
resource "aws_subnet" "public_subnet" {
  provider                = aws.default
  count                   = length(var.public_subnet_cidrs) > 0 ? length(var.public_subnet_cidrs) : 0
  vpc_id                  = aws_vpc.this_vpc.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = element(data.aws_availability_zones.available.names, count.index % length(data.aws_availability_zones.available.names))
  map_public_ip_on_launch = true

  tags = {
    Type = "public_subnet"
    Name = "${var.project_name}-public-subnet-${count.index + 1}"
  }
}

# Conditionally create private subnets
resource "aws_subnet" "private_subnet" {
  provider          = aws.default
  count             = length(var.private_subnet_cidrs) > 0 ? length(var.private_subnet_cidrs) : 0
  vpc_id            = aws_vpc.this_vpc.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = element(data.aws_availability_zones.available.names, count.index % length(data.aws_availability_zones.available.names))
  tags = {
    Type = "private_subnet"
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

resource "aws_internet_gateway" "this_vpc_igw" {
  provider = aws.default
  count    = length(var.public_subnet_cidrs) > 0 ? 1 : 0
  vpc_id   = aws_vpc.this_vpc.id

  tags = {
    Type = "this_igw"
    Name = "${var.project_name}-igw"
  }
}

resource "aws_nat_gateway" "this_nat_gateway" {
  provider      = aws.default
  count         = length(var.private_subnet_cidrs) > 0 ? 1 : 0
  allocation_id = aws_eip.this_eip[0].id
  subnet_id     = element(aws_subnet.public_subnet.*.id, 0)

  tags = {
    Type = "this_nat_gateway"
    Name = "${var.project_name}-nat-gateway"
  }
}

resource "aws_eip" "this_eip" {
  provider = aws.default
  count    = length(var.private_subnet_cidrs) > 0 ? 1 : 0
  domain   = "vpc"

  tags = {
    Type = "this_eip"
    Name = "${var.project_name}-eip"
  }
}

resource "aws_route_table" "private_route_table" {
  provider = aws.default
  count    = length(var.private_subnet_cidrs) > 0 ? 1 : 0
  vpc_id   = aws_vpc.this_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this_nat_gateway[0].id
  }

  tags = {
    Type = "private_route_table"
    Name = "${var.project_name}-private-route-table"
  }
}

resource "aws_route_table_association" "private_route_table_association" {
  provider       = aws.default
  count          = length(var.private_subnet_cidrs) > 0 ? length(var.private_subnet_cidrs) : 0
  subnet_id      = element(aws_subnet.private_subnet.*.id, count.index)
  route_table_id = aws_route_table.private_route_table[0].id
}

resource "aws_route_table" "public_route_table" {
  provider = aws.default
  count    = length(var.public_subnet_cidrs) > 0 ? 1 : 0
  vpc_id   = aws_vpc.this_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this_vpc_igw[0].id
  }

  tags = {
    Type = "public_route_table"
    Name = "${var.project_name}-public-route-table"
  }
}

resource "aws_route_table_association" "public_route_table_association" {
  provider       = aws.default
  count          = length(var.public_subnet_cidrs) > 0 ? length(var.public_subnet_cidrs) : 0
  subnet_id      = element(aws_subnet.public_subnet.*.id, count.index)
  route_table_id = element(aws_route_table.public_route_table.*.id, count.index)
}
