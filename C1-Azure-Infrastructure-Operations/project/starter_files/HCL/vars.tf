variable "prefix" {
  description = "The prefix which should be used for all resources in this example"
}

variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default     = "East US"
}

variable "resource_group_name" {
  description = "Existing Azure Resource Group name"
}

variable "admin_username" {
  description = "The admin username for the VM being created."
}

variable "admin_password" {
  description = "The password for the VM being created."
}

variable "vm_count" {
  description = "Number of virtual machines to deploy"
  type        = number
  default     = 2
}