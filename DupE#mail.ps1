$user=Get-ADUser -Server "DomainControllerA" -Filter * -SearchBase "OU=Users,OU=Dept,DC=DomainA,DC=COM" -Properties proxyaddresses

$DomainAEmails=@()

foreach ($u in $user) {
foreach ($proxy in $u.proxyAddresses | Where-Object {$_ -like "*smtp*"}){
$usboralEmails+=$proxy.Split(":")[1]
}
}
#Do the same thing for Domain B
$user=Get-ADUser -Server "DomainControllerB" -Filter * -SearchBase "OU=USER ACCOUNTS,OU=Dept,DC=DomainB,DC=COM" -Properties emailaddress #yes-this is what I want

$DomainBEmails=@()
foreach ($u in $user) {
foreach ($proxy in $u.proxyAddresses | Where-Object {$_ -like "*smtp*"}){
$DomainBEmails+=$proxy.Split(":")[1]
}
}
#Now compare the two arrays for duplicates
$adPrimaryEmails=@()
$duplicates=@()
foreach ($primaryEmail in $adPrimaryEmails){
$newEmail = $primaryEmail.split("@")[0]+"@DomainA.com"
#check if exists in usboral list
if($DomainAEmails | Where-Object{$_ -like $newEmail}){
$duplicates+=$primaryEmail
}
}