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
# Vaules include AzureCloud, AzureChinaCloud, AzureGermanCloud, AzureUSGovernment
$AzureEnvironment = "AzureUSGovernment"
# Identify which rule we'll be updating.
$LBRule = "LBRule"

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
        Write-Verbose "status: $status" -Verbose
        if (($status -eq "Activated") -or ($status -eq "Fired"))
        {
            Write-Verbose "resourceType: $ResourceType" -Verbose
            Write-Verbose "resourceName: $ResourceName" -Verbose
            Write-Verbose "resourceGroupName: $ResourceGroupName" -Verbose
            Write-Verbose "subscriptionId: $SubId" -Verbose
            Write-Verbose "BackendPoolIPAddress: $backendPoolAddress"
    
            # Determine code path depending on the resourceType
            if ($ResourceType -eq "microsoft.network/loadbalancers")
            {
                # This is an Resource Manager LB
                Write-Verbose "This is an Resource Manager LB." -Verbose
    
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
                    "Select subscription where resource is located"
                    $subscriptionResult = Select-AzSubscription -SubscriptionId $SubId
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
                
                # Update Backend Address Pool
                Write-Verbose "Updating backend address pool - $ResourceName - in resource group - $ResourceGroupName" -Verbose
                
                # Get existing rule configuration and store them away
                $slb = Get-AzLoadBalancer -Name $ResourceName -ResourceGroupName $ResourceGroupName
                $slbRule = (Get-AzLoadBalancer -Name $ResourceName | Get-AzLoadBalancerRuleConfig -Name $LBRule)
                $slbProbeName = ($slbRule.probe.id).tostring().split("/")[-1]
                $slbProtocol = $slbRule.Protocol
                $slbFEPort = $slbRule.FrontendPort
                $slbBEPort = $slbRule.BackendPort

                $slbProbe = $slb | Get-AzLoadBalancerProbeConfig -Name $slbProbeName

                # Get failed backend Pool
                $bePools = Get-AzLoadBalancer -Name $ResourceName | Get-AzLoadBalancerBackendAddressPool
                foreach ($bePool in $bePools) 
                {
                    # Don't include backend pools if more than 1 VM is defined
                    if($bePool.BackendIpConfigurations.count -gt 1){
                        continue
                    }
                    else {
                        $Nic = Get-AzNetworkInterface -ResourceId ($bePool.BackendIpConfigurations.id).Substring(0, ($bePool.BackendIpConfigurations.id).LastIndexOf("ipConfigurations") - 1)
                        $IPAddress = (Get-AzNetworkInterfaceIpConfig -NetworkInterface $Nic).PrivateIpAddress
                        if($IPAddress -ne $backendPoolAddress){
                            $slb | Set-AzLoadBalancerRuleConfig -Name $LBRule -BackendAddressPool $bePool -FrontendIpConfiguration $slb.FrontendIpConfigurations[0] -Protocol $slbProtocol -FrontendPort $slbFEPort -BackendPort $slbBEPort -Probe $slbProbe
                            $slb | Set-AzLoadBalancer
                            "Backend Pool set to - $($bePool.Name)"
                        }
                    }
                }                
            }
            else {
                # ResourceType not supported
                Write-Error "$ResourceType is not a supported resource type for this runbook."
            }
        }
        else {
            # The alert status was not 'Activated' or 'Fired' so no action taken
            Write-Verbose ("No action taken. Alert status: " + $status) -Verbose
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