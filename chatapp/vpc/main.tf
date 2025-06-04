resource "aws_vpc" "main" {
  cidr_block = var.main
  tags = { Name = "vpc_tf" }
}

resource "aws_subnet" "subnets" {
  for_each = var.subnets
  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = contains(["public_1a", "public_1b"], each.key) ? true : false
  tags = { Name = "${each.key}_tf" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "my-igw_tf" }
}

resource "aws_eip" "eip" {
  vpc = true
  tags = { Name = "nat_eip_tf" }
}

resource "aws_nat_gateway" "nat" {
  subnet_id     = aws_subnet.subnets["public_1a"].id
  allocation_id = aws_eip.eip.id
  tags = { Name = "my-nat_tf" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public_rt_tf" }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat.id
  }
  tags = { Name = "private_rt_tf" }
}

resource "aws_route_table_association" "public-rta" {
  for_each = {
    public_1a = aws_subnet.subnets["public_1a"].id
    public_1b = aws_subnet.subnets["public_1b"].id
  }
  subnet_id      = each.value
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private-rta" {
  for_each = {
    private_1a = aws_subnet.subnets["private_1a"].id
    private_1b = aws_subnet.subnets["private_1b"].id
  }
  subnet_id      = each.value
  route_table_id = aws_route_table.private_rt.id
}
