
(Get-AzResourceProvider -ProviderNamespace Microsoft.Compute).Locations | sort -Unique 

$location = "West US 2"
$rgVNETName = "OpsSharedVNETPSRG"
New-AzResourceGroup -Name $rgVNETName -Location $location

Import-Module Az.Network
$subnets = @()
$subnets += New-AzVirtualNetworkSubnetConfig -Name "Apps" -AddressPrefix 10.0.1.0/24
$subnets += New-AzVirtualNetworkSubnetConfig -Name "Data" -AddressPrefix 10.0.2.0/24

$vnetName = "OpsTrainingVNETPS"
$vnet = New-AzVirtualNetwork -Name $vnetName -ResourceGroupName $rgVNETName -Location $location -AddressPrefix 10.0.0.0/16 -Subnet $subnets
#Verification
Get-AzVirtualNetwork -ResourceGroupName $rgVNETName

$rgVMName = "OpsTrainingVMRG" 
New-AzResourceGroup -Name $rgVMName -Location $location

#Later:Add IF Statement where if the name is available (true) then create
Get-AzStorageAccountNameAvailability -Name "devopslabstorage"
$storageAccount = "devopslabstorage"

#Create Storage Account
New-AzStorageAccount -ResourceGroupName $rgVMName `
    -Location $location `
    -Name $storageAccount `
    -Type Standard_LRS

#Create Network Security Group (NSG)
$rules = @()
$rules += New-AzNetworkSecurityRuleConfig -Name "RDP" `
    -Protocol Tcp `
    -SourcePortRange "*" `
    -DestinationPortRange "3389" `
    -SourceAddressPrefix "*" `
    -DestinationAddressPrefix "*" `
    -Access Allow `
    -Description "Remote Desktop Access" `
    -Priority 100 `
    -Direction Inbound

$nsg = New-AzNetworkSecurityGroup -Name "webnsg" `
    -ResourceGroupName $rgVMName `
    -Location $location `
    -SecurityRules $rules

#Create Public IP Address
$vnet = Get-AzVirtualNetwork -ResourceGroupName $rgVNETName -Name $VNETName

#Test for availaility of DNS name - LATER: use IF statement to continue to create if output is "True"
Test-AzDnsAvailability -DomainQualifiedName "azdevops1" `
    -Location $location
$dnsName = "azdevops1"

$ipName = "webVMPubIP"
$pip = New-AzPublicIpAddress -Name $ipName `
    -ResourceGroupName $rgVMName `
    -Location $location `
    -AllocationMethod Dynamic `
    -DomainNameLabel $dnsName

$nicName = "webVMNIC1"
$nic = New-AzNetworkInterface -Name $nicName `
    -ResourceGroupName $rgVMName `
    -Location $location `
    -SubnetId $vnet.Subnets[0].Id `
    -PublicIpAddressId $pip.Id `
    -NetworkSecurityGroupId $nsg.ID

Install-Module Az.Compute -Force -AllowClobber

#Create Availability Set
$avSet = New-AzAvailabilitySet -ResourceGroupName $rgVMName -Name "WebAVSET" -Location $location

#Create first VM
$vmName = "webvm-1"
$vmSize = "Standard_D2S_V3"
$vm = New-AzVMConfig -VMName $vmName -VMSize $vmSize -AvailabilitySetId $avSet.Id
$vm | Add-AzVMNetworkInterface -Id $nic.Id

#Define a variable to hold the URL to the storage account for the virtual machine disks. This will be used to define full paths to VHD files.
$storageAcc = Get-AzStorageAccount -ResourceGroupName $rgVMName `
    -Name $storageAccount
$blobEndpoint = $storageAcc.PrimaryEndpoints.Blob.ToString()

#Attach additional storage to the virtual machine by defining variables for the name of a data disk and the URI in storage where it will be created at.
$dataDisk1Name = "vm1-datadisk1" 
$dataDisk1Uri = $blobEndpoint + "vhds/" + $dataDisk1Name + ".vhd"
$vm | Add-AzVMDataDisk -Name "datadisk1" `
    -VhdUri $dataDisk1Uri `
    -Caching None `
    -DiskSizeInGB 1023 `
    -Lun 0 `
    -CreateOption empty

# set the local credentials on the operating system and enable virtual machine agent. not recommended for production scenarios. use Azure Key Vault for credential storage.
$adminuser = "demouser"
$adminpassword = ConvertTo-SecureString -String "demo@pass123" -AsPlainText -Force
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $adminuser, $adminpassword

$vm | Set-AzVMOperatingSystem -Windows `
    -ComputerName $vmName `
    -Credential $cred `
    -ProvisionVMAgent

#Specify the virtual machine image configuration
$pubName   = "MicrosoftWindowsServer"
$offerName = "WindowsServer"
$skuName   = "2016-Datacenter"

$vm | Set-AzVMSourceImage -PublisherName $pubName `
    -Offer $offerName `
    -Skus $skuName `
    -Version "latest"

#specify the disk location for the OS disk and provision the virtual machine.
$osDiskName = "vm1-osdisk0"
$osDiskUri = $blobEndpoint + "vhds/" + $osDiskName + ".vhd"

$vm | Set-AzVMOSDisk -Name $osDiskName `
    -VhdUri $osDiskUri `
    -CreateOption fromImage

$vm | New-AzVM -ResourceGroupName $rgVMName `
    -Location $location

#Verify everything worked
Get-AzVM -ResourceGroupName $rgVMName -Name "webvm-1"