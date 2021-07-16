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
