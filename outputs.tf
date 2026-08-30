output "load_balancer_ip" {
  value       = azurerm_public_ip.web_public_ip.ip_address
  description = "Public Load Balancer IP to view the web app"
}