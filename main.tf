module "identities" {
  source = "https://github.com/patrickhayo/azr-tf-module-identity"
}

module "privatednszone" {
  source = "https://github.com/patrickhayo/azr-tf-module-private-dns-zone"
}

module "vnet" {
  source = "https://github.com/patrickhayo/azr-tf-module-vnet"
}

module "rt" {
  source = "https://github.com/patrickhayo/azr-tf-module-route-table"
}

module "nat" {
  source = "https://github.com/patrickhayo/azr-tf-module-nat-gateway"
}

