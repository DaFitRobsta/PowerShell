New-AzResourceGroup -Name "RG-RL-USGAZ-DMO-01" -Location usgovarizona

# Azure US Government
New-AzResourceGroupDeployment `
  -Name linkedTemplatesSLBAlerts `
  -ResourceGroupName "RG-RL-USGAZ-DMO-01" `
  -TemplateUri "https://raw.githubusercontent.com/DaFitRobsta/PowerShell/master/Monitoring/LoadBalancer/failover/maintemplate.json" `
  -TemplateParameterUri "https://raw.githubusercontent.com/DaFitRobsta/PowerShell/master/Monitoring/LoadBalancer/failover/maintemplate.parameters.gov.json"

# Azure Cloud
New-AzResourceGroupDeployment `
    -Name linkedTemplatesSLBAlerts `
    -ResourceGroupName "rl-wu2-dmo-np-rg01" `
    -TemplateUri "https://raw.githubusercontent.com/DaFitRobsta/PowerShell/master/Monitoring/LoadBalancer/failover/maintemplate.json" `
    -TemplateParameterUri "https://raw.githubusercontent.com/DaFitRobsta/PowerShell/master/Monitoring/LoadBalancer/failover/maintemplate.parameters.json"