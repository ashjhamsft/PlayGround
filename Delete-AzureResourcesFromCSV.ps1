#Requires -Modules Az.Accounts, Az.Resources
<#
.SYNOPSIS
    Deletes Azure resources based on resource IDs provided in a CSV file.

.DESCRIPTION
    This script reads resource IDs from a CSV file and deletes the corresponding Azure resources.
    It includes proper error handling, logging, confirmation prompts, and follows Azure security best practices.

.PARAMETER CsvFilePath
    Path to the CSV file containing resource IDs. The CSV should have a column named 'ResourceId'.

.PARAMETER WhatIf
    Shows what would be deleted without actually performing the deletion.

.PARAMETER Force
    Bypasses confirmation prompts for deletion.

.PARAMETER LogPath
    Path to the log file. Defaults to a timestamped file in the current directory.

.PARAMETER MaxRetries
    Maximum number of retry attempts for failed deletions. Default is 3.

.EXAMPLE
    .\Delete-AzureResourcesFromCSV.ps1 -CsvFilePath "resources_to_delete.csv"
    
.EXAMPLE
    .\Delete-AzureResourcesFromCSV.ps1 -CsvFilePath "resources_to_delete.csv" -WhatIf
    
.EXAMPLE
    .\Delete-AzureResourcesFromCSV.ps1 -CsvFilePath "resources_to_delete.csv" -Force -LogPath "deletion_log.txt"

.NOTES
    Author: GitHub Copilot
    Version: 1.0
    Requires: Az PowerShell modules (Az.Accounts, Az.Resources)
    
    CSV Format Expected:
    ResourceId
    /subscriptions/sub-id/resourceGroups/rg-name/providers/Microsoft.Storage/storageAccounts/storage-name
    /subscriptions/sub-id/resourceGroups/rg-name/providers/Microsoft.Web/sites/webapp-name
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $true)]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Leaf)) {
            throw "CSV file not found: $_"
        }
        if (-not ($_ -match '\.csv$')) {
            throw "File must be a CSV file: $_"
        }
        return $true
    })]
    [string]$CsvFilePath,
    
    [Parameter()]
    [switch]$Force,
    
    [Parameter()]
    [string]$LogPath = "Azure_Resource_Deletion_$(Get-Date -Format 'yyyyMMdd_HHmmss').log",
    
    [Parameter()]
    [ValidateRange(1, 10)]
    [int]$MaxRetries = 3
)

# Initialize logging
function Write-Log {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter()]
        [ValidateSet('INFO', 'WARN', 'ERROR', 'SUCCESS')]
        [string]$Level = 'INFO'
    )
    
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Write to console with appropriate color
    switch ($Level) {
        'INFO' { Write-Host $logEntry -ForegroundColor Cyan }
        'WARN' { Write-Warning $logEntry }
        'ERROR' { Write-Error $logEntry }
        'SUCCESS' { Write-Host $logEntry -ForegroundColor Green }
    }
    
    # Write to log file
    Add-Content -Path $LogPath -Value $logEntry -Encoding UTF8
}

# Function to validate and parse resource ID
function Test-AzureResourceId {
    param([string]$ResourceId)
    
    if ([string]::IsNullOrWhiteSpace($ResourceId)) {
        return $false
    }
    
    # Basic Azure resource ID pattern validation
    $pattern = '^/subscriptions/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}/resourceGroups/.+/providers/.+/.+/.+$'
    return $ResourceId -match $pattern
}

# Function to delete resource with retry logic
function Remove-AzureResourceWithRetry {
    param(
        [string]$ResourceId,
        [int]$MaxRetries,
        [bool]$ForceDelete
    )
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-Log "Attempt $attempt/$MaxRetries - Deleting resource: $ResourceId"
            
            if ($WhatIfPreference) {
                Write-Log "WHAT-IF: Would delete resource: $ResourceId" -Level 'WARN'
                return $true
            }
            
            # Get resource information first to validate it exists
            $resource = Get-AzResource -ResourceId $ResourceId -ErrorAction Stop
            
            if (-not $resource) {
                Write-Log "Resource not found or already deleted: $ResourceId" -Level 'WARN'
                return $true
            }
            
            # Show confirmation unless Force is specified
            if (-not $ForceDelete -and -not $Force) {
                $confirmation = Read-Host "Delete resource '$($resource.Name)' of type '$($resource.ResourceType)'? (y/N)"
                if ($confirmation -notmatch '^[Yy]$') {
                    Write-Log "Skipped deletion of resource: $ResourceId" -Level 'WARN'
                    return $true
                }
            }
            
            # Perform the deletion
            Remove-AzResource -ResourceId $ResourceId -Force -ErrorAction Stop
            
            # Verify deletion
            Start-Sleep -Seconds 2
            $verifyResource = Get-AzResource -ResourceId $ResourceId -ErrorAction SilentlyContinue
            if ($verifyResource) {
                throw "Resource still exists after deletion attempt"
            }
            
            Write-Log "Successfully deleted resource: $ResourceId" -Level 'SUCCESS'
            return $true
        }
        catch {
            $errorMessage = $_.Exception.Message
            Write-Log "Attempt $attempt failed for resource $ResourceId : $errorMessage" -Level 'ERROR'
            
            if ($attempt -eq $MaxRetries) {
                Write-Log "Failed to delete resource after $MaxRetries attempts: $ResourceId" -Level 'ERROR'
                return $false
            }
            
            # Exponential backoff
            $waitTime = [Math]::Pow(2, $attempt) * 5
            Write-Log "Waiting $waitTime seconds before retry..." -Level 'WARN'
            Start-Sleep -Seconds $waitTime
        }
    }
    
    return $false
}

# Main execution
try {
    Write-Log "Starting Azure resource deletion script"
    Write-Log "CSV File: $CsvFilePath"
    Write-Log "Log File: $LogPath"
    Write-Log "WhatIf Mode: $WhatIfPreference"
    Write-Log "Force Mode: $Force"
    
    # Check if connected to Azure
    $context = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $context) {
        Write-Log "Not connected to Azure. Please run Connect-AzAccount first." -Level 'ERROR'
        exit 1
    }
    
    Write-Log "Connected to Azure - Subscription: $($context.Subscription.Name) ($($context.Subscription.Id))"
    
    # Read and validate CSV file
    Write-Log "Reading CSV file: $CsvFilePath"
    
    try {
        $csvData = Import-Csv -Path $CsvFilePath -ErrorAction Stop
    }
    catch {
        Write-Log "Failed to read CSV file: $($_.Exception.Message)" -Level 'ERROR'
        exit 1
    }
    
    # Validate CSV structure
    if (-not $csvData -or $csvData.Count -eq 0) {
        Write-Log "CSV file is empty or invalid" -Level 'ERROR'
        exit 1
    }
    
    # Check for ResourceId column
    $resourceIdColumn = $csvData[0].PSObject.Properties.Name | Where-Object { $_ -match '^ResourceId$|^Resource.*Id$' }
    if (-not $resourceIdColumn) {
        Write-Log "CSV file must contain a 'ResourceId' column. Found columns: $($csvData[0].PSObject.Properties.Name -join ', ')" -Level 'ERROR'
        exit 1
    }
    
    Write-Log "Found $($csvData.Count) entries in CSV file"
    Write-Log "Using column: $resourceIdColumn"
    
    # Extract and validate resource IDs
    $resourceIds = @()
    $invalidIds = @()
    
    foreach ($row in $csvData) {
        $resourceId = $row.$resourceIdColumn
        if (Test-AzureResourceId -ResourceId $resourceId) {
            $resourceIds += $resourceId
        }
        else {
            $invalidIds += $resourceId
            Write-Log "Invalid resource ID format: $resourceId" -Level 'WARN'
        }
    }
    
    if ($invalidIds.Count -gt 0) {
        Write-Log "Found $($invalidIds.Count) invalid resource ID(s). Check the log for details." -Level 'WARN'
    }
    
    if ($resourceIds.Count -eq 0) {
        Write-Log "No valid resource IDs found in CSV file" -Level 'ERROR'
        exit 1
    }
    
    Write-Log "Found $($resourceIds.Count) valid resource ID(s) to process"
    
    # Show summary and get final confirmation
    if (-not $WhatIfPreference -and -not $Force) {
        Write-Host "`nSUMMARY:" -ForegroundColor Yellow
        Write-Host "- Resources to delete: $($resourceIds.Count)" -ForegroundColor Yellow
        Write-Host "- Invalid IDs skipped: $($invalidIds.Count)" -ForegroundColor Yellow
        Write-Host "- Subscription: $($context.Subscription.Name)" -ForegroundColor Yellow
        
        $finalConfirmation = Read-Host "`nProceed with deletion? Type 'DELETE' to confirm"
        if ($finalConfirmation -ne 'DELETE') {
            Write-Log "Operation cancelled by user" -Level 'WARN'
            exit 0
        }
    }
    
    # Process deletions
    Write-Log "Starting resource deletion process..."
    $successCount = 0
    $failureCount = 0
    $results = @()
    
    foreach ($resourceId in $resourceIds) {
        $success = Remove-AzureResourceWithRetry -ResourceId $resourceId -MaxRetries $MaxRetries -ForceDelete $Force
        
        $results += [PSCustomObject]@{
            ResourceId = $resourceId
            Status = if ($success) { 'Success' } else { 'Failed' }
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        }
        
        if ($success) {
            $successCount++
        }
        else {
            $failureCount++
        }
    }
    
    # Generate summary report
    Write-Log "`n=== DELETION SUMMARY ===" -Level 'INFO'
    Write-Log "Total resources processed: $($resourceIds.Count)" -Level 'INFO'
    Write-Log "Successfully deleted: $successCount" -Level 'SUCCESS'
    Write-Log "Failed deletions: $failureCount" -Level $(if ($failureCount -gt 0) { 'ERROR' } else { 'INFO' })
    Write-Log "Invalid IDs skipped: $($invalidIds.Count)" -Level 'INFO'
    
    # Export results to CSV
    $resultsCsvPath = "Deletion_Results_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $results | Export-Csv -Path $resultsCsvPath -NoTypeInformation -Encoding UTF8
    Write-Log "Results exported to: $resultsCsvPath" -Level 'INFO'
    
    Write-Log "Script completed. Check log file for details: $LogPath"
    
    # Exit with appropriate code
    if ($failureCount -gt 0) {
        exit 1
    }
    else {
        exit 0
    }
}
catch {
    Write-Log "Script execution failed: $($_.Exception.Message)" -Level 'ERROR'
    Write-Log "Stack trace: $($_.ScriptStackTrace)" -Level 'ERROR'
    exit 1
}
