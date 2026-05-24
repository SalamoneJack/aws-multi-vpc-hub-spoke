variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "key_pair" {
  description = "Name of an existing EC2 key pair for SSH access"
  type        = string
}

variable "shared_cidr" {
  description = "CIDR block for the shared-services (hub) VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "prod_cidr" {
  description = "CIDR block for the prod (spoke) VPC"
  type        = string
  default     = "10.10.0.0/16"
}

variable "dev_cidr" {
  description = "CIDR block for the dev (spoke) VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "instance_type" {
  description = "EC2 instance type for test instances"
  type        = string
  default     = "t2.micro"
}
