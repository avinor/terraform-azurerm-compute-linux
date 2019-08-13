provider "azurerm" {}

terraform {
  backend "azurerm" {}
}

locals {
  zones = [1, 2, 3]
}

resource "random_integer" "zone" {
  min = 0
  max = 2
}

resource "azurerm_resource_group" "main" {
  name     = "${var.name}-rg"
  location = "${var.location}"
}

resource "azurerm_managed_disk" "data" {
  count                = "${var.count * length(var.data_disks)}"
  name                 = "${var.name}${count.index / var.count}osdisk1"
  location             = "${azurerm_resource_group.main.location}"
  resource_group_name  = "${azurerm_resource_group.main.name}"
  storage_account_type = "${var.storage_account_type}"
  create_option        = "Empty"
  disk_size_gb         = "30"
  zones                = ["${element(local.zones, random_integer.zone.result + count.index % 3)}"]

  encryption_settings {
    enabled = false
  }

  tags = "${var.tags}"
}

resource "azurerm_network_interface" "main" {
  count                         = "${var.count}"
  name                          = "${var.name}${count.index}-nic"
  location                      = "${azurerm_resource_group.main.location}"
  resource_group_name           = "${azurerm_resource_group.main.name}"
  enable_accelerated_networking = "${var.accelerated_network}"

  ip_configuration {
    name                          = "${var.name}-ip-config"
    subnet_id                     = "${data.terraform_remote_state.networking.subnets[var.subnet_name]}"
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_monitor_diagnostic_setting" "nic" {
  count                      = "${var.count}"
  name                       = "${var.name}${count.index}-nic-log-analytics"
  target_resource_id         = "${element(azurerm_network_interface.main.*.id, count.index)}"
  log_analytics_workspace_id = "${data.terraform_remote_state.setup.log_resource_id}"

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }
}

resource "azurerm_virtual_machine" "main" {
  count                 = "${var.count}"
  name                  = "${var.name}${count.index}-vm"
  location              = "${azurerm_resource_group.main.location}"
  resource_group_name   = "${azurerm_resource_group.main.name}"
  network_interface_ids = ["${azurerm_network_interface.main.*.id}"]
  vm_size               = "${var.sku}"

  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true

  zones = ["${element(local.zones, random_integer.zone.result + count.index % 3)}"]

  boot_diagnostics {
    enabled     = true
    storage_uri = "${data.terraform_remote_state.setup.boot_storage_account_uri}"
  }

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }

  storage_os_disk {
    name              = "${var.name}${count.index}osdisk1"
    create_option     = "FromImage"
    caching           = "ReadWrite"
    managed_disk_type = "${var.storage_account_type}"
  }

  os_profile {
    computer_name  = "${var.name}${count.index}"
    admin_username = "admin"
  }

  os_profile_linux_config {
    ssh_keys = {
      key_data = "${data.terraform_remote_state.setup.ssh_key}"
      path     = "/home/admin/.ssh/authorized_keys"
    }

    disable_password_authentication = true
  }

  tags = "${var.tags}"
}

resource "azurerm_virtual_machine_extension" "login" {
  count                      = "${var.count}"
  name                       = "AADLoginForLinux"
  location                   = "${azurerm_resource_group.main.location}"
  resource_group_name        = "${azurerm_resource_group.main.name}"
  virtual_machine_name       = "${element(azurerm_virtual_machine.main.*.name, count.index)}"
  publisher                  = "Microsoft.Azure.ActiveDirectory.LinuxSSH"
  type                       = "AADLoginForLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true

  tags = "${var.tags}"
}

# Encrypt OS disk. Have to be done after installation


# resource "azurerm_virtual_machine_extension" "diskencrypt" {
#   count                      = "${var.count}"
#   name                       = "AzureDiskEncryptionForLinux"
#   location                   = "${azurerm_resource_group.main.location}"
#   resource_group_name        = "${azurerm_resource_group.main.name}"
#   virtual_machine_name       = "${element(azurerm_virtual_machine.main.*.name, count.index)}"
#   publisher                  = "Microsoft.Azure.Security"
#   type                       = "AzureDiskEncryptionForLinux"
#   type_handler_version       = "1.1"
#   auto_upgrade_minor_version = true


#   settings = <<SETTINGS
#     {
#         "EncryptionOperation": "EnableEncryption",
#         "KeyVaultURL": "${data.terraform_remote_state.setup.vault_uri}",
#         "KeyVaultResourceId": "${data.terraform_remote_state.setup.vault_id}",
#         "KeyEncryptionKeyURL": "${data.terraform_remote_state.setup.disk_encrypt_key_id}",
#         "KekVaultResourceId": "${data.terraform_remote_state.setup.vault_id}",
#         "KeyEncryptionAlgorithm": "RSA-OAEP",
#         "VolumeType": "All"
#     }
# SETTINGS


#   tags = "${var.tags}"
# }

