# Variables - update these as needed
$resourceGroup = "ajha-test-rg"
$location = "westus2"
$keyVaultName = "ajha-test-newkv"

# Create resource group if it doesn't exist
if (-not (Get-AzResourceGroup -Name $resourceGroup -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $resourceGroup -Location $location
}

# Create Key Vault
$keyVault = New-AzKeyVault -Name $keyVaultName -ResourceGroupName $resourceGroup -Location $location

# Disable public network access
Update-AzKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroup -PublicNetworkAccess "Disabled"

# Allow trusted Microsoft services to bypass the firewall
$properties = @{
    bypass = "AzureServices"
    defaultAction = "Deny"
}
Set-AzKeyVaultNetworkRuleSet -VaultName $keyVaultName -ResourceGroupName $resourceGroup @properties

Write-Host "Key Vault created, public access disabled, and trusted Microsoft services allowed."