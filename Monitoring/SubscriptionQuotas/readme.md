# Send Subscription Quota Usage Data to Log Analytics

## Using a Timer triggered Function App

## KQL Queries

- Show all Resource Types that are being used with a usage greater than .1 in a Column Chart (stacked)

```KQL
AzureQuota_CL
| where Location_s == 'westus'
| where Name_s != 'Network Watchers'
| where Usage_d > 0.10
| summarize avg(CurrentValue_d) by ResourceType = Name_s, Limit = Limit_d
| render columnchart with(kind=stacked)
```

- Show all Quota Names by a specific Azure region where the usage is greater than .05 in a column chart (unstacked)

```KQL
AzureQuota_CL
| where Location_s == 'westus'
| where Name_s != 'Network Watchers'
| where Usage_d > 0.05
| summarize ['Usage Percentage'] = sum(Usage_d * 100) by ['Quota Name'] = Name_s, Subscription = Subscription_s
| render columnchart with(kind= unstacked)
```
