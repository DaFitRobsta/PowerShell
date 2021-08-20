# Send Subscription Quota Usage Data to Log Analytics

## Background

At the present, there isn't a native Azure method for alerting when resource usage limits have been met. This solution uses the built-in [PowerShell cmdlets](https://docs.microsoft.com/en-us/azure/networking/check-usage-against-limits#powershell) to get the data from a subscription and insert it into a Log Analytics Workspace.  

Through the use of an Azure Function App, triggered via Timer, it runs every 24 hours to pull data from Subscription(s) and inserts the usages into a Log Analytics Workspace. Beyond ingesting the data, there's an included sample alert that emails if compute quota is greater than 80%.

## Requirements

- [Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/bicep-tutorial-create-first-bicep?tabs=azure-powershell) - Read through the Bicep tutorial to setup your environment.

## Resources Deployed

- Log Analytics Workspace
- Workbook
- App Service Plan (Consumption Plan)
- Function App
- Storage Account
- Action Group
- Alert

## PowerShell Deployment

With [Azure Bicep](https://docs.microsoft.com/en-us/azure/azure-resource-manager/templates/bicep-tutorial-create-first-bicep?tabs=azure-powershell) installed, run PublishFunction.ps1 from Visual Studio Code or a PowerShell console. If you haven't signed into Azure, the script will prompt you to sign in. Once signed in, you'll input which subscription and resource group for deploying the resources into.

> [IMPORTANT]
>
> The bicep deployment relies on the `main.parameters.json` and before executing `.\PublishFunction.ps1`, make sure you've updated the parameters.



```PowerShell
PS C:\repos\SubscriptionQuotas> .\PublishFunction.ps1
```

## Sample KQL Queries

- Show all Resource Types with a usage greater than .1 in a Column Chart (stacked)

```KQL
AzureQuota_CL
| where TimeGenerated > ago(1d)
| where Location_s in('westus', 'West US')
| where Category =~ 'compute'
| where Usage_d > 0.10
| summarize ['Current Usage'] = avg(CurrentValue_d) by ResourceType = Name_s
| render columnchart with(kind=stacked)
```

- Show all Resource (Quota) Names by a specific Azure region where the usage is greater than .05 in a column chart (unstacked)

```KQL
AzureQuota_CL
| where TimeGenerated > ago(1d)
| where Location_s in('westus', 'West US')
| where Category =~ 'compute'
| where Usage_d > 0.05
| summarize ['Usage Percentage'] = sum(Usage_d * 100) by ['Resource Name'] = Name_s, Subscription = Subscription_s
| render columnchart with(kind= unstacked, ymax=100)
```
