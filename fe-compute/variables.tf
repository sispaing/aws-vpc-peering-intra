variable "region" {
  description = "The region where the resources are created."
  default     = "ap-southeast-1"
}

variable "frontend_prefix" {
  description = "The prefix for the frontend resources."
  default     = "frontend"
}

variable "frontend_environment" {
  description = "The environment for the frontend resources."
  default     = "dev"
}

variable "fe_instance_type" {
  description = "Specifies the AWS instance type."
  default     = "t2.micro"
}

variable "tfc_organization" {
  description = "HCP Terraform organization (used to read other workspaces' outputs)."
  default     = "nickcloud4t-master"
}

variable "fe_network_workspace" {
  default = "fe-network-ws"
}

variable "fe_security_workspace" {
  default = "fe-security-ws"
}

#############################################################
# App Variables
#############################################################

variable "fe_placeholder" {
  default     = "placedog.net"
  description = "Image-as-a-service URL, e.g. placedog.net, placebear.com, loremflickr.com"
}

variable "placeholder_id" {
  default     = "2"
  description = "Image id passed to the placeholder service."
}

variable "width" {
  default     = "600"
  description = "Image width in pixels."
}

variable "height" {
  default     = "400"
  description = "Image height in pixels."
}
