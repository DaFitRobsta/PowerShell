#Requires -Module Az.Accounts, Az.Monitor, Az.ResourceGraph

<#
.Synopsis

Through Automation Account Runbook Webhook, uses the Azure Resource Graph to find resources by name and search for any Azure Monitor Alerts associated with them.  Then
finds those alerts and either sets their status to enabled or disabled.

Reference links:
Search-AzGraph <https://docs.microsoft.com/en-us/powershell/module/az.resourcegraph/search-azgraph?view=azps-4.4.0>
Azure Monitor PowerShell samples <https://docs.microsoft.com/en-us/azure/azure-monitor/samples/powershell-samples>
Starter Resource Graph query samples <https://docs.microsoft.com/en-us/azure/governance/resource-graph/samples/starter>


.Requirements
    Az.Accounts
    Az.Monitor
    Az.ResourceGraph

.Known Issues
    When testing from Automation Account, set ResourceNames in JSON format like ['myvm1', 'myvm2']
  
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


# Determine if called from a WebHook
if ($WebhookData) {
    # Check header for message to validate request
    if ($WebhookData.RequestHeader.message -eq 'StartedbyDZ')
    {
        Write-Output "Header has required information"}
    else
    {
        Write-Output "Header missing required information"
        exit
    }
    # Retrieve VMs from Webhook request body
    $ResourceNames = (ConvertFrom-Json -InputObject $WebhookData.RequestBody) 

    # For Automation Account (AA), use AA to log into Azure 
    try {
        # Get the connection "AzureRunAsConnection "
        $connectionName = "AzureRunAsConnection"
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
        "Logging in to Azure..."
        $connectionResult =  Connect-AzAccount -Tenant $servicePrincipalConnection.TenantID `
                                -ApplicationId $servicePrincipalConnection.ApplicationID   `
                                -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
                                -SubscriptionId $servicePrincipalConnection.subscriptionId `
                                -ServicePrincipal
        "Logged in."
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

    # Main routine
    try {
        # Not called via WebHook, therefore parameters passed in directly via AA.
        if ($ResourceNames.Count -gt 0) {
            foreach ($resource in $ResourceNames) {            
                # Find Resource ID for resource name 
                $alerts = Search-AzGraph -Query "Resources | where type == 'microsoft.insights/scheduledqueryrules' or type == 'microsoft.insights/metricalerts' | where name contains '$($resource.Name)'"
                # The following query does include the scope.
                #$alerts = Search-AzGraph -Query "Resources | where type == 'microsoft.insights/scheduledqueryrules' or type == 'microsoft.insights/metricalerts' | where name contains '$($resource.Name)' and properties.scopes contains '$($resource.Name)'"
                #Write-Host $alerts.id

                # Test if we got any alerts
                if ($alerts.count -gt 0) {
                    # Enable or Disable the rule(s)
                    foreach ($alert in $alerts) 
                    { 
                        $subscriptionResult = Select-AzSubscription -SubscriptionId $alert.subscriptionId
                        if ($resource.Status -eq 'enabled')
                        {
                            $alertResult = Get-AzMetricAlertRuleV2 -ResourceId $alert.id | Add-AzMetricAlertRuleV2
                            Write-Output "Successfully $($resource.Status) <$($alert.name)>"
                        }
                        elseif ($resource.Status -eq 'disabled') {
                            $alertResult = Get-AzMetricAlertRuleV2 -ResourceId $alert.id | Add-AzMetricAlertRuleV2 -DisableRule
                            Write-Output "Successfully $($resource.Status) <$($alert.name)>"
                        }
                        else {
                            Write-Output "Please provide a value for Status" -ForegroundColor Blue
                        }
                    }
                }
                else {
                    Write-Error "No alerts found for $($resource.Name)"
                }
            }
        }
    }
    catch {
        Write-Error -Message $_.Exception
                throw $_.Exception
    }
}