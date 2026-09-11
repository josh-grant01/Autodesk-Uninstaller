<#
 This script is used to FULLY UNINSTALL ALL AUTODESK PRODUCTS!!  RUN AT YOUR OWN RISK!
 #>

 # --- Start self-elevation check ---
$IsAdmin = ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Start-Process powershell.exe `
        -Verb RunAs `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}
# --- End self-elevation block ---


class Uninstaller {
    [void]deleteprogfiles() {
        $this.Logs("Checking for any Autodesk files and directories in ProgramFiles")
        $checkx64 = [bool](Get-ChildItem -Path $env:ProgramFiles -Filter "*Autodesk*" -Recurse -Directory -ErrorAction SilentlyContinue)
        $this.Logs("Checking for any Autodesk files and directories in ProgramFiles(x86)")
        $checkx86 = [bool](Get-ChildItem -Path ${env:ProgramFiles(x86)} -Filter "*Autodesk*" -Recurse -Directory -ErrorAction SilentlyContinue)
        $this.Logs("Checking for any Autodesk files and directories in ProgramData")
        $checkdata = [bool](Get-ChildItem -Path $env:ProgramData -Filter "*Autodesk*" -Recurse -Directory -ErrorAction SilentlyContinue)
        $this.Logs("Results - Program Files check = $checkx64, Program Files(x86) check = $checkx86, ProgramData check = $checkdata")

        if ($checkx64 -or $checkx86 -or $checkdata) {
            if ($checkx64) {
                Remove-Item -Path "$env:ProgramFiles\Autodesk" -Force -Include *.* -Recurse -ErrorAction SilentlyContinue -Verbose
                Remove-Item -Path "$env:ProgramFiles\Common Files\*Autodesk*" -Force -Include *.* -Recurse -ErrorAction SilentlyContinue -Verbose
            }
            if ($checkx86) {
                Remove-Item -Path "$env:ProgramFiles(x86)\Autodesk" -Force -Include *.* -Recurse -ErrorAction SilentlyContinue -Verbose
                Remove-Item -Path "$env:ProgramFiles(x86)\Common Files\*Autodesk*" -Force -Include *.* -Recurse -ErrorAction SilentlyContinue -Verbose
            }
            if ($checkdata) {
                Remove-Item -Path "$env:ProgramData\Autodesk" -Force -Include *.* -Recurse -ErrorAction SilentlyContinue -Verbose
                [bool]$testlogs = Test-Path -Path "$env:ProgramData\Logs\Acad"
                if ($testlogs) {
                    Remove-Item -Path "$env:ProgramData\Logs\Acad" -Force -Include *.* -Recurse -ErrorAction SilentlyContinue -Verbose
                }
                $testlogs = Test-Path -Path "$env:ProgramData\Logs\*Revit*"
                if ($testlogs) {
                    Remove-Item -Path "$env:ProgramData\Logs\*Revit*" -Force -Include *.* -Recurse -ErrorAction SilentlyContinue -Verbose
                }
            }
        }

        $this.Logs("Finished deleting all Autodesk files and directories in ProgramFiles, ProgramFiles(x86), and ProgramData.")
        $this.deleteroot()
    }

    [void]deleteroot() {
        $this.Logs("Checking for Autodesk files and directories in root of drive.")
        $checkroot = [bool](Get-ChildItem -Path $env:SystemDrive -Filter "*Autodesk*" -Recurse -Directory -ErrorAction SilentlyContinue)
        if ($checkroot) {
            Remove-Item -Path "$env:SystemDrive\*Autodesk*" -Force -Include *.* -Recurse -ErrorAction SilentlyContinue -Verbose
            $this.Logs("Finished removing Autodesk files and directories from root of system drive.")
        }
        $this.deleteHKEY()
    }

    [void]deleteHKEY() {
        $this.Logs("Checking for Autodesk HKeys in HKLM.")
        $checkHKLM = [bool](Get-ChildItem -Path HKLM:\SOFTWARE\*Autodesk* -Recurse -ErrorAction SilentlyContinue)
        if ($checkHKLM) {
            Remove-Item -Path "HKLM:\SOFTWARE\*Autodesk*" -Force -Recurse -ErrorAction SilentlyContinue -Verbose
            Remove-item -Path "HKLM:|SOFTWARE\WOW6432Node\*Autodesk*" -Force -Recurse -ErrorAction SilentlyContinue -Verbose
            $this.Logs("Removed Autodesk keys from HKLM")
        }
        $this.Logs("Checking for Autodesk HKeys in HKCU.")
        $checkHKCU = [bool](Get-ChildItem -Path HKCU:\Software\*Autodesk* -Recurse -ErrorAction SilentlyContinue)
        if ($checkHKCU) {
            Remove-Item -Path "HKCU:\Software\*Autodesk*" -Force -Recurse -ErrorAction SilentlyContinue -Verbose
            $this.Logs("Removed Autodesk keys from HKCU.")
        }
        $this.Logs("Checking for Autodesk HKeys in HKU.")

        $PatternSID = 'S-1-5-21-\d+-\d+\-\d+\-\d+$'
        $ProfileList = gp 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*' | Where-Object {$_.PSChildName -match $PatternSID} | Select @{name="SID";expression={$_.PSChildName}}, @{name="UserHive";expression={"$($_.ProfileImagePath)\ntuser.dat"}}, @{name="Username";expression={$_.ProfileImagePath -replace '^(.*[\\\/])',''}}

        $LoadedHives = gci Registry::HKEY_USERS | ? {$_.PSChildName -match $PatternSID} | Select @{name="SID";expression={$_.PSChildName}}
        $UnloadedHives = Compare-Object $ProfileList.SID $LoadedHives.SID | Select @{name="SID";expression={$_.InputObject}}, UserHive, Username

        # Load each SID and Recurse through to delete Autodesk data for each user
        Foreach ($item in $ProfileList) {
            if ($item.SID -in $UnloadedHives.SID) {
                reg load HKU\$($item.SID) $($Item.UserHive) | Out-Null
            }

            $checkHKU = [bool](Get-ChildItem -Path Registry::HKEY_USERS\$($Item.SID)\Software\*Autodesk* -Recurse -ErrorAction SilentlyContinue)
            if ($checkHKU) {
                Remove-Item -Path Registry::HKEY_USERS\$($Item.SID)\Software\*Autodesk* -Force -Recurse -ErrorAction SilentlyContinue -Verbose
                $this.Logs("Removed Autodesk keys from HKU for user $($item.Username).")
            }

            $checklocaluser = [bool](Get-ChildItem -Path "$env:SystemDrive\Users\$($Item.Username)\APPDATA\Local\*Autodesk*" -Recurse -ErrorAction SilentlyContinue)
            if ($checklocaluser) {
                Remove-Item -Path "$env:SystemDrive\Users\$($Item.Username)\APPDATA\Local\*Autodesk*" -Force -Recurse -ErrorAction SilentlyContinue -Verbose
                Remove-Item -Path "$env:SystemDrive\Users\$($Item.Username)\APPDATA\Local\Temp\*" -Force -Recurse -ErrorAction SilentlyContinue -Verbose
                $this.Logs("Removed Autodesk files and directories from $env:localappdata for user $($Item.Username).")
            }

            $checkroamuser = [bool](Get-ChildItem -Path "env:SystemDrive\Users\$($Item.Username)\APPDATA\Roaming\*Autodesk*" -Recurse -ErrorAction SilentlyContinue)
            if ($checkroamuser) {
                Remove-Item -Path "env:SystemDrive\Users\$($Item.Username)\APPDATA\Roaming\*Autodesk*" -Force -Recurse -ErrorAction SilentlyContinue -Verbose
                $this.Logs("Removed Autodesk files and directories from $env:APPDATA for user $($Item.Username).")
            }

            if ($item.SID -in $UnloadedHives.SID) {
                [gc]::Collect()
                reg unload HKU\$($Item.SID) | Out-Null
            }
        }
    }

    [void]Logs([string]$message) {
        $logDir = "$env:TEMP\Uninstall"
        if (-not (Test-Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        $logFile = Join-Path $logDir "aduninstall.log"
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss:ms"
        "$timestamp - $message" | Out-File -FilePath $logFile -Append -Encoding utf8
    }
}

$startup = [Uninstaller]::new()
$startup.deleteprogfiles()