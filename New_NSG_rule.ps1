#Adding a new rule to the Network Security Group

$nsg = Get-AzNetworkSecurityGroup -ResourceGroupName $rgVMName -Name "webnsg"
$nsg | Add-AzNetworkSecurityRuleConfig -Name "HTTP" `
    -Protocol Tcp `
    -SourcePortRange "*" `
    -DestinationPortRange "80" `
    -SourceAddressPrefix "*" `
    -DestinationAddressPrefix "*" `
    -Access Allow `
    -Description "Web Access" `
    -Priority 200 `
    -Direction Inbound

$nsg | Add-AzNetworkSecurityRuleConfig -Name "RemoteDesktop" `
    -Protocol Tcp `
    -SourcePortRange "*" `
    -DestinationPortRange "3389" `
    -SourceAddressPrefix "10.0.3.0/24" `
    -DestinationAddressPrefix "*" `
    -Access Allow `
    -Description "RDP Management Access" `
    -Priority 300 `
    -Direction Inbound

$nsg | Set-AzNetworkSecurityGroup

#verification
Get-AzNetworkSecurityGroup -ResourceGroupName $rgVMName | fl