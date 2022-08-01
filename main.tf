module "identities" {
  source = "https://github.com/patrickhayo/azr-tf-module-identity"
}

module "privatednszone" {
  source = "https://github.com/patrickhayo/azr-tf-module-private-dns-zone"
}

module "vnet" {
  source = "https://github.com/patrickhayo/azr-tf-module-vnet"
}

module "vnet-data" {
  source = "https://github.com/patrickhayo/azr-tf-data-module-vnet"
}

module "subnet" {
  source = "https://github.com/patrickhayo/azr-tf-module-subnet"
}

module "rt" {
  source = "https://github.com/patrickhayo/azr-tf-module-route-table"
}

module "nat" {
  source = "https://github.com/patrickhayo/azr-tf-module-nat-gateway"
}

module "nsg" {
  source = "https://github.com/patrickhayo/azr-tf-module-nsg"
}

module "log" {
  source = "https://github.com/patrickhayo/azr-tf-module-log-analytics-workspace"
}

module "privateendpoint" {
  source = "https://github.com/patrickhayo/azr-tf-module-private-endpoint"
}

module "bastionhost" {
  source = "https://github.com/patrickhayo/azr-tf-module-bastion-host"
}

module "firewall" {
  source = "https://github.com/patrickhayo/azr-tf-module-firewall"
}

module "keyvault" {
  source = "https://github.com/patrickhayo/azr-tf-module-keyvault"
}

module "akscluster" {
  source = "https://github.com/patrickhayo/azr-tf-module-aks-cluster"
}

module "aksnodepool" {
  source = "https://github.com/patrickhayo/azr-tf-module-aks-node-pool"
}
