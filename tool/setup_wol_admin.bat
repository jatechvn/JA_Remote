@echo off
setlocal EnableExtensions
chcp 65001 >nul
title JA Remote - HP BIOS Check and WoL Optimizer [Admin]

set "AUTO_MODE=0"
if /I "%~1"=="--auto" set "AUTO_MODE=1"

set "SCRIPT_PATH=%~f0"
set "SCRIPT_ARGS="
if "%AUTO_MODE%"=="1" set "SCRIPT_ARGS=--auto"

net session >nul 2>&1
if errorlevel 1 goto :need_elevation

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; try { $raw = [System.IO.File]::ReadAllText($env:SCRIPT_PATH, [System.Text.Encoding]::UTF8); $m = [regex]::Match($raw, '(?m)^:: __POWERSHELL_' + 'PAYLOAD__\r?\n'); if (-not $m.Success) { throw 'PowerShell payload marker not found.' }; $code = $raw.Substring($m.Index + $m.Length); $sb = [scriptblock]::Create($code); $global:LASTEXITCODE = 0; & $sb -ScriptPath $env:SCRIPT_PATH -AutoMode ($env:AUTO_MODE -eq '1'); exit $LASTEXITCODE } catch { Write-Error $PSItem.Exception.Message; exit 1 }"
set "EXIT_CODE=%errorlevel%"

if "%AUTO_MODE%"=="0" goto :pause_done
exit /b %EXIT_CODE%

:pause_done
echo.
pause
exit /b %EXIT_CODE%

:need_elevation
echo [JA-WOL] Dang xin quyen Administrator qua Windows UAC...
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "try { $q = [char]34; $sp = $env:SCRIPT_PATH; $sa = $env:SCRIPT_ARGS; $arg = if ([string]::IsNullOrWhiteSpace($sa)) { '/s /c ' + $q + $q + $sp + $q + $q } else { '/s /c ' + $q + $q + $sp + $q + ' ' + $sa + $q }; $p = Start-Process -FilePath $env:ComSpec -ArgumentList $arg -Verb RunAs -Wait -PassThru -ErrorAction Stop; exit $p.ExitCode } catch { Write-Error $PSItem.Exception.Message; exit 5 }"
set "ELEV_RC=%errorlevel%"
if %ELEV_RC% neq 0 echo [JA-WOL] Khong the lay quyen Administrator [ExitCode=%ELEV_RC%]. Hay nhan Yes tren hop thoai UAC hoac Run as Administrator.
exit /b %ELEV_RC%

:: __POWERSHELL_PAYLOAD__
param(
    [string]$ScriptPath = '',
    [bool]$AutoMode = $false
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$scriptDir = if ($ScriptPath) { Split-Path -Path $ScriptPath -Parent } else { (Get-Location).Path }
$parentDir = Split-Path -Path $scriptDir -Parent
if ((Split-Path -Path $scriptDir -Leaf) -ieq 'tool' -and $parentDir) {
    $logDir = Join-Path $parentDir 'logs'
} else {
    $logDir = $scriptDir
}
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir 'wol_setup_report.log'

$logLines = New-Object 'System.Collections.Generic.List[string]'
function Write-Log {
    param([string]$Message = '')
    Write-Host $Message
    $logLines.Add($Message)
}

function Write-Section {
    param([string]$Title)
    Write-Log ''
    Write-Log ('=' * 72)
    Write-Log $Title
    Write-Log ('=' * 72)
}

function Set-NicPropIfPresent {
    param(
        [string]$AdapterName,
        [string]$RegistryKeyword,
        [int]$TargetValue,
        [string]$Label
    )
    $prop = Get-NetAdapterAdvancedProperty -Name $AdapterName -IncludeHidden -RegistryKeyword $RegistryKeyword -ErrorAction SilentlyContinue
    if ($null -eq $prop) {
        return
    }
    $currentVal = ($prop.RegistryValue -join ',')
    $targetStr = "$TargetValue"
    if ($currentVal -eq $targetStr) {
        Write-Log ("  [OK] {0} ({1}): Da la '{2}' ({3})" -f $Label, $RegistryKeyword, $prop.DisplayValue, $currentVal)
        return
    }
    if ($prop.ValidRegistryValues -and ($prop.ValidRegistryValues -notcontains $targetStr)) {
        Write-Log ("  [SKIP] {0} ({1}): Gia tri '{2}' khong nam trong ValidRegistryValues=({3})" -f $Label, $RegistryKeyword, $targetStr, ($prop.ValidRegistryValues -join ', '))
        return
    }
    try {
        Set-NetAdapterAdvancedProperty -Name $AdapterName -IncludeHidden -RegistryKeyword $RegistryKeyword -RegistryValue $targetStr -NoRestart -ErrorAction Stop
        $after = Get-NetAdapterAdvancedProperty -Name $AdapterName -IncludeHidden -RegistryKeyword $RegistryKeyword -ErrorAction SilentlyContinue
        Write-Log ("  [SET] {0} ({1}): {2} -> {3} ({4})" -f $Label, $RegistryKeyword, $prop.DisplayValue, $after.DisplayValue, ($after.RegistryValue -join ','))
    } catch {
        Write-Log ("  [WARN] Khong the dat {0} ({1}): {2}" -f $Label, $RegistryKeyword, $PSItem.Exception.Message)
    }
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

Write-Section 'JA REMOTE - HP BIOS CHECK & WAKE-ON-LAN OPTIMIZER'
Write-Log ("Timestamp : {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'))
Write-Log ("User      : {0} (IsAdmin={1})" -f [Security.Principal.WindowsIdentity]::GetCurrent().Name, $isAdmin)
Write-Log ("Report    : {0}" -f $logFile)

if (-not $isAdmin) {
    Write-Log '[ERROR] Script khong co quyen Administrator. Huy thao tac.'
    [System.IO.File]::WriteAllLines($logFile, $logLines, [System.Text.UTF8Encoding]::new($false))
    exit 5
}

$cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$bios = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
Write-Log ("Host      : {0} | {1} {2}" -f $cs.Name, $cs.Manufacturer, $cs.Model)
Write-Log ("BIOS      : {0} {1}" -f $bios.Manufacturer, $bios.SMBIOSBIOSVersion)
Write-Log ("OS        : {0} (Build {1})" -f $os.Caption, $os.BuildNumber)

# ------------------------------------------------------------------------
# LAYER 1: HP BIOS INSPECTION & SAFE AUTO-ENABLE
# ------------------------------------------------------------------------
Write-Section '[LAYER 1] KIEM TRA HP BIOS WMI (root\hp\instrumentedbios)'
$biosPasswordSet = $false
$biosCheckSupported = $false
$biosNeedsReboot = $false

try {
    $pwList = @(Get-CimInstance -Namespace root\hp\instrumentedbios -ClassName HP_BIOSPassword -ErrorAction Stop)
    if ($pwList.Count -gt 0) {
        $biosCheckSupported = $true
        foreach ($pw in $pwList) {
            Write-Log ("  BIOS Password [{0}]: IsSet = {1}" -f $pw.Name, $pw.IsSet)
            if ($pw.Name -eq 'Setup Password' -and [int]$pw.IsSet -ne 0) {
                $biosPasswordSet = $true
            }
        }
    }
} catch {
    Write-Log ("  [INFO] HP_BIOSPassword khong kha dung hoac khong ho tro: {0}" -f $PSItem.Exception.Message)
}

$hpBiosSettings = @()
try {
    $allBios = @(Get-CimInstance -Namespace root\hp\instrumentedbios -ClassName HP_BIOSSetting -ErrorAction Stop)
    $biosCheckSupported = $true
    $hpBiosSettings = @($allBios | Where-Object { $PSItem.Name -match 'Wake|LAN|S5|S4|Power|PME|PCI|Deep|ErP|NIC|Network|Embedded' })
    if ($hpBiosSettings.Count -eq 0) {
        Write-Log '  [INFO] Khong tim thay muc Wake/LAN/S5 trong HP_BIOSSetting.'
    } else {
        foreach ($b in $hpBiosSettings) {
            Write-Log ("  - {0} = [{1}]  (Possible: {2})" -f $b.Name, $b.CurrentValue, ($b.Value -replace '\s+', ' '))
        }
    }
} catch {
    Write-Log ("  [WARN] Khong the doc HP_BIOSSetting (nhieu dong HP Pro Tower 280 G9 dung AMI BIOS khong mo WMI): {0}" -f $PSItem.Exception.Message)
}

if ($biosCheckSupported -and $hpBiosSettings.Count -gt 0) {
    if ($biosPasswordSet) {
        Write-Log '  [WARN] BIOS Setup Password dang duoc dat -> Bo qua tu dong sua BIOS qua WMI.'
    } else {
        $biosIface = Get-CimInstance -Namespace root\hp\instrumentedbios -ClassName HP_BIOSSettingInterface -ErrorAction SilentlyContinue
        if ($null -ne $biosIface) {
            $s5Setting = $hpBiosSettings | Where-Object { $PSItem.Name -eq 'S5 Maximum Power Savings' } | Select-Object -First 1
            if ($null -ne $s5Setting -and $s5Setting.CurrentValue -match '^Enable') {
                try {
                    $res = Invoke-CimMethod -InputObject $biosIface -MethodName SetBIOSSetting -Arguments @{ Name = 'S5 Maximum Power Savings'; Value = 'Disable'; Password = '' } -ErrorAction Stop
                    Write-Log ("  [SET BIOS] S5 Maximum Power Savings -> Disable (Return={0})" -f $res.Return)
                    if ($res.Return -eq 0) { $biosNeedsReboot = $true }
                } catch {
                    Write-Log ("  [WARN] Loi sua BIOS S5 Maximum Power Savings: {0}" -f $PSItem.Exception.Message)
                }
            }

            $wolBiosSetting = $hpBiosSettings | Where-Object { $PSItem.Name -eq 'Wake On LAN' } | Select-Object -First 1
            if ($null -ne $wolBiosSetting -and $wolBiosSetting.CurrentValue -match '^Disable') {
                $targetBiosWol = if ($wolBiosSetting.PossibleValues -contains 'Boot to Hard Drive') {
                    'Boot to Hard Drive'
                } elseif ($wolBiosSetting.PossibleValues -contains 'Enable') {
                    'Enable'
                } elseif ($wolBiosSetting.PossibleValues -contains 'Boot to Normal Boot Order') {
                    'Boot to Normal Boot Order'
                } else {
                    $null
                }
                if ($null -ne $targetBiosWol) {
                    try {
                        $res = Invoke-CimMethod -InputObject $biosIface -MethodName SetBIOSSetting -Arguments @{ Name = 'Wake On LAN'; Value = $targetBiosWol; Password = '' } -ErrorAction Stop
                        Write-Log ("  [SET BIOS] Wake On LAN -> {0} (Return={1})" -f $targetBiosWol, $res.Return)
                        if ($res.Return -eq 0) { $biosNeedsReboot = $true }
                    } catch {
                        Write-Log ("  [WARN] Loi sua BIOS Wake On LAN: {0}" -f $PSItem.Exception.Message)
                    }
                }
            }
        }
    }
} else {
    Write-Log '  [NOTE] Neu can bat/xac nhan BIOS thu cong tren HP Pro Tower 280 G9 (AMI F.33): Nhan F10 khi boot -> Power Management -> Bat Wake On LAN / Power On by PCI-E & tat S5 ErP/Deep Sleep.'
}

# ------------------------------------------------------------------------
# LAYER 2 & 3: ADAPTER DISCOVERY & DRIVER + POWER OPTIMIZATION
# ------------------------------------------------------------------------
Write-Section '[LAYER 2 & 3] TOI UU CARD MANG ONBOARD PCIe & QUAN LY NGUON WINDOWS'

$pcieAdapters = @(Get-NetAdapter -IncludeHidden:$false | Where-Object {
    $PSItem.HardwareInterface -eq $true -and
    $PSItem.PhysicalMediaType -eq '802.3' -and
    $PSItem.PnPDeviceID -like 'PCI*'
})

$usbLanAdapters = @(Get-NetAdapter -IncludeHidden:$false | Where-Object {
    $PSItem.HardwareInterface -eq $true -and
    $PSItem.PhysicalMediaType -eq '802.3' -and
    $PSItem.PnPDeviceID -like 'USB*'
})

foreach ($u in $usbLanAdapters) {
    Write-Log ("  [INFO USB-LAN] {0} ({1}, MAC {2}): USB-LAN chi ho tro danh thuc tu Sleep S3, khong kich nguon tu Shutdown S5." -f $u.Name, $u.InterfaceDescription, $u.MacAddress)
}

if ($pcieAdapters.Count -eq 0) {
    Write-Log '[WARN] Khong tim thay card mang PCIe Ethernet nao!'
}

foreach ($adapter in $pcieAdapters) {
    Write-Log ''
    Write-Log ("--- Dang toi uu: {0} ({1}, MAC {2}, Status={3}) ---" -f $adapter.Name, $adapter.InterfaceDescription, $adapter.MacAddress, $adapter.Status)

    # Enable required WoL driver flags
    Set-NicPropIfPresent -AdapterName $adapter.Name -RegistryKeyword '*WakeOnMagicPacket' -TargetValue 1 -Label 'Wake on Magic Packet'
    Set-NicPropIfPresent -AdapterName $adapter.Name -RegistryKeyword 'S5WakeOnLan' -TargetValue 1 -Label 'Shutdown Wake-On-Lan'
    Set-NicPropIfPresent -AdapterName $adapter.Name -RegistryKeyword 'EnablePME' -TargetValue 1 -Label 'Enable PME'
    Set-NicPropIfPresent -AdapterName $adapter.Name -RegistryKeyword 'ReduceSpeedOnPowerDown' -TargetValue 1 -Label 'Reduce Speed On Power Down'
    Set-NicPropIfPresent -AdapterName $adapter.Name -RegistryKeyword 'WolShutdownLinkSpeed' -TargetValue 0 -Label 'WOL & Shutdown Link Speed (10 Mbps First)'

    # Disable unstable energy-saving & ghost pattern wake flags
    Set-NicPropIfPresent -AdapterName $adapter.Name -RegistryKeyword '*WakeOnPattern' -TargetValue 0 -Label 'Wake on pattern match (chong tu bat nham)'
    Set-NicPropIfPresent -AdapterName $adapter.Name -RegistryKeyword '*EEE' -TargetValue 0 -Label 'Energy-Efficient Ethernet'
    Set-NicPropIfPresent -AdapterName $adapter.Name -RegistryKeyword 'EEELinkAdvertisement' -TargetValue 0 -Label 'Intel EEE Link Advertisement'
    Set-NicPropIfPresent -AdapterName $adapter.Name -RegistryKeyword 'EnableGreenEthernet' -TargetValue 0 -Label 'Green Ethernet'
    Set-NicPropIfPresent -AdapterName $adapter.Name -RegistryKeyword 'GreenEthernet' -TargetValue 0 -Label 'Green Ethernet'
    Set-NicPropIfPresent -AdapterName $adapter.Name -RegistryKeyword 'PowerSavingMode' -TargetValue 0 -Label 'Power Saving Mode'
    Set-NicPropIfPresent -AdapterName $adapter.Name -RegistryKeyword 'ULPMode' -TargetValue 0 -Label 'Ultra Low Power Mode'

    # Windows NDIS Power Management: Allow Magic Packet only
    try {
        Set-NetAdapterPowerManagement -Name $adapter.Name -WakeOnMagicPacket Enabled -WakeOnPattern Disabled -NoRestart -ErrorAction Stop
        Write-Log ("  [SET PM] Set-NetAdapterPowerManagement: WakeOnMagicPacket=Enabled, WakeOnPattern=Disabled")
    } catch {
        Write-Log ("  [WARN] Set-NetAdapterPowerManagement loi: {0}" -f $PSItem.Exception.Message)
    }

    # Verify / reinforce WMI power wake flags
    try {
        $devEnable = Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceEnable -ErrorAction SilentlyContinue |
            Where-Object { $PSItem.InstanceName.StartsWith($adapter.PnPDeviceID, [System.StringComparison]::OrdinalIgnoreCase) }
        foreach ($inst in @($devEnable)) {
            if (-not $inst.Enable) {
                $inst | Set-CimInstance -Property @{ Enable = $true } -ErrorAction Stop
                Write-Log ("  [SET WMI] MSPower_DeviceEnable.Enable = True")
            } else {
                Write-Log ("  [OK WMI] MSPower_DeviceEnable.Enable = True")
            }
        }

        $wakeEnable = Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceWakeEnable -ErrorAction SilentlyContinue |
            Where-Object { $PSItem.InstanceName.StartsWith($adapter.PnPDeviceID, [System.StringComparison]::OrdinalIgnoreCase) }
        foreach ($inst in @($wakeEnable)) {
            if (-not $inst.Enable) {
                $inst | Set-CimInstance -Property @{ Enable = $true } -ErrorAction Stop
                Write-Log ("  [SET WMI] MSPower_DeviceWakeEnable.Enable = True")
            } else {
                Write-Log ("  [OK WMI] MSPower_DeviceWakeEnable.Enable = True")
            }
        }

        $magicOnly = Get-CimInstance -Namespace root\wmi -ClassName MSNdis_DeviceWakeOnMagicPacketOnly -ErrorAction SilentlyContinue |
            Where-Object { $PSItem.InstanceName -eq $adapter.InterfaceDescription -or $PSItem.InstanceName.StartsWith($adapter.PnPDeviceID, [System.StringComparison]::OrdinalIgnoreCase) }
        foreach ($inst in @($magicOnly)) {
            if (-not $inst.EnableWakeOnMagicPacketOnly) {
                $inst | Set-CimInstance -Property @{ EnableWakeOnMagicPacketOnly = $true } -ErrorAction Stop
                Write-Log ("  [SET WMI] MSNdis_DeviceWakeOnMagicPacketOnly = True")
            } else {
                Write-Log ("  [OK WMI] MSNdis_DeviceWakeOnMagicPacketOnly = True")
            }
        }
    } catch {
        Write-Log ("  [WARN] Cap nhat WMI wake gap loi: {0}" -f $PSItem.Exception.Message)
    }
}

# ------------------------------------------------------------------------
# LAYER 4: WINDOWS FAST STARTUP & PCIE ASPM
# ------------------------------------------------------------------------
Write-Section '[LAYER 4] TAT FAST STARTUP & PCIE LINK STATE POWER MANAGEMENT (ASPM)'
$powerRegPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power'
try {
    $hiberBootBefore = (Get-ItemProperty -Path $powerRegPath -Name HiberbootEnabled -ErrorAction SilentlyContinue).HiberbootEnabled
    Set-ItemProperty -Path $powerRegPath -Name HiberbootEnabled -Value 0 -Type DWord -ErrorAction Stop
    Write-Log ("  [SET OS] HiberbootEnabled: {0} -> 0 (Tat Fast Startup)" -f $hiberBootBefore)
} catch {
    Write-Log ("  [WARN] Khong the dat HiberbootEnabled: {0}" -f $PSItem.Exception.Message)
}

try {
    & powercfg.exe /setacvalueindex SCHEME_CURRENT SUB_PCIEXPRESS ASPM 0 | Out-Null
    & powercfg.exe /setactive SCHEME_CURRENT | Out-Null
    Write-Log '  [SET OS] PCIe Link State Power Management (AC ASPM): Off (0x00000000)'
} catch {
    Write-Log ("  [WARN] Khong the dat PCIe ASPM: {0}" -f $PSItem.Exception.Message)
}

# ------------------------------------------------------------------------
# RESTART ADAPTER & RE-ARM WAKE
# ------------------------------------------------------------------------
Write-Section '[APPLY] KHOI DONG LAI CARD MANG & XAC NHAN powercfg /deviceenablewake'
foreach ($adapter in $pcieAdapters) {
    Write-Log ("  Restarting {0}..." -f $adapter.Name)
    try {
        Restart-NetAdapter -Name $adapter.Name -ErrorAction Stop
    } catch {
        Write-Log ("  [WARN] Restart-NetAdapter bao loi: {0}" -f $PSItem.Exception.Message)
    }

    $upReady = $false
    for ($i = 0; $i -lt 15; $i++) {
        Start-Sleep -Seconds 1
        $cur = Get-NetAdapter -Name $adapter.Name -ErrorAction SilentlyContinue
        if ($null -ne $cur -and $cur.Status -eq 'Up') {
            $upReady = $true
            break
        }
    }
    $afterAdapter = Get-NetAdapter -Name $adapter.Name -ErrorAction SilentlyContinue
    $linkDisplay = if ($upReady) { 'Up' } elseif ($null -ne $afterAdapter) { "$($afterAdapter.Status)" } else { 'Unknown' }
    Write-Log ("  Link status sau restart: {0} ({1})" -f $linkDisplay, $adapter.Name)

    $enableOut = & powercfg.exe /deviceenablewake "$($adapter.InterfaceDescription)" 2>&1
    Write-Log ("  powercfg /deviceenablewake: Exit={0} {1}" -f $LASTEXITCODE, ($enableOut -join ' ').Trim())
}

# ------------------------------------------------------------------------
# FINAL VERIFICATION REPORT
# ------------------------------------------------------------------------
Write-Section '[VERIFY] KET QUA KIEM CHUNG SAU KHI TOI UU'

foreach ($adapter in $pcieAdapters) {
    $liveAdapter = Get-NetAdapter -Name $adapter.Name -ErrorAction SilentlyContinue
    $ips = @(Get-NetIPAddress -InterfaceIndex $liveAdapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty IPAddress)
    Write-Log ("Adapter     : {0} ({1})" -f $liveAdapter.Name, $liveAdapter.InterfaceDescription)
    Write-Log ("Link & MAC  : Status={0} | Speed={1} | MAC={2} | IPv4={3}" -f $liveAdapter.Status, $liveAdapter.LinkSpeed, $liveAdapter.MacAddress, ($ips -join ', '))

    $pm = Get-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction SilentlyContinue
    if ($null -ne $pm) {
        Write-Log ("PowerMgmt   : WakeOnMagicPacket={0} | WakeOnPattern={1} | ArpOffload={2} | NSOffload={3}" -f $pm.WakeOnMagicPacket, $pm.WakeOnPattern, $pm.ArpOffload, $pm.NSOffload)
    }

    $verifyKeys = @('*WakeOnMagicPacket', 'S5WakeOnLan', 'WolShutdownLinkSpeed', '*WakeOnPattern', '*EEE', 'EnableGreenEthernet', 'PowerSavingMode', 'EnablePME', 'EEELinkAdvertisement', 'ULPMode')
    $adv = @(Get-NetAdapterAdvancedProperty -Name $adapter.Name -IncludeHidden -ErrorAction SilentlyContinue | Where-Object { $verifyKeys -contains $PSItem.RegistryKeyword })
    foreach ($p in $adv) {
        Write-Log ("  - {0,-28} ({1,-22}) = {2} ({3})" -f $p.DisplayName, $p.RegistryKeyword, $p.DisplayValue, ($p.RegistryValue -join ','))
    }

    $wakeEnable = Get-CimInstance -Namespace root\wmi -ClassName MSPower_DeviceWakeEnable -ErrorAction SilentlyContinue |
        Where-Object { ([string]$PSItem.InstanceName).StartsWith([string]$adapter.PnPDeviceID, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
    $magicOnly = Get-CimInstance -Namespace root\wmi -ClassName MSNdis_DeviceWakeOnMagicPacketOnly -ErrorAction SilentlyContinue |
        Where-Object { $PSItem.InstanceName -eq $adapter.InterfaceDescription -or ([string]$PSItem.InstanceName).StartsWith([string]$adapter.PnPDeviceID, [System.StringComparison]::OrdinalIgnoreCase) } | Select-Object -First 1
    $nicReg = Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue |
        ForEach-Object { Get-ItemProperty $PSItem.PSPath -ErrorAction SilentlyContinue } |
        Where-Object { $PSItem.NetCfgInstanceId -eq $liveAdapter.InterfaceGuid } | Select-Object -First 1

    Write-Log ("WMI & Reg   : MSPower_DeviceWakeEnable={0} | MSNdis_DeviceWakeOnMagicPacketOnly={1} | PnPCapabilities={2}" -f $wakeEnable.Enable, $magicOnly.EnableWakeOnMagicPacketOnly, $nicReg.PnPCapabilities)
}

$hiberNow = (Get-ItemProperty -Path $powerRegPath -Name HiberbootEnabled -ErrorAction SilentlyContinue).HiberbootEnabled
$aspmLines = (& powercfg.exe /q SCHEME_CURRENT SUB_PCIEXPRESS ASPM) -join "`n"
Write-Log ("Hiberboot   : HiberbootEnabled = {0}" -f $hiberNow)
$acMatch = [regex]::Match($aspmLines, 'Current AC Power Setting Index:\s*(0x[0-9a-fA-F]+)')
if ($acMatch.Success) {
    Write-Log ("PCIe ASPM   : Current AC Power Setting Index = {0}" -f $acMatch.Groups[1].Value)
}

Write-Log ''
Write-Log 'powercfg /devicequery wake_armed:'
foreach ($line in (& powercfg.exe /devicequery wake_armed)) {
    if ($line.Trim()) { Write-Log ("  * {0}" -f $line.Trim()) }
}

if ($biosNeedsReboot) {
    Write-Log ''
    Write-Log '[ACTION REQUIRED] Da cap nhat cau hinh BIOS HP -> Khoi dong lai Windows de ap dung BIOS.'
}

Write-Log ''
Write-Log ("Hoan tat! Bao cao da duoc luu tai: {0}" -f $logFile)

try {
    [System.IO.File]::WriteAllLines($logFile, $logLines, [System.Text.UTF8Encoding]::new($false))
} catch {
    Write-Host ("[WARN] Khong ghi duoc file log: {0}" -f $PSItem.Exception.Message)
}
exit 0
