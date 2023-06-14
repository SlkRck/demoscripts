#AzureRM_RG_Terraform_template for testing#
provider "azurerm" {
    subscription_id="08201627-2ef3-4df3-be6f-9ddd7bea136b"
    tenant_id="20c5dd07-d38c-454a-80e4-c1799be03751"
    version = "~>2.1.0"
    features{}
  }
    
/*terraform {
    backend "azurerm" {
      resource_group_name   = "cloud-shell-storage-westus"
      storage_account_name  = "cs410032000d200b8e2"
      container_name        = "tstate"
      key                   = "terraform.tfstate"
    }
  }
*/
###################################################################

###################################################################
# Create Resource Groups
 locals {
    RG_list = {
      for rg in csvdecode(file("${path.module}/RGlist_Dev.csv")) :
      rg["Resource_Group_Name"] => {
        name     = rg["Resource_Group_Name"]
        location = rg["Location"]
      }
    }
 }
 resource "azurerm_resource_group" "ResourceGroups" {
    for_each = local.RG_list
    name     = each.value.name
    location = each.value.location
  }
####################################################################
# Create virtual networks within the resource groups
 locals {
     vnet_list ={
       for vnet in csvdecode(file("${path.module}/vnetlist_dev.csv")) :
      vnet["Name"] => {
        name     = vnet["Name"]
        location = vnet["Location"]
        resource_group_name = vnet["Resource_Group_Name"]
        address_space = vnet["Address_Space"]
        }
    }
 }
 resource "azurerm_virtual_network" "VirtualNetworks" {
    for_each = local.vnet_list
    name     = each.value.name
    location = each.value.location
    resource_group_name  = each.value.resource_group_name
    address_space = [each.value.address_space]
    depends_on = [azurerm_resource_group.ResourceGroups]
  }
###################################################################
# Create a Storage Account
resource "azurerm_storage_account" "demotaylorsa" {
  name                     = "demotaylorsa"
  resource_group_name      = "DemoRG-001"
  location                 = "West US"
  account_tier             = "Standard"
  account_replication_type = "LRS"
  depends_on = [azurerm_resource_group.ResourceGroups]
}
###################################################################
# Create subnets
locals {
    snet_list = {
      for snet in csvdecode(file("${path.module}/snetlist_dev.csv")) :
    snet["Subnet_Name"] => {
        name     = snet["Name"]
        resource_group_name = snet["Resource_Group_Name"]
        address_space = snet["Address_Space"]
        address_prefix = snet["Address_Prefix"]
        subnet_name = snet["Subnet_Name"]
      }
    }
  }
resource "azurerm_subnet" "subnets" {
    for_each = local.snet_list
    virtual_network_name     = each.value.name
    resource_group_name  = each.value.resource_group_name
    address_prefix = each.value.address_prefix
    name = each.value.subnet_name
    depends_on = [azurerm_virtual_network.VirtualNetworks]
  }
#####################################################################
# Create public IP for Linux
resource "azurerm_public_ip" "Linux_publicip" {
  name                = "Linux_publicip"
  location            = "West US"
  resource_group_name = "DemoRG-002"
  allocation_method   = "Static"
  depends_on = [azurerm_virtual_network.VirtualNetworks]
}
# Create public IP for Windows
resource "azurerm_public_ip" "Windows_publicip" {
  name                = "Windows_publicip"
  location            = "West US"
  resource_group_name = "DemoRG-001"
  allocation_method   = "Static"
  depends_on = [azurerm_virtual_network.VirtualNetworks]
}
##################################################################
# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg"
  location            = "West US"
  resource_group_name = "DemoRG-001"
  depends_on = [azurerm_virtual_network.VirtualNetworks]

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "RDP_Allow"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}
##################################################################
# Create network interface for Linux machine
resource "azurerm_network_interface" "Linux_nic" {
  name                      = "Linux_nic"
  location                  = "West US"
  resource_group_name       = "DemoRG-002"
  
  ip_configuration {
    name                          = "LinuxNICConfg"
    subnet_id                     = "/subscriptions/5246a658-81a5-4e56-9434-7eac0eb13478/resourceGroups/DemoRG-001/providers/Microsoft.Network/virtualNetworks/vnet-demo-001/subnets/subnet-demo-002"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.Linux_publicip.id
  }
}
# Create network interface for Windows machine
resource "azurerm_network_interface" "Windows_nic" {
  name                      = "Windows_nic"
  location                  = "West US"
  resource_group_name       = "DemoRG-001"
  
  ip_configuration {
    name                          = "WindowsNICConfg"
    subnet_id                     = "/subscriptions/5246a658-81a5-4e56-9434-7eac0eb13478/resourceGroups/DemoRG-001/providers/Microsoft.Network/virtualNetworks/vnet-demo-001/subnets/subnet-demo-001"
    private_ip_address_allocation = "dynamic"
    public_ip_address_id          = azurerm_public_ip.Windows_publicip.id
  }
}
#################################################################
# Create a Linux virtual machine
resource "azurerm_virtual_machine" "linuxvm" {
  name                  = "LinuxVM"
  location              = "West US"
  resource_group_name   = "DemoRG-002"
  network_interface_ids = [azurerm_network_interface.Linux_nic.id]
  vm_size               = "Standard_D2s_v3"
  
  storage_os_disk {
    name              = "myOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
    }

  storage_image_reference {
    publisher = "RedHat"
    offer     = "RHEL"
    sku       = "7-RAW-CI"
    version   = "latest"
  }

  os_profile {
    computer_name  = "myTFVM"
    admin_username = "rtaylor9"
    admin_password = "Password1234!"
  }

  os_profile_linux_config {
    disable_password_authentication = false
  }
}

##########################################################################
resource "azurerm_windows_virtual_machine" "WindowsVM" {
  name                = "WindowsVM"
  resource_group_name = "DemoRG-001"
  location            = "West US"
  size                = "Standard_D2s_v3"
  admin_username      = "rtaylor9"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.Windows_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
    }
  }
######################################################
# Create a routing table and route entries
locals {
    route_list = {
      for route in csvdecode(file("${path.module}/routelist_dev.csv")) :
    route["Name"] => {
        name     = route["Name"]
        resource_group_name = route["Resource_Group_Name"]
        location = route["Location"]
        address_prefix = route["Address_Prefix"]
        next_hop_type = route["Next_Hop_Type"]
        disable_bgp_route_propagation = route["Disable_BGP_Route_Propagation"]

      }
    }
  }
resource "azurerm_route_table" "route" {
    for_each = local.route_list
    name     = each.value.name
    resource_group_name  = each.value.resource_group_name
    location = each.value.location
    disable_bgp_route_propagation = each.value.disable_bgp_route_propagation
    depends_on = [azurerm_resource_group.ResourceGroups]
  route {
    name = each.value.name
    address_prefix = each.value.address_prefix
    next_hop_type = each.value.next_hop_type
  }
}
