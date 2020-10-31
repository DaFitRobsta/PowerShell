#Requires -Module Az.Accounts, Az.Monitor, Az.ResourceGraph

<#
.Synopsis

Uses the Azure Resource Graph to find resources by name and search for any Azure Monitor Alerts associated with them.  Then
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
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
    [string[]]
    # When calling from AutomationAccount, use ['vmName1', 'vmName2', 'etc.']
    $ResourceNames = @("vmName", "vmName2"),
    [Parameter(Mandatory=$true)]
    [ValidateSet("Enabled","Disabled")]
    [string]
    $Status = "Enabled OR Disabled",
    [Parameter(Mandatory=$false)]
    [ValidateSet("AutomationAccount","PowerShellConsole")]
    [string]
    $Environment = "AutomationAccount",
    [string] $PSModuleRepository = "PSGallery"
) # end param


# Determine if running in POSH Console or Automation Account
if ($Environment -eq "PowerShellConsole") 
{
    #region MODULES
    # Module repository setup and configuration
    Set-PSRepository -Name $PSModuleRepository -InstallationPolicy Trusted -Verbose
    Install-PackageProvider -Name Nuget -ForceBootstrap -Force

    # Bootstrap dependent modules
    $AzModules = @("Az", "Az.ResourceGraph")
    ForEach ($module in $AzModules) 
    {
        if (Get-InstalledModule -Name $module -ErrorAction SilentlyContinue)
        {
            # If module exists, update it
            [string]$currentVersionADM = (Find-Module -Name $module -Repository $PSModuleRepository).Version
            [string]$installedVersionADM = (Get-InstalledModule -Name $module).Version
            If ($currentVersionADM -ne $installedVersionADM)
            {
                    # Update modules if required
                    Update-Module -Name $module -Force -ErrorAction SilentlyContinue -Verbose
            } # end if
        } # end if
        # If the modules aren't already loaded, install and import it.
        else
        {
            Install-Module -Name $module -Repository $PSModuleRepository -Force -Verbose
        } #end If
        Import-Module -Name $module -Verbose
    }
    #endregion MODULES
}
else 
{
    # For Automation Account (AA), use AA to log into Azure 
    try {
        # Get the connection "AzureRunAsConnection "
        $connectionName = "AzureRunAsConnection"
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName
        "Logging in to Azure..."
        $connectionResult =  Connect-AzAccount -Tenant $servicePrincipalConnection.TenantID `
                                -ApplicationId $servicePrincipalConnection.ApplicationID   `
                                -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint `
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
}

# Main routine
try {
    if ($ResourceNames.Count -gt 0) {
        foreach ($resource in $ResourceNames) {
            
            # Find Resource ID for resource name 
            $alerts = Search-AzGraph -Query "Resources | where type == 'microsoft.insights/scheduledqueryrules' or type == 'microsoft.insights/metricalerts' | where name contains '$resource'"
            # The following query includes the scope
            #$alerts = Search-AzGraph -Query "Resources | where type == 'microsoft.insights/scheduledqueryrules' or type == 'microsoft.insights/metricalerts' | where name contains '$resource' and properties.scopes contains '$resource'"
            #Write-Host $alerts.id

            # Test if we got any alerts
            if ($alerts.count -gt 0) {
                # Enable or Disable the rule(s)
                foreach ($alert in $alerts) 
                { 
                    write-host $alert.name
                    $subscriptionResult = Select-AzSubscription -SubscriptionId $alert.subscriptionId
                    if ($Status -eq 'enabled')
                    {
                        $alertResult = Get-AzMetricAlertRuleV2 -ResourceId $alert.id | Add-AzMetricAlertRuleV2
                        Write-Output "Successfully $Status <$($alert.name)>"
                    }
                    elseif ($Status -eq 'disabled') {
                        $alertResult = Get-AzMetricAlertRuleV2 -ResourceId $alert.id | Add-AzMetricAlertRuleV2 -DisableRule
                        Write-Output "Successfully $Status <$($alert.name)>"
                    }
                    else {
                        Write-Output "Please provide a value for Status" -ForegroundColor Blue
                    }
                }
            }
            else {
                Write-Error "No alerts found for $resource"
            }
        }
    }
}
catch {
    Write-Error -Message $_.Exception
            throw $_.Exception
}