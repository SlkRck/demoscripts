get-azvm -ResourceGroupName $rgvmname -Name $vmname -Status

#generate RDP file
Get-AzRemoteDesktopFile -ResourceGroupName $rgVMName `
    -Name $vmName `
    -LocalPath c:\temp\WebVM.rdp

#Provision additional disks
$vm = Get-AzVM -ResourceGroupName $rgVMName -Name $vmName
$dataDisk2Name = "vm1-datadisk2" 
$dataDisk2Uri = $blobEndpoint + "vhds/" + $dataDisk2Name + ".vhd"
$vm | Add-AzVMDataDisk -Name $dataDisk2Name `
    -VhdUri $dataDisk2Uri `
    -Caching None `
    -DiskSizeInGB 1023 `
    -Lun 1 `
    -CreateOption empty
$vm | Update-AzVM -ResourceGroupName $rgVMName
