# Add an Automated Failover Behavior to Azure Load Balancers

## Background/Request

Azure Load Balancers do not currently support an active/passive configuration for their backend pool(s).  In order to meet this behavior/need, we'll use Azure Monitor to monitor the health probe(s) of the load balancer which will generate an alert to an action group configured with Azure Automation Runbook.

## Requirements

Must have at least two backend pools, containing at least one server, defined/declared.

## Known issue

It takes up to 5 minutes after the load balancer health probe has marked a backed server as unhealthy before the other backend pool is put into an active state.