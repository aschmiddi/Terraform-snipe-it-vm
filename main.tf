resource "azurerm_resource_group" "rg" {
  location = var.resource_group_location
  name = "rg-aschmidt-cw-terraform"
}

# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "myVnet-cloudwalker"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create subnet
# Create subnet
resource "azurerm_subnet" "my_terraform_subnet" {
  name                 = "mySubnet-cloudwalker"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create public IPs
resource "azurerm_public_ip" "my_terraform_public_ip" {
  name                = "myPublicIP-cloudwalker"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "my_terraform_nsg" {
  name                = "myNetworkSecurityGroup-cloudwalker"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

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
}

# Create network interface
resource "azurerm_network_interface" "my_terraform_nic" {
  name                = "myNIC-cloudwalker"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "my_nic_configuration-cloudwalker"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.my_terraform_nic.id
  network_security_group_id = azurerm_network_security_group.my_terraform_nsg.id
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = azurerm_resource_group.rg.name
  }

  byte_length = 8
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = azurerm_resource_group.rg.location
  resource_group_name      = azurerm_resource_group.rg.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "my_terraform_vm" {
  name                  = "vm-terraform-cloudwalker"
  location              = azurerm_resource_group.rg.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.my_terraform_nic.id]
  size                  = "Standard_B1s"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name  = "hostname"
  admin_username = var.username

  admin_ssh_key {
    username   = var.username
    public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCueJ7xmB4ni8COeSkQt+mO2CPAB4MwMNj2rQN1aMKPJBIPrZnuJylMsqY/SZPhR/lH5E9knHTRDp+IuVDIEKkOVWRTEiyFXnT/Y3axNWEOmxrbdg7sUyKxe3YWfWxsc9X9e7nJ9+FUCJzsuHINiqs7NRPpTkwG7+pV08DCleFJ6G3cCQKT41stmB4YTbXaR421QY0HWINhLMaBhE+0bxgq6jnw8iHadCNkSUfvCcj9W7DmUQKX33QBBdZ5ss4VHJ2wsLieRIWHKFLgp3QZZJuXfd+Im2C3ZrKRl29nuaVQtuQ3Pl4nwBoidS6vpZP5C4B38yJn/cIC2SwFFtndSH+wdbIAwFLI80gUY8iubfn7X9szf/coFJEgkV/b3dS5+DgQBWJ1VqHEy4sl8wTWVJVFntE0s37BV9cXjOw/9pASuZlaCXHEOvfSyfceMSxhU6ADl3xk/qZiI8ntJ37DznEySGpp2t/RSf1H/OBexcEo5hd4rV6FspQg4eH+NS9GoLp+ycJmf6Dy9gNT71DAN/4WBi0+i7QpdAsvCBCNQ8UAIxZ1EmNJJFgspSdesusmWUMaoME/o/o3vR5pcIvTVagTiuysd735EjjAbZussSRs/M5N7A9ZAI5LbF/bSKuwKozXIHeC0C6ERsZHeeszZ12HeSZsIzG3mLGvzNOF3VCQhQ== azureadmin@4.184.214.13"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}

terraform {
  backend "azurerm" {
    resource_group_name = "rg-aschmidt-cloudwalker"
    storage_account_name = "stacloudwalkerterraform"
    container_name = "c-cloudwalker-terraform"
    key = "prod.terraform.tfstate"
  }
  

}
