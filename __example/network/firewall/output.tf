output "privatednszone" {
  value = module.privatednszone
}
output "firewall" {
  value = module.firewall
}

output "basion" {
  value = module.bastion_host
}

output "network" {
  value = module.network
}

output "route_tables" {
  value = module.rt
}

output "nsgs" {
  value = module.nsg
}
