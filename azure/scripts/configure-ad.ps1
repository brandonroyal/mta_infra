[CmdletBinding()]
Param(
  [string] $DomainName = "docker.local",
  [string] $MachinePrefix,
  [int] $WorkCount = 3
)

#Variables
$Date = Get-Date -Format "yyyy-MM-dd HHmmss"
$ContainerHostsGroupName = "containerhosts"
$WaitForHostSleep = New-TimeSpan -Seconds 30
$WaitForHostTimeout = New-TimeSpan -Minutes 3

$AppName = "app1"

$TestUserName = "user1"
$TestUserPassword = "Password123!"

function New-ADHostsGroup(){
  # This next step is bad. Don't do it in production. I'm not a Kerberos expert so I won't try to explain why  
  Add-KdsRootKey -EffectiveTime ((get-date).addhours(-10))

  New-ADGroup -GroupCategory Security -DisplayName "Container Hosts" -Name $ContainerHostsGroupName -GroupScope Universal
}

function Get-HostAvailability($HostName){
  try
  {
      return $(Get-ADComputer -Identity $HostName).Enabled
  }
  catch
  {
      return $False
  }
}

function Add-ContainerHostToGroup($HostName){
  #check if AD host exists in domain, if not, wait
  $timeoutIntervals = $($WaitForHostTimeout.TotalSeconds / $WaitForHostSleep.TotalSeconds)
  $i = 0

  Write-Host "[INFO] determining $HostName host availability in domain before attempting to join to group"
  while (!(Get-HostAvailability -HostName $HostName) -and ($i -lt $timeoutIntervals)) {
    $i++
    Write-Host "[INFO] $HostName unavailable in domain. Waiting $($WaitForHostSleep.TotalSeconds) seconds before retrying [$i/$timeoutIntervals]"
    Start-Sleep $WaitForHostSleep.TotalSeconds
    
  }
  if ($i -ge $timeoutIntervals){
    Write-Host "[ERROR] $HostName failed to join $ContainerHostsGroupName AD group. host availability in domain timed out"
    return
  }
  Write-Host "[INFO] $HostName available. Adding to $ContainerHostsGroupName AD Group"
  Get-ADGroup $ContainerHostsGroupName | Add-ADGroupMember -Members (Get-ADComputer -Identity $HostName)
}

function New-GroupManagedServiceAccount(){
  New-ADServiceAccount -name $AppName -DnsHostName "$AppName.$DomainName"  -ServicePrincipalNames "http/$AppName.$DomainName" -PrincipalsAllowedToRetrieveManagedPassword $ContainerHostsGroupName
}

function New-DomainUsers(){
  New-ADUser -Name $TestUserName -PasswordNeverExpires $true -AccountPassword ($TestUserPassword | ConvertTo-SecureString -AsPlainText -Force) -Enabled $true
  $user1 = Get-ADUser User1
  $usergroup = New-ADGroup -GroupCategory Security -DisplayName "App1 Authorized Users" -Name App1Users -GroupScope Universal
  For ($i=0; $i -lt $WorkCount; $i++) {
    $usergroup | Add-ADGroupMember -Members (Get-ADComputer -Identity $("{0}-wrk{1}" -F $MachinePrefix, $i) )
  }
  
}

try
{
  Start-Transcript -path "C:\configure-ad_$Date.log" -append
  
  Write-Host "[INFO] Creating AD Group for Container Hosts"
  New-ADHostsGroup

  Write-Host "[INFO] Joining hosts to container hosts AD Group"
  For ($i=0; $i -lt $WorkCount; $i++) {
    Add-ContainerHostToGroup -HostName "$MachinePrefix-wrk$i"
  }

  Write-Host "[INFO] Creating gMSA"
  New-GroupManagedServiceAccount

  Write-Host "[INFO] Creating Test Users"
  New-DomainUsers

  Stop-Transcript
}
catch
{
  Write-Error $_
}