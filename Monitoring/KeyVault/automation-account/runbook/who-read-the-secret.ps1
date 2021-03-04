#Requires -Module Az.Accounts, Az.Monitor, Az.Network

<#
.Synopsis

Through Automation Account Runbook Webhook, determine if we need to switch the backend pool of a load balancer.

Reference links:
Azure Monitor PowerShell samples <https://docs.microsoft.com/en-us/azure/azure-monitor/samples/powershell-samples>
Starter Resource Graph query samples <https://docs.microsoft.com/en-us/azure/governance/resource-graph/samples/starter>


.Requirements
    Az.Accounts
    Az.Monitor
    Az.Network

.Known Issues
    
  
.DISCLAIMER
    MIT License
 
    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
 
    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
 
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#>

[CmdletBinding()]
Param
(
    [Parameter (Mandatory = $false)]
    [object] $WebhookData
) # end param
$ErrorActionPreference = "stop"
# Set the Azure Cloud Environment, defaults to AzureCloud if not used in Connect-AzConnect 
$AzureEnvironment = "AzureCloud" #valid values include AzureUSGovernment
#$LBRule = "LBRule"

# Determine if called from a WebHook
if ($WebhookData) {
    # Get the data object from WebhookData
    $WebhookBody = (ConvertFrom-Json -InputObject $WebhookData.RequestBody)

    # Get the info needed to identify the VM (depends on the payload schema)
    $schemaId = $WebhookBody.schemaId
    Write-Verbose "schemaId: $schemaId" -Verbose
    if ($schemaId -eq "azureMonitorCommonAlertSchema") {
        # This is the common Metric Alert schema (released March 2019)
        $Essentials = [object] ($WebhookBody.data).essentials
        $AlertContext = [object] ($WebhookBody.data).alertContext
        # Get the first target only as this script doesn't handle multiple
        $alertTargetIdArray = (($Essentials.alertTargetIds)[0]).Split("/")
        $SubId = ($alertTargetIdArray)[2]
        $ResourceGroupName = ($alertTargetIdArray)[4]
        $ResourceType = ($alertTargetIdArray)[6] + "/" + ($alertTargetIdArray)[7]
        $ResourceName = ($alertTargetIdArray)[-1]
        $status = $Essentials.monitorCondition
        # Get the backendPool IP Address that failed from alertContext
        foreach($dimension in $AlertContext.condition.allOf[0].dimensions)
        {
            if($dimension.name -eq "CaAddress")
            {
                $backendPoolAddress = $dimension.value
            }
        }        
    }
    elseif ($schemaId -eq "AzureMonitorMetricAlert") {
        # This is the near-real-time Metric Alert schema
        $AlertContext = [object] ($WebhookBody.data).context
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = $AlertContext.resourceName
        $status = ($WebhookBody.data).status
    }
    elseif ($schemaId -eq "Microsoft.Insights/activityLogs") {
        # This is the Activity Log Alert schema
        $AlertContext = [object] (($WebhookBody.data).context).activityLog
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = (($AlertContext.resourceId).Split("/"))[-1]
        $status = ($WebhookBody.data).status
    }
    elseif ($schemaId -eq "Microsoft.Insights/LogAlert") {
        # This is the Log Alert schema
        $AlertContext = [object] (($WebhookBody.data).searchresults).tables
        <#
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = (($AlertContext.resourceId).Split("/"))[-1]
        $status = ($WebhookBody.data).status
        #>
        $TimeGenerated = $AlertContext.rows[0][0]
        $ResourceName = $AlertContext.rows[0][1]
        $Operation = $AlertContext.rows[0][2]
        $RequestURI = $AlertContext.rows[0][3]
        $CallerIPAddress = $AlertContext.rows[0][4]
        $UserOID = $AlertContext.rows[0][5]
    }
    elseif ($schemaId -eq $null) {
        # This is the original Metric Alert schema
        $AlertContext = [object] $WebhookBody.context
        $SubId = $AlertContext.subscriptionId
        $ResourceGroupName = $AlertContext.resourceGroupName
        $ResourceType = $AlertContext.resourceType
        $ResourceName = $AlertContext.resourceName
        $status = $WebhookBody.status
    }
    else {
        # Schema not supported
        Write-Error "The alert data schema - $schemaId - is not supported."
    }

    # Main routine
    try {
        <#
        Write-Verbose "status: $status" -Verbose
        if (($status -eq "Activated") -or ($status -eq "Fired"))
        {
        #>
            Write-Verbose "TimeGenerated: $TimeGenerated" -Verbose
            Write-Verbose "resourceName: $ResourceName" -Verbose
            Write-Verbose "Operation: $Operation" -Verbose
            Write-Verbose "RequestURI: $RequestURI" -Verbose
            Write-Verbose "UserOID: $UserOID"
    
 
            # For Automation Account (AA), use AA to log into Azure 
            try {
                # Authenticate to Azure with service principal and certificate and set subscription
                Write-Verbose "Authenticating to Azure with service principal and certificate" -Verbose
                # Get the connection "AzureRunAsConnection "
                $connectionName = "AzureRunAsConnection"
                $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
                "Logging in to Azure..."
                $connectionResult =  Connect-AzAccount -Tenant $servicePrincipalConnection.TenantID `
                                        -ApplicationId $servicePrincipalConnection.ApplicationID   `
                                        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
                                        -SubscriptionId $servicePrincipalConnection.subscriptionId `
                                        -ServicePrincipal `
                                        -Environment $AzureEnvironment
                "Logged in."
                #"Select subscription where resource is located"
                #$subscriptionResult = Select-AzSubscription -SubscriptionId $SubId
                "Connect to Azure AD"
                $connectionResult =  Connect-AzureAD -Tenant $servicePrincipalConnection.TenantID `
                                        -ApplicationId $servicePrincipalConnection.ApplicationID   `
                                        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
                                        -AzureEnvironmentName $AzureEnvironment
                #$result = Connect-AzureAd
                # Get user information from object ID
                $user = Get-AzureADUser -ObjectId $UserOID
                $user.UserPrincipalName
            }
            catch {
                if (!$servicePrincipalConnection) {
                    $ErrorMessage = "Connection $RunAsConnectionName not found."
                    throw $ErrorMessage
                } else{
                    Write-Error -Message $_.Exception
                    throw $_.Exception
                }
            }
             
    }
    catch {
        Write-Error -Message $_.Exception
                throw $_.Exception
        }
}
else {
    # Error
    Write-Error "This runbook is meant to be started from an Azure alert webhook only."
}