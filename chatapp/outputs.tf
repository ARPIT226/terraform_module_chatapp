output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vpc.private_subnet_ids
}

output "nginx_public_ip" {
  value = module.ec2.nginx_public_ip
}

output "backend_private_ip" {
  value = module.ec2.backend_private_ip
}

output "mysql_private_ip" {
  value = module.ec2.mysql_private_ip
}
