[CmdletBinding()]
param (
    [Parameter( HelpMessage="Enter the Azure Cloud to connect to. Default is AzureCloud.")]
    [ValidateSet("AzureCloud", "AzureUSGovernment", "AzureGermanCloud", "AzureChinaCloud")]
    [string]
    $AzureEnvironment='AzureCloud'
)

# Create a Compressed ZIP file representing the Function App.
$mypath = Split-Path $MyInvocation.MyCommand.Path
$functionAppPath = $mypath + "\FunctionAppCode"

$TmpFuncZipDeployPath = $mypath + "\mytmpFunction.zip" 

$excludeFilesAndFolders = @(".git",".vscode","bin","Microsoft",".funcignore",".gitignore") 

$FileToSendArray = @() 

foreach ($file in get-childitem -Path $functionAppPath) { 

    if ($file.name -notin $excludeFilesAndFolders) { 

        $FileToSendArray += $file.fullname 

    }
} 
compress-archive -Path $FileToSendArray -DestinationPath $TmpFuncZipDeployPath -Force

# Deploy ZIP file to Azure Function App
# Determine if already connected to Azure
try {
  $connected = Get-AzSubscription
}
catch {
  Write-Host "Not connected to Azure and you will prompt you to connect to Azure" -ForegroundColor Green
  $result = Connect-AzAccount -Environment $AzureEnvironment
}
Write-Host ""
Write-Host "List of available subscriptions:" -ForegroundColor Green
(Get-AzSubscription).name
Write-Host ""
$subscriptionName = Read-Host -Prompt "Enter Subscription Name"
$result = Select-AzSubscription -SubscriptionName $subscriptionName

Write-Host ""
Write-Host "List of available Resource Groups:" -ForegroundColor Green
(Get-AzResourceGroup).ResourceGroupName
Write-Host ""
$resourceGroup = Read-Host -Prompt "Enter the Resource Group Name"
# Write-Host ""
# Write-Host "List of available Function Apps:" -ForegroundColor Green
# (Get-AzFunctionApp).Name
# Write-Host ""
# $FunctionAppName = Read-Host -Prompt "Enter the Function App Name"
#$resourceGroup = (Get-AzFunctionApp | Where-Object {$_.name -eq $FunctionAppName}).ResourceGroupName

# Create Azure Resources
$output = New-AzResourceGroupDeployment -Name 'deployFunctionAppResources' -ResourceGroupName $resourceGroup -TemplateFile .\IaC\main.bicep -TemplateParameterFile .\IaC\main.parameters.json
<# Consider adding the app setting variables needed for inserting into Log Analytics Workspace
Update-AzFunctionAppSetting -Name <FUNCTION_APP_NAME> -ResourceGroupName <RESOURCE_GROUP_NAME> -AppSetting @{"CUSTOM_FUNCTION_APP_SETTING" = "12345"}
#>
if($output.ProvisioningState -eq "Succeeded") {
  Write-Host "Deployment succeeded. Deploying Function App code..." -ForegroundColor Green
  $FunctionAppName = $output.Parameters.funappName.value
  Publish-AzWebapp -ResourceGroupName $resourceGroup -Name $FunctionAppName –ArchivePath $TmpFuncZipDeployPath -force
  Write-Host "Don't forget to grant the function app managed identity reader access to Subscriptions or Management Groups" -ForegroundColor Yellow
}