# Get Data of the Azuer Subscription
data "azurerm_client_config" "this" {}


# Create Azure Resouce Group
resource "azurerm_resource_group" "this" {
  name     = local.resource_group_name
  location = local.location
}

# Get Data of the created Azure Resouce Group (for simplification of the running script)
data "azurerm_resource_group" "this" {
  name = azurerm_resource_group.this.name
}


# Create Azure Virtual Network (VNET)
module "network" {
  source              = "github.com/patrickhayo/modules//vnet"
  vnet_name           = local.vnet_name
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  address_space       = local.address_space
  subnets             = local.subnets
}

# Create Azure NAT Gateway
module "nat" {
  source                              = "github.com/patrickhayo/modules//nat"
  name                                = "nat-${local.vnet_name}"
  resource_group_name                 = data.azurerm_resource_group.this.name
  location                            = data.azurerm_resource_group.this.location
  prefix_enabled                      = local.nat_gateway_prefix_enabled
  subscription_id                     = data.azurerm_client_config.this.subscription_id
  virtual_network_name                = local.vnet_name
  virtual_network_resource_group_name = data.azurerm_resource_group.this.name
  subnets_to_associate                = module.network.subnet_names
  depends_on = [
    module.network,
  ]
}

# Create Azure Private DNS Zone
module "privatednszone" {
  source               = "github.com/patrickhayo/modules//privatednszone"
  name                 = local.private_dns_zone_name
  resource_group_name  = data.azurerm_resource_group.this.name
  registration_enabled = local.private_dns_zone_registration_enabled
  virtual_networks_to_link = {
    (local.vnet_name) = {
      subscription_id     = data.azurerm_client_config.this.subscription_id
      resource_group_name = data.azurerm_resource_group.this.name
    }
  }
  depends_on = [
    module.network,
  ]
}

# Create Network Security Groups (NSG)
module "nsg" {
  source              = "github.com/patrickhayo/modules//nsg"
  for_each            = toset(module.network.subnet_names)
  name                = "nsg-${each.key}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  associate_subnet_id = module.network.subnet_ids[each.key]
  # Apply the default "Bastion Host" rules ( inbound allow on 3389/tcp, 22/tcp), 
  # only if an "AzureBastionSubnet" is part of the Configuration.
  # Otherwise skip the "Basion Host" default inbount rules.
  rules = contains(module.network.subnet_names_services, "AzureBastionSubnet") ? [
    {
      name        = "AllowRemoteAzureBastionSubnetInbound"
      description = "Allow SSH and RDP from AzureBastionSubnet Inbound."
      protocol    = "*"
      access      = "Allow"
      priority    = 100
      direction   = "Inbound"
      source = {
        port_range                     = "*"
        port_ranges                    = null
        address_prefix                 = join("", module.network.subnet_address_prefixes["AzureBastionSubnet"])
        address_prefixes               = null
        application_security_group_ids = null
      }
      destination = {
        port_range                     = null
        port_ranges                    = ["22", "3389"]
        address_prefix                 = join("", module.network.subnet_address_prefixes[each.key])
        address_prefixes               = null
        application_security_group_ids = null
      }
    },
    {
      name        = "DenyRemoteAnyInbound"
      description = "Deny SSH and RDP from Any Inbound."
      protocol    = "*"
      access      = "Allow"
      priority    = 200
      direction   = "Inbound"
      source = {
        port_range                     = "*"
        port_ranges                    = null
        address_prefix                 = "*"
        address_prefixes               = null
        application_security_group_ids = null
      }
      destination = {
        port_range                     = null
        port_ranges                    = ["22", "3389"]
        address_prefix                 = join("", module.network.subnet_address_prefixes[each.key])
        address_prefixes               = null
        application_security_group_ids = null
      }
    },
  ] : []
  depends_on = [
    module.network
  ]
}

# Create Azure Bastion Host
module "bastion_host" {
  source              = "github.com/patrickhayo/modules//bastionhost"
  name                = local.bastion_host_name
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  subnet_id           = module.network.subnet_ids["AzureBastionSubnet"]
  depends_on = [
    module.network,
  ]
}

# Create specific Network Security Group (NSG) for Bastion Subnet
module "nsg_AzureBastionSubnet" {
  source              = "github.com/patrickhayo/modules//bastionhost"
  name                = "nsg-${local.bastion_host_name}"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  associate_subnet_id = module.network.subnet_ids["AzureBastionSubnet"]
  rules = [
    {
      name        = "AllowHttpsInbound"
      description = "Allow Internet HTTPS to Bastion Host"
      protocol    = "Tcp"
      access      = "Allow"
      priority    = 120
      direction   = "Inbound"
      source = {
        port_range                     = "*"
        port_ranges                    = null
        address_prefix                 = "Internet"
        address_prefixes               = null
        application_security_group_ids = null
      }
      destination = {
        port_range                     = "443"
        port_ranges                    = null
        address_prefix                 = "*"
        address_prefixes               = null
        application_security_group_ids = null
      }
    },
    {
      name        = "AllowGatewayManagerInbound"
      description = "Allow GatewayManager HTTPS to Basion Host"
      protocol    = "Tcp"
      access      = "Allow"
      priority    = 130
      direction   = "Inbound"
      source = {
        port_range                     = "*"
        port_ranges                    = null
        address_prefix                 = "GatewayManager"
        address_prefixes               = null
        application_security_group_ids = null
      }
      destination = {
        port_range                     = null
        port_ranges                    = ["443", "4443"]
        address_prefix                 = "*"
        address_prefixes               = null
        application_security_group_ids = null
      }
    },
    {
      name        = "AllowLoadBalancerInbound"
      description = "Allow Loadbalancer HTTPS to Basion Host"
      protocol    = "Tcp"
      access      = "Allow"
      priority    = 140
      direction   = "Inbound"
      source = {
        port_range                     = "*"
        port_ranges                    = null
        address_prefix                 = "AzureLoadBalancer"
        address_prefixes               = null
        application_security_group_ids = null
      }
      destination = {
        port_range                     = "443"
        port_ranges                    = null
        address_prefix                 = "*"
        address_prefixes               = null
        application_security_group_ids = null
      }
    },
    {
      name        = "AllowLBasionHostComunication"
      description = "Allow Basstion Host Communication"
      protocol    = "*"
      access      = "Allow"
      priority    = 150
      direction   = "Inbound"
      source = {
        port_range                     = "*"
        port_ranges                    = null
        address_prefix                 = "VirtualNetwork"
        address_prefixes               = null
        application_security_group_ids = null
      }
      destination = {
        port_range                     = null
        port_ranges                    = ["8080", "5701"]
        address_prefix                 = "VirtualNetwork"
        address_prefixes               = null
        application_security_group_ids = null
      }
    },
    {
      name        = "AllowSshRdpOutbound"
      description = "Allow SSH and RDP outbound"
      protocol    = "*"
      access      = "Allow"
      priority    = 100
      direction   = "Outbound"
      source = {
        port_range                     = "*"
        port_ranges                    = null
        address_prefix                 = "*"
        address_prefixes               = null
        application_security_group_ids = null
      }
      destination = {
        port_range                     = null
        port_ranges                    = ["22", "3389"]
        address_prefix                 = "VirtualNetwork"
        address_prefixes               = null
        application_security_group_ids = null
      }
    },
    {
      name        = "AllowAzureCloudOutbound"
      description = "Allow Azure Cloud outbound"
      protocol    = "Tcp"
      access      = "Allow"
      priority    = 110
      direction   = "Outbound"
      source = {
        port_range                     = "*"
        port_ranges                    = null
        address_prefix                 = "*"
        address_prefixes               = null
        application_security_group_ids = null
      }
      destination = {
        port_range                     = "443"
        port_ranges                    = null
        address_prefix                 = "AzureCloud"
        address_prefixes               = null
        application_security_group_ids = null
      }
    },
    {
      name        = "AllowBastionComunicationOutbound"
      description = "Allow Bastion Host to Azure Cloud outbound"
      protocol    = "*"
      access      = "Allow"
      priority    = 120
      direction   = "Outbound"
      source = {
        port_range                     = "*"
        port_ranges                    = null
        address_prefix                 = "VirtualNetwork"
        address_prefixes               = null
        application_security_group_ids = null
      }
      destination = {
        port_range                     = null
        port_ranges                    = ["8080", "5701"]
        address_prefix                 = "VirtualNetwork"
        address_prefixes               = null
        application_security_group_ids = null
      }
    },
    {
      name        = "AllowGetSessionInformationOutbound"
      description = "Allow Bastion Host get Session Information outbound"
      protocol    = "*"
      access      = "Allow"
      priority    = 130
      direction   = "Outbound"
      source = {
        port_range                     = "*"
        port_ranges                    = null
        address_prefix                 = "*"
        address_prefixes               = null
        application_security_group_ids = null
      }
      destination = {
        port_range                     = "80"
        port_ranges                    = null
        address_prefix                 = "Internet"
        address_prefixes               = null
        application_security_group_ids = null
      }
    },
  ]
  depends_on = [
    module.network,
    module.bastion_host
  ]
}
