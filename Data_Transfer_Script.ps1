param (
    [Parameter(Mandatory = $true)]
    [string]$teacher,

    [Parameter(Mandatory = $true)]
    [string]$oldPC
)

# Variables
$baseSource = "\\$oldPC\C$\Users\$teacher"
$baseDestination = "C:\Users\$teacher"
$folders = @("Downloads", "Documents", "Desktop", "Pictures")
$globalLog = "C:\Logs\$teacher-transfer-summary.log"
$sizeThresholdGB = 4
$maxAgeDays = 730

# Ensure Logs directory exists
if (!(Test-Path -Path "C:\Logs")) {
    New-Item -ItemType Directory -Path "C:\Logs" | Out-Null
}

# Function: Check old PC connectivity
function Test-OldPCConnection {
    Write-Host "Checking if $oldPC is online..."
    if (Test-Connection -ComputerName $oldPC -Count 1 -Quiet) {
        Write-Host "$oldPC is reachable.`n"
        return $true
    } else {
        Write-Host "$oldPC is NOT reachable.`n"
        "$(Get-Date): ERROR - $oldPC not reachable." | Out-File -Append $globalLog
        return $false
    }
}

# Function: Get folder size safely
function Get-FolderSizeGB($path) {
    try {
        $bytes = (Get-ChildItem $path -Recurse -File -ErrorAction Stop | Measure-Object -Property Length -Sum).Sum
        return [math]::Round($bytes / 1GB, 2)
    } catch {
        "$(Get-Date): ERROR accessing $path - $_" | Out-File -Append $globalLog
        return $null
    }
}

# Main execution
if (Test-OldPCConnection) {
    foreach ($folder in $folders) {
        $source = Join-Path $baseSource $folder
        $destination = Join-Path $baseDestination $folder
        $logPath = "C:\Logs\$teacher-$folder.log"

        Write-Host "Checking existence: $source"
        if (!(Test-Path $source)) {
            "$(Get-Date): WARNING - $folder not found on $oldPC." | Out-File -Append $globalLog
            continue
        }

        # Calculate folder size
        $folderSizeGB = Get-FolderSizeGB $source
        if ($null -eq $folderSizeGB) {
            "$(Get-Date): ERROR - Could not calculate size for $folder. Skipping." | Out-File -Append $globalLog
            continue
        }

        Write-Host "Processing $folder ($folderSizeGB GB)..."
        $startTime = Get-Date
        $copiedCount = 0

        # 1st Priority: Copy subfolders/files (with timestamp checks)
        Get-ChildItem $source -Directory -Recurse | ForEach-Object {
            $relativeSubfolder = $_.FullName.Substring($source.Length).TrimStart("\")
            $targetSubfolderPath = Join-Path $destination $relativeSubfolder

            if (!(Test-Path $targetSubfolderPath)) {
                New-Item -Path $targetSubfolderPath -ItemType Directory -Force | Out-Null
            }

            Get-ChildItem $_.FullName -Recurse -File | ForEach-Object {
                $subRelativeFile = $_.FullName.Substring($source.Length).TrimStart("\")
                $subFileTarget = Join-Path $destination $subRelativeFile
                if (!(Test-Path (Split-Path $subFileTarget))) {
                    New-Item -Path (Split-Path $subFileTarget) -ItemType Directory -Force | Out-Null
                }

                $shouldCopy = $true
                if (Test-Path $subFileTarget) {
                    $targetFile = Get-Item $subFileTarget
                    if ($_.LastWriteTime -le $targetFile.LastWriteTime) {
                        $shouldCopy = $false
                        "$(Get-Date): Skipped (folder - newer or same): $($_.FullName)" | Out-File -Append $logPath
                    }
                }

                if ($shouldCopy) {
                    Copy-Item $_.FullName -Destination $subFileTarget -Force
                    "$(Get-Date): Copied (folder): $($_.FullName) -> $subFileTarget" | Out-File -Append $logPath
                    $copiedCount++
                }
            }
        }

        # 2nd Priority: Conditionally copy root-level files
        $cutoffDate = (Get-Date).AddDays(-$maxAgeDays)
        if ($folderSizeGB -ge $sizeThresholdGB) {
            Write-Host "Copying root-level files modified within last $maxAgeDays days only..."
            $rootFiles = Get-ChildItem $source -File | Where-Object { $_.LastWriteTime -gt $cutoffDate }
        } else {
            Write-Host "Copying all root-level files..."
            $rootFiles = Get-ChildItem $source -File
        }

        foreach ($file in $rootFiles) {
            $relativeFilePath = $file.Name
            $targetFilePath = Join-Path $destination $relativeFilePath

            $shouldCopy = $true
            if (Test-Path $targetFilePath) {
                $targetFile = Get-Item $targetFilePath
                if ($file.LastWriteTime -le $targetFile.LastWriteTime) {
                    $shouldCopy = $false
                    "$(Get-Date): Skipped (root - newer or same): $($file.FullName)" | Out-File -Append $logPath
                }
            }

            if ($shouldCopy) {
                Copy-Item $file.FullName -Destination $targetFilePath -Force
                "$(Get-Date): Copied (root): $($file.FullName) -> $targetFilePath" | Out-File -Append $logPath
                $copiedCount++
            }
        }

        $elapsedTime = (Get-Date) - $startTime
        "$(Get-Date): Completed $folder transfer - $copiedCount items copied in $([math]::Round($elapsedTime.TotalMinutes,2)) minutes." | Out-File -Append $globalLog
    }

    Write-Host "Transfer complete. Logs saved to: $globalLog"
}

Read-Host -Prompt "Press Enter to close"
