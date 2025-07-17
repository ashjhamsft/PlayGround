# Azure Resource Deletion Script

This PowerShell script reads Azure resource IDs from a CSV file and safely deletes those resources with proper error handling, logging, and confirmation prompts.

## Prerequisites

1. **Azure PowerShell Modules**: Install the required modules
   ```powershell
   Install-Module -Name Az.Accounts, Az.Resources -Force -AllowClobber
   ```

2. **Azure Authentication**: Connect to your Azure account
   ```powershell
   Connect-AzAccount
   
   # Optional: Select specific subscription
   Set-AzContext -SubscriptionId "your-subscription-id"
   ```

## CSV File Format

Create a CSV file with a `ResourceId` column containing the full Azure resource IDs:

```csv
ResourceId
/subscriptions/sub-id/resourceGroups/rg-name/providers/Microsoft.Storage/storageAccounts/storage-name
/subscriptions/sub-id/resourceGroups/rg-name/providers/Microsoft.Web/sites/webapp-name
```

## Usage Examples

### 1. Basic Usage (with confirmation prompts)
```powershell
.\Delete-AzureResourcesFromCSV.ps1 -CsvFilePath "resources_to_delete.csv"
```

### 2. What-If Mode (preview what would be deleted)
```powershell
.\Delete-AzureResourcesFromCSV.ps1 -CsvFilePath "resources_to_delete.csv" -WhatIf
```

### 3. Force Mode (skip confirmation prompts)
```powershell
.\Delete-AzureResourcesFromCSV.ps1 -CsvFilePath "resources_to_delete.csv" -Force
```

### 4. Custom Log Path
```powershell
.\Delete-AzureResourcesFromCSV.ps1 -CsvFilePath "resources_to_delete.csv" -LogPath "custom_deletion_log.txt"
```

### 5. Adjust Retry Logic
```powershell
.\Delete-AzureResourcesFromCSV.ps1 -CsvFilePath "resources_to_delete.csv" -MaxRetries 5
```

## Script Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `CsvFilePath` | String | Yes | Path to the CSV file containing resource IDs |
| `WhatIf` | Switch | No | Preview mode - shows what would be deleted without performing deletion |
| `Force` | Switch | No | Bypass confirmation prompts |
| `LogPath` | String | No | Custom log file path (default: timestamped file) |
| `MaxRetries` | Int | No | Maximum retry attempts for failed deletions (default: 3) |

## Features

### ✅ Safety Features
- **Validation**: Validates Azure resource ID format
- **Confirmation**: Multiple confirmation prompts (unless `-Force` is used)
- **What-If Mode**: Preview mode to see what would be deleted
- **Verification**: Checks if resources exist before deletion

### ✅ Error Handling & Reliability
- **Retry Logic**: Exponential backoff for transient failures
- **Comprehensive Logging**: Detailed logs with timestamps and levels
- **Error Recovery**: Continues processing even if individual deletions fail
- **Results Export**: Exports results to CSV for audit trail

### ✅ Monitoring & Reporting
- **Progress Tracking**: Real-time progress updates
- **Color-coded Output**: Different colors for different message types
- **Summary Report**: Detailed summary with success/failure counts
- **Audit Trail**: Complete log of all operations

## How to Get Resource IDs

### Method 1: Azure Portal
1. Navigate to the resource in Azure Portal
2. Go to **Properties** or **Overview**
3. Copy the **Resource ID**

### Method 2: Azure CLI
```bash
# List all resources in a resource group
az resource list --resource-group "your-rg-name" --query "[].id" -o tsv

# List specific resource type
az storage account list --query "[].id" -o tsv
```

### Method 3: PowerShell
```powershell
# List all resources in a resource group
Get-AzResource -ResourceGroupName "your-rg-name" | Select-Object ResourceId

# List specific resource type
Get-AzStorageAccount | Select-Object @{Name="ResourceId";Expression={$_.Id}}
```

## Security Considerations

- **Authentication**: Uses your current Azure PowerShell session
- **Permissions**: Requires appropriate RBAC permissions to delete resources
- **Logging**: All operations are logged for audit purposes
- **Confirmation**: Multiple safety checks to prevent accidental deletions

## Troubleshooting

### Common Issues

1. **"Not connected to Azure"**
   ```powershell
   Connect-AzAccount
   ```

2. **"Permission denied"**
   - Ensure you have **Contributor** or **Owner** role on the resources
   - Check if resources are locked

3. **"Invalid resource ID format"**
   - Verify the resource ID follows the correct format
   - Check for extra spaces or special characters

4. **"Resource not found"**
   - Resource may have already been deleted
   - Verify the subscription and resource group exist

### Exit Codes
- `0`: Success (all resources processed successfully)
- `1`: Failure (one or more errors occurred)

## Output Files

The script generates the following files:
- **Log File**: `Azure_Resource_Deletion_YYYYMMDD_HHMMSS.log`
- **Results CSV**: `Deletion_Results_YYYYMMDD_HHMMSS.csv`

## Best Practices

1. **Always test first**: Use `-WhatIf` mode before actual deletion
2. **Backup important data**: Ensure you have backups before deletion
3. **Review permissions**: Verify you have appropriate access
4. **Check dependencies**: Some resources may have dependencies
5. **Use resource locks**: Consider using locks for critical resources

## Support

For issues or questions, refer to the Azure PowerShell documentation:
- [Azure PowerShell Documentation](https://docs.microsoft.com/en-us/powershell/azure/)
- [Azure Resource Manager](https://docs.microsoft.com/en-us/azure/azure-resource-manager/)
