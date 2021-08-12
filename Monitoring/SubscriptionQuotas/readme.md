# Send Subscription Quota Usage Data to Log Analytics

## Background

At the present, there isn't a native Azure method for alerting when resource usage limits have been met. This solution uses the built-in [PowerShell cmdlets](https://docs.microsoft.com/en-us/azure/networking/check-usage-against-limits#powershell) to get the data from a subscription and insert it into a Log Analytics Workspace.  Through the use of an Azure Function App, triggered via Timer, it runs every 24 hours to pull data from Subscription(s) and inserts the usages into aLog Analytics Workspace.

## Requirements

- [Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/bicep-tutorial-create-first-bicep?tabs=azure-powershell) - Read through the Bicep tutorial to setup your environment.
- Log Analytics Workspace
- App Service Plan (Consumption Plan)
- Function App
- Storage Account
- Alert(s) (optional)


## PowerShell Deployment

With Azure Bicep installed, run PublishFunction.ps1 from Visual Studio Code or a PowerShell console

```PowerShell
.\PublishFunction.ps1
```

## KQL Queries

- Show all Resource Types with a usage greater than .1 in a Column Chart (stacked)

```KQL
AzureQuota_CL
| where Location_s in('westus', 'West US')
| where Category =~ 'compute'
| where Usage_d > 0.10
| summarize ['Current Usage'] = avg(CurrentValue_d) by ResourceType = Name_s
| render columnchart with(kind=stacked)
```

- Show all Resource (Quota) Names by a specific Azure region where the usage is greater than .05 in a column chart (unstacked)

```KQL
AzureQuota_CL
| where Location_s in('westus', 'West US')
| where Category =~ 'compute'
| where Usage_d > 0.05
| summarize ['Usage Percentage'] = sum(Usage_d * 100) by ['Resource Name'] = Name_s, Subscription = Subscription_s
| render columnchart with(kind= unstacked, ymax=100)
```
