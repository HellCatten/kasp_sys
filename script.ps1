<#
.SYNOPSIS
    Скрипт сбора системной информации
.DESCRIPTION
    Собирает данные об ОС, дисках, ресурсоемких процессах и проблемных службах
#>

# 1. Формирование имени отчета по ТЗ
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm"
$reportFileName = "Report_$timestamp.txt"

# Сохраняем в текущую папку запуска
$currentDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$reportPath = Join-Path -Path $currentDir -ChildPath $reportFileName

# Инициализация списка строк для отчета
$report = [System.Collections.Generic.List[string]]::new()

function Add-Header {
    param([string]$Title)
    $report.Add("=" * 65)
    $report.Add(" $Title")
    $report.Add("=" * 65)
}

# 2. Имя компьютера и версия ОС
Add-Header "1. Имя компьютера и версия ОС"
$os = Get-CimInstance -ClassName Win32_OperatingSystem
$report.Add("Computer Name: $($os.CSName)")
$report.Add("OS Name:       $($os.Caption)")
$report.Add("OS Version:    $($os.Version) (Build $($os.BuildNumber))")
$report.Add("")

# 3. Информация о дисках
Add-Header "2. Информация о дисках"
$disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType = 3" | ForEach-Object {
    $total = [math]::Round($_.Size / 1GB, 2)
    $free  = [math]::Round($_.FreeSpace / 1GB, 2)
    $percent = if ($_.Size -gt 0) { [math]::Round(($_.FreeSpace / $_.Size) * 100, 2) } else { 0 }

    [PSCustomObject]@{
        "Drive"          = $_.DeviceID
        "Total_GB"       = $total
        "Free_GB"        = $free
        "Free_Percent"   = "$percent%"
    }
}

$disksTable = $disks | Format-Table -AutoSize | Out-String
$report.Add($disksTable.Trim())
$report.Add("")

# 4. Топ-5 процессов по потреблению памяти
Add-Header "3. Топ 5 процессов по потреблению памяти"
$topProcesses = Get-Process | 
    Sort-Object -Property WorkingSet64 -Descending | 
    Select-Object -First 5 | 
    Select-Object -Property Id, ProcessName, @{Name="RAM_MB"; Expression={[math]::Round($_.WorkingSet64 / 1MB, 2)}}

$procTable = $topProcesses | Format-Table -AutoSize | Out-String
$report.Add($procTable.Trim())
$report.Add("")

# 5. Службы: тип запуска Automatic, но статус Stopped
Add-Header "4. Сервисы: AUTOMATIC, но STOPPED"
$problemServices = Get-Service | 
    Where-Object { $_.StartType -eq 'Automatic' -and $_.Status -eq 'Stopped' } | 
    Select-Object -Property Name, DisplayName, Status, StartType

if ($problemServices) {
    $servTable = $problemServices | Format-Table -AutoSize | Out-String
    $report.Add($servTable.Trim())
} else {
    $report.Add("No stopped automatic services found.")
}
$report.Add("")

# 6. Сохранение файла в кодировке UTF-8
$report | Out-File -FilePath $reportPath -Encoding utf8

Write-Host "Отчет успешно загружен: $reportPath" -ForegroundColor Green