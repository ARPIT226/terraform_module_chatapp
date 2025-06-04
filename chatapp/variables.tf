variable "ami1" {
  type    = string
  default = "ami-027270e7956a6afc4"
}

variable "subnet1_id" {
  type    = string
  default = "subnet-07d40b71c7154203b"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "main" {
  description = "main vpc"
  type        = string
  default     = "10.0.0.0/16"
}

variable "default_ubuntu_ami" {
  description = "default ami id for ubuntu"
  type        = string
  default     = "ami-04da26f654d3383cf"
}

variable "subnets" {
  description = "2 public and 2 private subnets in main vpc"
  default = {
    public_1a = {
      cidr_block        = "10.0.1.0/24"
      availability_zone = "eu-west-2a"
    }
    public_1b = {
      cidr_block        = "10.0.2.0/24"
      availability_zone = "eu-west-2b"
    }
    private_1a = {
      cidr_block        = "10.0.3.0/24"
      availability_zone = "eu-west-2a"
    }
    private_1b = {
      cidr_block        = "10.0.4.0/24"
      availability_zone = "eu-west-2b"
    }
  }
}
