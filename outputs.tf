output "load_balancer_ip" {
  value       = azurerm_public_ip.web_public_ip.ip_address
  description = "Public Load Balancer IP to view the web app"
}

output "vm1_ssh_command" {
  value       = "ssh -i ~/.ssh/id_rsa adminuser@${azurerm_public_ip.web_vm_public_ip[0].ip_address}"
  description = "SSH into VM 1 (Zone 1)"
}

output "vm2_ssh_command" {
  value       = "ssh -i ~/.ssh/id_rsa adminuser@${azurerm_public_ip.web_vm_public_ip[1].ip_address}"
  description = "SSH into VM 2 (Zone 2)"
}