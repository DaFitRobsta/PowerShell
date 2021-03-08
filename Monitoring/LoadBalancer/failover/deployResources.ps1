New-AzResourceGroup -Name "RG-RL-USGAZ-DMO-01" -Location usgovarizona

New-AzResourceGroupDeployment `
  -Name linkedTemplatesSLBAlerts `
  -ResourceGroupName "RG-RL-USGAZ-DMO-01" `
  -TemplateUri "https://raw.githubusercontent.com/DaFitRobsta/PowerShell/master/Monitoring/LoadBalancer/failover/maintemplate.json" `
  -TemplateParameterUri "https://raw.githubusercontent.com/DaFitRobsta/PowerShell/master/Monitoring/LoadBalancer/failover/maintemplate.parameters.gov.json"

  New-AzResourceGroupDeployment `
  -Name linkedTemplatesSLBAlerts `
  -ResourceGroupName "rl-wu2-dmo-np-rg01" `
  -TemplateUri "https://raw.githubusercontent.com/DaFitRobsta/PowerShell/master/Monitoring/LoadBalancer/failover/maintemplate.json" `
  -TemplateParameterUri "https://raw.githubusercontent.com/DaFitRobsta/PowerShell/master/Monitoring/LoadBalancer/failover/maintemplate.parameters.json"