variable "region" {
  description = "The region where the resources are created."
  default     = "ap-southeast-1"
}

variable "backend_prefix" {
  description = "The prefix for the backend resources."
  default     = "backend"
}

variable "tfc_organization" {
  description = "HCP Terraform organization (used to read other workspaces' outputs)."
  default     = "nickcloud4t-master"
}

variable "be_network_workspace" {
  default = "be-network-ws"
}

variable "fe_security_workspace" {
  default = "fe-security-ws"
}
