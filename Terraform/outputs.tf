output "bastion_public_ip" {
  value = yandex_compute_instance.bastion.network_interface[0].nat_ip_address
}

output "alb_public_ip" {
  value = yandex_alb_load_balancer.web.listener[0].endpoint[0].address[0].external_ipv4_address[0].address
}

output "zabbix_url" {
  value = "http://${yandex_compute_instance.zabbix.network_interface[0].nat_ip_address}"
}

output "kibana_url" {
  value = "http://${yandex_compute_instance.kibana.network_interface[0].nat_ip_address}:5601"
}

output "web_servers_private_ips" {
  value = yandex_compute_instance.webserver[*].network_interface[0].ip_address
}
