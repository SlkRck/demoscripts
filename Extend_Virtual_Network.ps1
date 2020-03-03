#Extending a Virtual Network - adds an additional subnet to an existing virtual network

$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $rgVMName -Name "webnsg" 
$vnet = Get-AzVirtualNetwork -ResourceGroupName $rgVNETName -Name $VNETName
$vnet | Add-AzVirtualNetworkSubnetConfig -Name "Management" `
    -AddressPrefix "10.0.3.0/24" `
    -NetworkSecurityGroupId $nsg.Id
$vnet | Set-AzVirtualNetwork

Get-AzVirtualNetwork -ResourceGroupName $rgVNETName -Name $VNETName | Select Subnets

