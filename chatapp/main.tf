terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "eu-west-2"
}

module "vpc" {
  source = "./vpc"
  main   = var.main
  subnets = var.subnets
}

module "security_group" {
  source = "./security_group"
  vpc_id = module.vpc.vpc_id
}

module "ec2" {
  source              = "./ec2"
  default_ubuntu_ami  = var.default_ubuntu_ami
  instance_type       = var.instance_type
  subnets             = module.vpc.subnet_ids
  key_name            = module.ec2.key_name
  security_group_ids  = module.security_group.security_group_ids
  vpc_id              = module.vpc.vpc_id
  public_subnet_id    = module.vpc.public_subnet_ids[1]
  private_subnet_id   = module.vpc.private_subnet_ids[1]
}
