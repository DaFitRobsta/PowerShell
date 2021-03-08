# Add an Automated Failover Behavior to Azure Load Balancers

## Background/Request

Azure Load Balancers do not currently support an active/passive configuration for their backend pool(s).  In order to meet this behavior/need, we'll use Azure Monitor to monitor the health probe(s) of the load balancer which will generate an alert to an action group configured with Azure Automation Runbook.

## Requirements

Must have at least two backend pools, containing at least one server, defined/declared.

## Known issue

It takes up to 5 minutes after the load balancer health probe has marked a backed server as unhealthy before the other backend pool is put into an active state.

## Reference links
[Create a metric alert with a Resource Manager template](https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-metric-create-templates)

## Try on Portal

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3a%2f%2fraw.githubusercontent.com%2fDaFitRobsta%2fPowerShell%2fmaster%2fMonitoring%2fLoadBalancer%2ffailover%2fmaintemplate.json)
[![Deploy To Azure US Gov](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazuregov.svg?sanitize=true)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3a%2f%2fraw.githubusercontent.com%2fDaFitRobsta%2fPowerShell%2fmaster%2fMonitoring%2fLoadBalancer%2ffailover%2fmaintemplate.json)