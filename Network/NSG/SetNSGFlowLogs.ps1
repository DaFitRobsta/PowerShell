#Surelight
$NW = Get-AzNetworkWatcher -ResourceGroupName NetworkWatcherRg -Name NetworkWatcher_eastus
$storageAccount = "/subscriptions/<SubscriptionID>/resourceGroups/Admin/providers/Microsoft.Storage/storageAccounts/surelighteu1"

$workspaceResourceId = "/subscriptions/<SubscriptionID>/resourcegroups/admin/providers/microsoft.operationalinsights/workspaces/surelight-law"
$workspaceGUID = "<workspaceID>"
$workspaceLocation = "westus2"

$nsgs = Get-AzNetworkSecurityGroup | Where-Object {$_.Location -eq "eastus"}

Foreach ($nsg in $nsgs)
{
	Write-host "Setting NSG Flogs for $($nsg.Name)"
	Set-AzNetworkWatcherConfigFlowLog -NetworkWatcher $NW -TargetResourceId $nsg.Id -StorageAccountId $storageAccount -EnableFlowLog $true -FormatType Json -FormatVersion 2 -EnableRetention $true -RetentionInDays 1 -EnableTrafficAnalytics -WorkspaceResourceId $workspaceResourceId -WorkspaceGUID $workspaceGUID -WorkspaceLocation $workspaceLocation -TrafficAnalyticsInterval 10
}