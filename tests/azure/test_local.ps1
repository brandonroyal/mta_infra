#Login-AzureRmAccount -Credential (Get-Credential) -TenantId "acpcloud482hotmail.onmicrosoft.com"

$ErrorActionPreference = "Stop"


#Set Variables
Write-Host "Setting variables"
$random = Get-Random -Minimum 0 -Maximum 32768 #Min is inclusive, Max is exclusive
$resourceGroupName = "mtainfra$random"
$location = "West US"
$storageAccountName = "mtainfra$random"

#Create Resource Group
Write-Host "Creating Resource Group"
New-AzureRmResourceGroup -Name $resourceGroupName -Location $location

#Create Asset Storage
Write-Host "Creating storage account and container"
New-AzureRmStorageAccount `
    -ResourceGroupName $resourceGroupName `
    -Name $storageAccountName `
    -SkuName Standard_LRS `
    -Location $location
Set-AzureRmCurrentStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
New-AzureStorageContainer -Name artifacts -Permission blob


#Upload Assets
Write-Host "Uploading assets"
Get-Item -Path "..\..\azure\scripts\*" | ForEach-Object {
    Set-AzureStorageBlobContent -File $_ -Container artifacts
} | Select-Object Name

#Perform Deployment
$parameters = @{
    'prefix' = 'mta'
    'adminUsername' = 'docker'
    'adminPassword' = 'P@ssword1'
    'sshPublicKey' = 'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDdqs3DLhpiXMSOTgSk0X7pjOE8Jk502pX1qERGACbuArBFUGxBAjBl5c3wdenC/P8oYtvHFGN0syVCaqxsn87vp//IWTzF2LIOySJQ55N9Wq2SpNEiEOxtgrF5O4EhC8pwQphEwovChwVijOJEQl0WX2HhGZBTiDmTFrCVl22S0CCHymthkDtFsiE5LCXMbZvOk5olZEAzLymrO1SKjHsgQruZAFFWSxoyUPn2SmmD2Br6SQe9sQr4k+CCQ5q3NYXxsj0tpbnNIpKg85ozsQ9CUgc+06juEqahuj1p5DLkbZfHz0zlmPd3wbM02YLQNX8ZxdLBF4RLVSv4dW4NwPxf broyal@docker.com'
    'artifactBaseUri' = "https://$storageAccountName.blob.core.windows.net/artifacts/"
}

New-AzureRmResourceGroupDeployment `
    -ResourceGroupName $resourceGroupName `
    -TemplateFile '..\..\azure\ddc\azuredeploy.json' `
    -TemplateParameterObject $parameters `
    -Verbose

$choice = Read-Host "Clean up resource group? [Y/N] (default Yes)"
if ($choice -in ($null, 'Y','Yes')) { Remove-AzureRmResourceGroup -Name $resourceGroupName }
