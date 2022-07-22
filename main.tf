module "identities" {
  source = "https://github.com/patrickhayo/azr-tf-module-identity"
}

module "privatednszone" {
  source = "https://github.com/patrickhayo/azr-tf-module-private-dns-zone"
}

module "vnet" {
  source = "https://github.com/patrickhayo/azr-tf-module-vnet"
}

