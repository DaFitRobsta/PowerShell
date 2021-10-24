<#
.SYNOPSIS
Sends Subscription Quota and Usages to a Log Analytics Workspace

.DESCRIPTION
Azure Resource Quotas into a Log Analytics Workspace (Using PowerShell)
Credit to Original Solution: https://blogs.msdn.microsoft.com/tomholl/2017/06/11/get-alerts-as-you-approach-your-azure-resource-quotas/

Useful resources:
https://docs.microsoft.com/en-us/azure/azure-monitor/logs/data-collector-api
https://dev.to/omiossec/powershell-code-and-azure-functions-a-little-more-2ob6

.PARAMETER omsWorkspaceId
A Log Analytics Workspace ID.

.PARAMETER omsSharedKey
A Log Analytics Shared Key.

.PARAMETER Subscriptions
A list of subscriptions to gather quota information on. This is formatted ["SubscriptionID1", "SubscriptionID2", "etc"]
To see a list of subscriptions your account can access use the PowerShell command "Get-AzSubscription". The ID field is the subscription ID.

.PARAMETER locations
A list of locations for each of the above subscriptions to gather quota information on. This is formatted ["South Africa North", "UK West", "etc"]
To get a list of locations use the PowerShell command "Get-AzLocation". Either Displayname or Location fields can be used.

.NOTES

LEGAL DISCLAIMER:
This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment. 
THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED,
INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE. 
We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form of the Sample Code, provided that You agree:
(i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded;
(ii) to include a valid copyright notice on Your software product in which the Sample Code is embedded; and
(iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys' fees, that arise or result from the use or distribution of the Sample Code.
This posting is provided "AS IS" with no warranties, and confers no rights.
#>

Param($Timer)

$omsWorkspaceId = $env:omsWorkspaceId
$omsSharedKey = $env:omsSharedKey
$Locations = $env:Locations

#If user gives the Location list with comma seperated....
[string[]] $AzLocations = $Locations -split ","

# I don't think I need this since the environment is already set to log in with the identity.
<# try
{
    "Logging in to Azure..."
    $null = Connect-AzAccount -Identity
}
catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
} #>

$LogType = "AzureQuota"
 
 
# Create the function to create the authorization signature
Function Build-Signature ($omsWorkspaceId, $omsSharedKey, $date, $contentLength, $method, $contentType, $resource)
{
    $xHeaders = "x-ms-date:" + $date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
 
    $bytesToHash = [Text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($omsSharedKey)
 
    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.Key = $keyBytes
    $calculatedHash = $sha256.ComputeHash($bytesToHash)
    $encodedHash = [Convert]::ToBase64String($calculatedHash)
    $authorization = 'SharedKey {0}:{1}' -f $omsWorkspaceId,$encodedHash
    return $authorization
}
 
# Create the function to create and post the request
Function Post-LogAnalyticsData($omsWorkspaceId, $omsSharedKey, $body, $logType)
{
    $method = "POST"
    $contentType = 'application/json'
    $resource = "/api/logs"
    $rfc1123date = [DateTime]::UtcNow.ToString("r")
    $contentLength = $body.Length
    $signature = Build-Signature `
        -omsWorkspaceId $omsWorkspaceId `
        -omsSharedKey $omsSharedKey `
        -date $rfc1123date `
        -contentLength $contentLength `
        -method $method `
        -contentType $contentType `
        -resource $resource
    $uri = "https://" + $omsWorkspaceId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"
 
    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $logType;
        "x-ms-date" = $rfc1123date;
    }
 
        $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $contentType -Headers $headers -Body $body -UseBasicParsing
        return $response.StatusCode
}

# Main routine starts here
$Subscriptions = Get-AzSubscription

# for each subscription get the quota data
foreach ($Subscription in $Subscriptions)
{
$SubscriptionId = $Subscription.Id
#$SubscriptionName = $Subscription.Name

Set-AzContext -SubscriptionId $SubscriptionId
$azureContext = Get-AzContext
$SubscriptionName = $azureContext.Subscription.Name

Write-Output "Checking Quota Usage on $SubscriptionName"

$json = ''

# Get VM quotas
foreach ($AzLoc in $AzLocations)
{
    $vmQuotas = Get-AzVMUsage -location $AzLoc
    foreach($vmQuota in $vmQuotas)
    {
        $usage = 0
        if ($vmQuota.Limit -gt 0) { $usage = $vmQuota.CurrentValue / $vmQuota.Limit }
        $json += @"
{ "SubscriptionId":"$SubscriptionId", "Subscription":"$SubscriptionName", "Name":"$($vmQuota.Name.LocalizedValue)", "Category":"Compute", "Location":"$AzLoc", "CurrentValue":$($vmQuota.CurrentValue), "Limit":$($vmQuota.Limit),"Usage":$usage },
"@
    }
}

# Get Network Quota
foreach ($AzLoc in $AzLocations)
{
    $networkQuotas = Get-AzNetworkUsage -location $AzLoc
    foreach ($networkQuota in $networkQuotas)
    {
        $usage = 0
        if ($networkQuota.limit -gt 0) { $usage = $networkQuota.currentValue / $networkQuota.limit }
         $json += @"
{ "SubscriptionId":"$SubscriptionId", "Subscription":"$SubscriptionName", "Name":"$($networkQuota.name.localizedValue)", "Category":"Network", "Location":"$AzLoc", "CurrentValue":$($networkQuota.currentValue), "Limit":$($networkQuota.limit),"Usage":$usage },
"@
    } 
}

# Get Storage Quota
foreach ($AzLoc in $AzLocations)
{
    $storageQuota = Get-AzStorageUsage -Location $AzLoc
    $usage = 0
    if ($storageQuota.Limit -gt 0) { $usage = $storageQuota.CurrentValue / $storageQuota.Limit }
    $json += @"
{ "SubscriptionId":"$SubscriptionId", "Subscription":"$SubscriptionName", "Name":"$($storageQuota.LocalizedName)", "Location":"$AzLoc", "Category":"Storage", "CurrentValue":$($storageQuota.CurrentValue), "Limit":$($storageQuota.Limit),"Usage":$usage },
"@
}
# Wrap in an array
$json = $json.substring(0, $json.lastindexof(','))
$json = "[$json]"
#write-output $json
Write-Output "Got all Subscription Quota Usage data for $SubscriptionName and inserting it into Log Analytics"
 
# Submit the data to the API endpoint
Post-LogAnalyticsData -omsWorkspaceId $omsWorkspaceId -omsSharedKey $omsSharedKey -body ([System.Text.Encoding]::UTF8.GetBytes($json)) -logType $logType
}