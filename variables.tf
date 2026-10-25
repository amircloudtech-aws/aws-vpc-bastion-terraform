variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "project" {
  description = "Name prefix for all resources"
  type        = string
  default     = "claude-tf"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "One public subnet CIDR per AZ"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "One private subnet CIDR per AZ"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

variable "my_ip" {
  description = "Your public IP in CIDR form, e.g. 84.148.189.152/32"
  type        = string

  validation {
    condition     = can(cidrhost(var.my_ip, 0)) && endswith(var.my_ip, "/32")
    error_message = "my_ip must be a single IP ending in /32."
  }
}

variable "key_name" {
  description = "Name of an EXISTING EC2 key pair in this region"
  type        = string
  default     = "Claude-bastion-ec2"
}

variable "instance_type" {
  description = "Bastion instance type"
  type        = string
  default     = "t3.micro"
}

variable "enable_nat" {
  description = "Create a NAT Gateway (costs money hourly)"
  type        = bool
  default     = false
}
