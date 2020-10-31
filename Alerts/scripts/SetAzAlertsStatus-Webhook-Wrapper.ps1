<#
 .Synopis
 Collects the server names the user wants to set the alert status for and calls an Azure Automation Runbook webhook
 to execute the request.

 .Requirements
 Update the URI for your Azure Automation Account
#>

$AlertStatus = Read-Host 'Enter the desired alert status: Enabled or Disabled'
$ServerCount = Read-Host 'How many servers are you setting their alert status?'

# Create an empty array
$data = @()
if ($AlertStatus -eq "enabled" -or $AlertStatus -eq "disabled") {
    for ($i=1; $i -le $ServerCount; $i++) {
    $ServerName = Read-Host 'Enter Server Name'
    $object = New-Object -TypeName PSObject
    $object | Add-Member -Name 'Name' -MemberType Noteproperty -Value $ServerName
    $object | Add-Member -Name 'Status' -MemberType Noteproperty -Value $AlertStatus
    $data += $object
    }
}
Else {
    Write-Host "You didn't enter a valid value for the Alert Status. It should be either Enabled or Disabled." -ForegroundColor Red
    exit;
}

Write-Host "Setting Alerts to $AlertStatus"

# UPDATE URI to your AAA Runbook Webhook URL
$uri = "https://a51a94bc-127a-4afa-97bc-789b0b75e425.webhook.wus2.azure-automation.net/webhooks?token=iTDKGJ1TPVPXKFb2pE67qO7bC7AiTsvBwxgxrz1yxh4%3d"

$body = ConvertTo-Json -InputObject $data
$header = @{ message="StartedbyDZ"}
$response = Invoke-WebRequest -Method Post -Uri $uri -Body $body -Headers $header
$jobid = (ConvertFrom-Json ($response.Content)).jobids[0]