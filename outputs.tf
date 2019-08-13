output "ids" {
  value = "${azurerm_virtual_machine.main.*.id}"
}
