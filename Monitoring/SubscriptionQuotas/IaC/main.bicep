// Create a new Log Analytics Workspace
@description('Log Analytics Name')
param lawName string

// Workbook name based on GUID
param workbookName string = guid('Azure Subscription Quotas and Usages')
param workbookSerializedData string

@description('Name of the Function App')
param funappName string = 'rz-wu2-quota-pd-posh01'

@description('A list of locations for each of the above subscriptions to gather quota information on. This is formatted ["West US", "East US 2", "etc"]')
param Locations string = 'westus'

@description('Name of the email recipent')
param emailUserName string

@description('Enter an email address to send alerts to')
param emailUser01 string

var location = resourceGroup().location

resource law 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: lawName
  location: location
  properties: {
    retentionInDays: 30
  } 
}
output lawPrimaryKey string = listkeys(law.id, '2021-06-01').primarySharedKey
output lawID string = law.properties.customerId

// Workbook Example
resource lawWorkbook 'Microsoft.Insights/workbooks@2021-03-08' = {
  name: workbookName
  location: location
  kind: 'shared'
  properties: {
    serializedData: workbookSerializedData
    category: 'workbook'
    displayName: 'Azure Subscription(s) Quotas and Usages'
    sourceId: law.id
    version: '1.0'
  }
}

// Create a function app, consumption (serverless)
// App Service Plan
resource asp01 'Microsoft.Web/serverfarms@2021-01-15' = {
  name: 'asp-${uniqueString(funappName)}'
  location: location
  kind: ''
  sku: {
    tier: 'Dynamic'
    name: 'Y1'
  }
  properties: { 
  }
}

// Storage Account for Function App
resource storage01 'Microsoft.Storage/storageAccounts@2021-04-01' = {
  name: 'sta${uniqueString(funappName)}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
  }
}
output staEndpointSuffix string = substring(storage01.properties.primaryEndpoints.blob, lastIndexOf(storage01.properties.primaryEndpoints.blob, 'core.'), length(storage01.properties.primaryEndpoints.blob) - lastIndexOf(storage01.properties.primaryEndpoints.blob, 'core.') - 1)


// Function App
resource funapp 'Microsoft.Web/sites@2021-01-15' = {
  name: funappName
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned' 
  }
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage01.name};AccountKey=${listKeys(storage01.id, '2021-04-01').keys[0].value};EndpointSuffix=${substring(storage01.properties.primaryEndpoints.blob, lastIndexOf(storage01.properties.primaryEndpoints.blob, 'core.'), length(storage01.properties.primaryEndpoints.blob) - lastIndexOf(storage01.properties.primaryEndpoints.blob, 'core.') - 1)}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storage01.name};AccountKey=${listKeys(storage01.id, '2021-04-01').keys[0].value};EndpointSuffix=${substring(storage01.properties.primaryEndpoints.blob, lastIndexOf(storage01.properties.primaryEndpoints.blob, 'core.'), length(storage01.properties.primaryEndpoints.blob) - lastIndexOf(storage01.properties.primaryEndpoints.blob, 'core.') - 1)}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: '${funappName}afd0'
        }
        {
          name: 'omsWorkspaceId'
          value: law.properties.customerId
        }
        {
          name: 'omsSharedKey'
          value: listkeys(law.id, '2021-06-01').primarySharedKey
        }
        {
          name: 'Locations'
          value: Locations
        }
      ]
      use32BitWorkerProcess: true
      powerShellVersion: '~7'
    }
    serverFarmId: asp01.id
    clientAffinityEnabled: false
  }
}

// Create an Action Group for those who should be notified
resource actionGroup 'microsoft.insights/actionGroups@2019-06-01' = {
  name: 'ag-Subscription-QuotaUsage'
  location: 'Global'
  properties: {
    enabled: true
    groupShortName: 'ag-sub-usage'
    emailReceivers: [
      {
        name: emailUserName
        emailAddress: emailUser01
        useCommonAlertSchema: true
      }
    ]
  }
}

// Create a sample alert 
resource sampleAlert 'Microsoft.Insights/scheduledQueryRules@2021-02-01-preview' = {
  name: 'Subscription-Compute-Quota-Usage-Warning'
  location: location
  properties: {
    displayName: 'Subscription-Compute-Quota-Usage-Warning'
    description: 'Warning: Subscription Compute Quota Usage is at or above 80%'
    severity: 2
    enabled: true
    evaluationFrequency: 'P1D'
    scopes: [
      law.id
    ]
    windowSize: 'P1D'
    criteria: {
      allOf: [
        {
          query: '''AzureQuota_CL
          | where Location_s in('westus', 'West US')
          | where Category =~ 'compute'
          | where Usage_d > 0.80
          | summarize ['Current Usage'] = avg(CurrentValue_d) by ResourceType = Name_s, Subscription = Subscription_s'''
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
          failingPeriods: {
            numberOfEvaluationPeriods: 1
            minFailingPeriodsToAlert: 1
          }
        }
      ]
    }
    // autoMitigate has to be set to false since the alert is fired once a day
    autoMitigate: false
    actions: {
      actionGroups: [
        actionGroup.id
      ]
    }
  }
}
