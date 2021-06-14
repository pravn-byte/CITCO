##############################################################################
# Variables File
#
# Here is where we store the default values for all the variables used in our
# Terraform code. If you create a variable with no default, the user will be
# prompted to enter it (or define it via config file or command line flags.)
##############################################################################
variable "prefix" {
  description = "This prefix will be included in the name of most resources."
  default = "dev"
}

variable "region" {
  description = "The region where the resources are created."
  default = "us-east-1"
}

variable "address_space" {
  description = "The address space that is used by the virtual network. You can supply more than one address space. Changing this forces a new resource to be created."
  default     = "10.10.0.0/20"
}

variable "public_subnet" {
  type        = list
  description = "The address space to use for the public subnet."
  default     = ["10.10.1.0/24", "10.10.2.0/24"]
}

variable "instance_type" {
  description = "Specifies the AWS instance type."
  default     = "t2.micro"
}

variable "availability_zones" {
  type = list
  description = "AWS Region Availability Zones"
  default = ["us-east-1a", "us-east-1b"]
}
