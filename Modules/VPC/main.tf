# -------------------------------
# VPC: Main Virtual Private Cloud
# -------------------------------
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr                 # CIDR range for the VPC
  enable_dns_hostnames = true                         # Enable DNS hostnames for instances
  enable_dns_support   = true                         # Enable DNS resolution inside the VPC

  tags = {
    Name                                        = "${var.cluster_name}-vpc"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared" # Tag for EKS cluster discovery
  }
}

# -------------------------------
# Private Subnets
# -------------------------------
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)       # Create one subnet per CIDR provided
  vpc_id            = aws_vpc.main.id                        # Attach to the main VPC
  cidr_block        = var.private_subnet_cidrs[count.index]  # Subnet CIDR
  availability_zone = var.availability_zones[count.index]    # Place in specific AZ

  tags = {
    Name                                        = "${var.cluster_name}-private-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"   # Required for EKS
    "kubernetes.io/role/internal-elb"           = "1"        # Marks subnet for internal load balancers
  }
}

# -------------------------------
# Public Subnets
# -------------------------------
resource "aws_subnet" "public" {
  count             = length(var.public_subnet_cidrs)        # Create one subnet per CIDR provided
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]

  map_public_ip_on_launch = true                             # Auto-assign public IPs to instances

  tags = {
    Name                                        = "${var.cluster_name}-public-${count.index + 1}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"        # Marks subnet for public load balancers
  }
}

# -------------------------------
# Internet Gateway
# -------------------------------
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id   # Attach IGW to the VPC

  tags = {
    Name = "${var.cluster_name}-igw"
  }
}

# -------------------------------
# Elastic IPs for NAT Gateways
# -------------------------------
resource "aws_eip" "nat" {
  count  = length(var.public_subnet_cidrs)   # One EIP per public subnet
  domain = "vpc"

  tags = {
    Name = "${var.cluster_name}-nat-${count.index + 1}"
  }
}

# -------------------------------
# NAT Gateways
# -------------------------------
resource "aws_nat_gateway" "main" {
  count         = length(var.public_subnet_cidrs)   # One NAT per public subnet
  allocation_id = aws_eip.nat[count.index].id       # Attach Elastic IP
  subnet_id     = aws_subnet.public[count.index].id # Place NAT in public subnet

  tags = {
    Name = "${var.cluster_name}-nat-${count.index + 1}"
  }
}

# -------------------------------
# Public Route Table
# -------------------------------
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"                # Default route to the internet
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.cluster_name}-public"
  }
}

# -------------------------------
# Private Route Tables
# -------------------------------
resource "aws_route_table" "private" {
  count  = length(var.private_subnet_cidrs) # One route table per private subnet
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"                  # Default route to internet
    nat_gateway_id = aws_nat_gateway.main[count.index].id # Use NAT gateway for outbound traffic
  }

  tags = {
    Name = "${var.cluster_name}-private-${count.index + 1}"
  }
}

# -------------------------------
# Route Table Associations
# -------------------------------
resource "aws_route_table_association" "private" {
  count          = length(var.private_subnet_cidrs)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_route_table_association" "public" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
