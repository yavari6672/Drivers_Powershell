# PowerShell Script to Process .inf Files Securely with Enhanced Validation and Verbose Output

param (
    [ValidateSet('All', 'hwid', 'DriverVer', 'Provider')]
    [string]$type_report,

    [string]$drivers_path_input,

    [ValidateSet('txt', 'Clixml', 'All')]
    [string]$file_type_export = 'All',

    [int]$Last_modified_date = 0,

    [switch]$v, # Verbose switch
    [switch]$h  # Help switch
)

# Display Help if -h is specified or no parameters are passed
if ($h -or -not $PSBoundParameters.Count) {
    Write-Host "Usage: .\script.ps1 -type_report [All|hwid|DriverVer|Provider] -drivers_path_input [path] -file_type_export [txt|Clixml|All] -Last_modified_date [days] -v -h" -ForegroundColor Cyan
    Write-Host "- type_report: Type of report to generate (All, hwid, DriverVer, Provider)" -ForegroundColor White
    Write-Host "- drivers_path_input: Path to the directory containing .inf files" -ForegroundColor White
    Write-Host "- file_type_export: Export format (txt, Clixml, All)" -ForegroundColor White
    Write-Host "- Last_modified_date: Number of days to filter files by last modified date (0 for all)" -ForegroundColor White
    Write-Host "- v: Enable verbose output" -ForegroundColor White
    Write-Host "- h: Display this help message" -ForegroundColor White
    return
}

# Validate drivers path input
if (-not $drivers_path_input) {
    Write-Host "Error: 'drivers_path_input' cannot be empty." -ForegroundColor Red
    exit
}

# Function to Process Individual .inf Files
function Process_InfFile {
    param (
        [string]$inf_file_FullName,
        [string]$inf_file_BaseName,
        [string]$type_report,
        [string]$file_type_export,
        [string]$output_path,
        [string]$csvFile,
        [string]$logFile
    )

    $infverif = "infverif.exe"
    $target = "$infverif /info '$inf_file_FullName'"

    # Modify command based on report type
    if ($type_report -ne 'All') {
        $target += " | Select-String -Pattern '$type_report'"
    }

    # Export based on file type
    switch ($file_type_export) {
        'txt' { $target += " | Out-File '$output_path\$inf_file_BaseName.txt'" }
        'Clixml' { $target += " | Export-Clixml '$output_path\$inf_file_BaseName.Clixml'" }
        'All' { $target += " | Tee-Object '$output_path\$inf_file_BaseName.txt' | Export-Clixml '$output_path\$inf_file_BaseName.Clixml'" }
    }

   
    $folderName = (Get-Item $inf_file_FullName).Directory.Name
    $fileName = (Get-Item $inf_file_FullName).Name
    $path = Split-Path $inf_file_FullName -Parent

    try {
        Invoke-Expression $target 
        "Processed,$folderName,$fileName,$inf_file_BaseName.Clixml,$path" | Add-Content -Path $csvFile
        Add-Content -Path $logFile -Value "Processed: $inf_file_FullName"
        if ($v) { Write-Host "Processed: $inf_file_FullName" -ForegroundColor Green }
    }
    catch {
        "Failed,$folderName,$fileName,$inf_file_BaseName.Clixml,$path" | Add-Content -Path $csvFile
        Add-Content -Path $logFile -Value "Failed: $inf_file_FullName"
        if ($v) { Write-Host "Failed to process: $inf_file_FullName" -ForegroundColor Red }
    }
        
    
}

# Main Script Execution
try {
    # Validate path
    if (-Not (Test-Path -PathType Container $drivers_path_input)) {
        throw "Invalid path: $drivers_path_input"
    }

    # Create output directory
    $output_path = Join-Path -Path (Get-Location).Path -ChildPath 'drivers_info'
    if (Test-Path -PathType Container $output_path) {
        Remove-Item -LiteralPath $output_path -Force -Recurse
    }
    New-Item -ItemType Directory -Path $output_path | Out-Null

 

    $csvFile = "$(Get-Location)\processed_files.csv"
    New-Item -Path $csvFile -ItemType File -Force
    Add-Content -Path $csvFile -Value "Status,Folder,Inf,Clixml,Path"


    $logFile = "$(Get-Location)\processed_files.log"
    New-Item -Path $logFile -ItemType File -Force
    Add-Content -Path $logFile -Value "Log initialized: $(Get-Date)"  

    

    # Retrieve .inf files from the specified path
    $inf_files = Get-ChildItem -Path $drivers_path_input -Recurse -Filter '*.inf'


    # Process each .inf file
    foreach ($inf_file in $inf_files) {
        # Check for last modified date if specified
        if ($Last_modified_date -eq 0 -or $inf_file.LastWriteTime -ge (Get-Date).AddDays(-$Last_modified_date)) {
            Process_InfFile -inf_file_FullName $inf_file.FullName -inf_file_BaseName $inf_file.BaseName  -type_report $type_report -file_type_export $file_type_export -output_path $output_path   -csvFile $csvFile  -logFile $logFile
        }
    }

    

    Write-Host "Processing completed." -ForegroundColor Cyan
}
catch {
    Write-Host "An error occurred: $_" -ForegroundColor Red
}
