# Azure Automation Account deployment template

This template deploys an Azure Automation Account, creates a runbook for [set-lb-backendpool](https://github.com/DaFitRobsta/PowerShell/blob/master/Alerts/scripts/SetAzAlertsStatus-Webhook.ps1), and imports required modules:
* Az.Module
* Az.Monitor
* Az.Network

## Try on Portal

[![Deploy To Azure](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/deploytoazure.svg?sanitize=true)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3a%2f%2fraw.githubusercontent.com%2fDaFitRobsta%2fPowerShell%2fmaster%2fAlerts%2fautomation-account%2fazuredeploy.json)
