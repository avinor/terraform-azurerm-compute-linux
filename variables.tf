variable "name" {
  description = "Name of the spoke virtual network."
}

variable "environment" {
  description = "Environment to create (prod, test, dev)"
}

variable "location" {
  description = "The Azure Region in which to create resource."
}

variable "subnet_name" {
  description = "Subnet name where to create vm."
}

variable "count" {
  description = "Number of machines to create."
  default     = 1
}

variable "accelerated_network" {
  description = "Enable accelerated networking, limits selection of vm sku available"
  default     = true
}

variable "sku" {
  description = "Sku of VM."
  default     = "Standard_DS2_v2"
}

variable "storage_account_type" {
  description = "The type of strorage to use for managed disk. Allowable values are Standard_LRS, Premium_LRS, StandardSSD_LRS or UltraSSD_LRS."
  default     = "Standard_LRS"
}

variable "data_disks" {
  description = "List of data disks to attach."
  type        = "list"
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources created."
  type        = "map"
  default     = {}
}
