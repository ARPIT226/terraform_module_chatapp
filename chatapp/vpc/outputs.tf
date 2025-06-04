output "vpc_id" {
  value = aws_vpc.main.id
}

output "subnet_ids" {
  value = { for k, s in aws_subnet.subnets : k => s.id }
}

output "public_subnet_ids" {
  value = [
    aws_subnet.subnets["public_1a"].id,
    aws_subnet.subnets["public_1b"].id
  ]
}

output "private_subnet_ids" {
  value = [
    aws_subnet.subnets["private_1a"].id,
    aws_subnet.subnets["private_1b"].id
  ]
}
