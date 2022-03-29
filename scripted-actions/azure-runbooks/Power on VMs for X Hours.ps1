#description: Get all VMs in host pool and set scale in restriction tag for X hours (default 24 hours). 
#tags: Nerdio, Preview

<# Notes:

This script will turn on all VMs in a host pool, and ensure that Nerdio does not turn the VMs off again until
X hours have passed. The number of hours is defined by the $RestrictScaleInForHours variable below, which defaults
to 24. To use a different duration for the scale in restriction, clone this script and modify the variable below.

#>
<# Variables:
{
  "HostPoolId": {
    "Description": "Full Id of the host pool, e.g. /subscriptions/XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX/resourceGroups/host-pool-rg/providers/Microsoft.DesktopVirtualization/hostpools/HostPoolName",
    "IsRequired": true,
    "DefaultValue": ""
  },
  "RestrictScaleInForHours": {
    "Description": "Number of hours (from now) to prevent power off via scale-in processes",
    "IsRequired": true,
    "DefaultValue": "24"
  }
}
#>

# Ensure correct subscription context is selected
Set-AzContext -SubscriptionId $AzureSubscriptionID

$ErrorActionPreference = Stop

$Prefix = ($KeyVaultName -split '-')[0].ToUpper()

# Get hostpool resource group
$HostPool = Get-AzResource -ResourceId $HostpoolID
$HostPoolRG = $HostPool.ResourceGroupName
$HostPoolName = $Hostpool.Name

# Parse the VM names from the host names
$VmNames = (Get-AzWvdSessionHost -HostPoolName $HostPoolName -ResourceGroupName $HostPoolRG).name | ForEach-Object {($_ -replace "$HostPoolName/",'' -split '\.')[0]}

$VMs = $VmNames | ForEach-Object {Get-AzVM -Name $_ }
$RestrictUntil = (Get-Date).AddHours([int]$RestrictScaleInForHours)
$TimeZoneId = (Get-TimeZone).id

foreach ($VM in $VMs) {
    $tags = $vm.tags

    # Set the scale in restriction tag to prevent Nerdio from turning the VMs off
    $tags["$Prefix`_SCALE_IN_RESTRICTION"] = $RestrictUntil.ToString("yyyy-MM-ddTHH") + ";$TimeZoneId"
    Set-AzResource -ResourceGroupName $vm.ResourceGroupName -Name $vm.name -ResourceType "Microsoft.Compute/VirtualMachines" -Tag $tags -Force 
}

$VMs | Start-AzVM 