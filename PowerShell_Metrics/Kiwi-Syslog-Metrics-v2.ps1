<#
 .SYNOPSIS
	Generates metrics from Kiwi Syslog text output.

 .DESCRIPTION
	Accepts variables to allow for script reuse to create multiple Performance Counters for Kiwi Syslog.

 .PARAMETER LogsPath
	A string for the top-level folder where all other log folders live.
	This must contain the ending backslash.
	Default value: "E:\Logs\"
 
 .PARAMETER FolderName
	A string for the specific folder we want to monitor.
	Default value: "Redis"
	
 .EXAMPLE
	Kiwi-Syslog-Metrics.ps1
	Will prompt for parameters.
	
 .EXAMPLE
	Kiwi-Syslog-Create-Performance-Counters.ps1 -LogsPath "E:\Logs\" -FolderName "Redis"
	Will create common performance counters under "Kiwi Syslog" for "Redis All Logs" and others.

 .INPUTS
	Pipeline input has not been tested.

 .OUTPUTS
	Screen output only.

 .NOTES
	Author		: Scott Cooper
	Created		: 2019-04-24
	Change Log	: 2019-05-29 Text variable now shrinks with each log level parsing,
					which should speed the script. Notice level removed, Fatals added.
				: 2019-07-01 Prepared for production use.
#>

#region Parameters
Param(
	[String]$LogsPath,
	[String]$FolderName)
#endregion

#region ClearErrors
# Allow this script to run.
Set-ExecutionPolicy -executionPolicy Unrestricted -Scope Process -Force
# The above _may_ throw an error that we don't care about.
# This clears the error and resets the count to zero.
$error.Clear()
#endregion

#region Variables
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Variables
# Set a Title
Set-Variable -Name "ScriptTitle" -Value "Kiwi Syslog Metrics v2"

# Some servers use .log, some use .txt.
Set-Variable -Name "Extension" -Value "txt"

# Set-Variable -Name "LogsPath" -Value "E:\Logs\"
# Set-Variable -Name "FolderName" -Value "TransactionRouter"

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

# Set a variable for the scripts start time.
Set-Variable -Name "StartTime" -Value (get-date -format "HH:mm:ss")

# Set a variable for today's date, hour, and minute.
Set-Variable -Name "DateStamp" -Value (get-date -format yyyy-MM-dd-HHmm)

# Set for the Select-String search.
Set-Variable -Name "PriorMinute" -Value (get-date (get-date).AddMinutes(-1) -format "yyyy-MM-dd HH:mm:")

# Set a pattern to match.
Set-Variable -Name "Pattern" -Value "\A$PriorMinute"
#endregion

#region Main
ForEach ($Folder in $FolderName) { Write-Host Checking $LogsPath$Folder; 
  (Get-ChildItem -Path $LogsPath\$Folder\*.* -Filter *.$Extension.* | ? {
  $_.LastWriteTime -ge (Get-Date).AddMinutes(-1) 
    } -OutVariable FilesFound)| Get-Content | Select-String -Pattern $Pattern -OutVariable "MinuteStrings" | Measure-Object -Line -OutVariable "Lines"
	Set-Variable -Name "Lines" -Value ($Lines.lines)
	Write-Host $Folder has $Lines total lines.`n
	# $Number = ($Number + 1);
	# Write-Host $Folder reported as Statistics.Stat$Number`: $Lines.Lines

	$MinuteStrings | Select-String -Pattern \.Info`t -NotMatch -OutVariable "MinuteStrings" | Measure-Object -Line -OutVariable "NotInfo"
	Write-Host $Folder has $NotInfo.lines lines do not match the pattern for Info.
	Set-Variable -Name "Info" -Value ($Lines - $NotInfo.lines)
	Write-Host $Folder has $Info info lines counted.`n

	$MinuteStrings | Select-String -Pattern \.Debug`t -NotMatch -OutVariable "MinuteStrings" | Measure-Object -Line -OutVariable "NotDebug"
	Write-Host $Folder has $NotDebug.lines lines do not match the pattern for Debug.
	Set-Variable -Name "Debug" -Value ($NotInfo.lines - $NotDebug.lines)
	Write-Host $Folder has $Debug debug lines counted.`n
	
	$MinuteStrings | Select-String -Pattern \.Warning`t -NotMatch -OutVariable "MinuteStrings" | Measure-Object -Line -OutVariable "NotWarning"
	Write-Host $Folder has $NotWarning.lines lines do not match the pattern for Warning.
	Set-Variable -Name "Warning" -Value ($NotDebug.lines - $NotWarning.lines)
	Write-Host $Folder has $Warning warning lines counted.`n
	
	$MinuteStrings | Select-String -Pattern \.Error`t -NotMatch -OutVariable "MinuteStrings" | Measure-Object -Line -OutVariable "NotErrors"
	Write-Host $Folder has $NotErrors.lines lines do not match the pattern for Error.
	Set-Variable -Name "Errors" -Value ($NotWarning.lines - $NotErrors.lines)
	Write-Host $Folder has $Errors error lines counted.`n
	
	$MinuteStrings | Select-String -Pattern \.Fatal`t -NotMatch -OutVariable "MinuteStrings" | Measure-Object -Line -OutVariable "NotFatal"
	Write-Host $Folder has $NotFatal.lines lines do not match the pattern for Fatal.
	Set-Variable -Name "Fatals" -Value ($NotErrors.lines - $NotFatal.lines)
	Write-Host $Folder has $Fatals fatal lines counted.`n
	
	# Select-String should not be needed here.
	# $MinuteStrings | Select-String -Pattern \.Error`t,\.Warning`t,\.Fatal`t,\.Info`t,\.Debug`t -NotMatch | Measure-Object -Line -OutVariable "Other"
	$MinuteStrings | Measure-Object -Line -OutVariable "Other"
	Set-Variable -Name "Other" -Value ($Other.lines)
	
	Write-Host There are $Fatals fatals, $Errors errors, $Warning warnings, $Info info, and $Debug debug messages. There are $Other other unclassified messages.`n

	# Now write the to the Performance Counter locally.
	$AllLogs		= New-Object System.Diagnostics.PerformanceCounter("Kiwi Syslog - $FolderName", "All Logs", "", $false)
	$InfoLogs		= New-Object System.Diagnostics.PerformanceCounter("Kiwi Syslog - $FolderName", "Info", "", $false)
	$DebugLogs		= New-Object System.Diagnostics.PerformanceCounter("Kiwi Syslog - $FolderName", "Debug", "", $false)
	$WarningLogs	= New-Object System.Diagnostics.PerformanceCounter("Kiwi Syslog - $FolderName", "Warnings", "", $false)
	$ErrorLogs		= New-Object System.Diagnostics.PerformanceCounter("Kiwi Syslog - $FolderName", "Errors", "", $false)
	$FatalLogs		= New-Object System.Diagnostics.PerformanceCounter("Kiwi Syslog - $FolderName", "Fatals", "", $false)
	$OtherLogs		= New-Object System.Diagnostics.PerformanceCounter("Kiwi Syslog - $FolderName", "Other", "", $false)

	$AllLogs.RawValue		= $Lines
	$InfoLogs.RawValue		= $Info
	$DebugLogs.RawValue		= $Debug
	$WarningLogs.RawValue	= $Warning
	$ErrorLogs.RawValue		= $Errors
	$FatalLogs.RawValue		= $Fatals
	$OtherLogs.RawValue		= $Other
	
	<#
	$AllLogs.ReadOnly		= $false
	$FatalLogs.ReadOnly		= $false
	$ErrorLogs.ReadOnly		= $false
	$WarningLogs.ReadOnly	= $false
	$InfoLogs.ReadOnly		= $false
	$DebugLogs.ReadOnly		= $false
	$OtherLogs.ReadOnly		= $false
	#>

}
#endregion

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# If no lines were found, write to the Event Log that nothing was found to report.
# If no error, write an Information message with EventID 888,
# if an error, write a Warning message with EventID 444.

if ($Lines -lt "1") {
  # Counts the errors and uses the correct singular or plural of "error".
  Set-Variable -Name "ErrorCount" -Value ($error.count)
  if ($ErrorCount -gt "1") {Set-Variable -Name "Error_or_Errors" -Value "errors"} else {Set-Variable -Name "Error_or_Errors" -Value "error"}
  Set-Variable -Name "ErrorMessages" -Value ($error | Format-List | Out-String)
  if (!($error)) {
    Write-EventLog -LogName "Application" -Source "Ansible Tower" -EventID 888 -EntryType Information -Message "$ScriptTitle started at $StartTime completed successfully, and found $Folder has $Lines total lines.`nThere are $Fatals fatals, $Errors errors, $Warning warnings, $Info info, and $Debug debug messages. There are $Other other unclassified messages.`nThese files were searched: $FilesFound" -Category 0
	} else {
	Write-EventLog -LogName "Application" -Source "Ansible Tower" -EventID 444 -EntryType Warning -Message "$ScriptTitle started at $StartTime completed with $ErrorCount $Error_or_Errors`:`n $ErrorMessages`n $ScriptTitle found $Folder has $Lines total lines.`nThere are $Fatals fatals, $Errors errors, $Warning warnings, $Info info, and $Debug debug messages. There are $Other other unclassified messages.`nThese files were searched: $FilesFound" -Category 0
    }
	} else {
  # Everything is all good.
  Write-EventLog -LogName "Application" -Source "Ansible Tower" -EventID 888 -EntryType Information -Message "$ScriptTitle started at $StartTime completed successfully, and found $Folder has $Lines lines.`n $ScriptTitle found $Folder has $Lines total lines.`nThere are $Fatals fatals, $Errors errors, $Warning warnings, $Info info, and $Debug debug messages. There are $Other other unclassified messages.`nThese files were searched: $FilesFound" -Category 0
  # There are $ErrorLogs.RawValue errors, $WarningLogs.RawValue warnings, $NoticeLogs.RawValue notices, $InfoLogs.RawValue info, and $DebugLogs.RawValue debug messages. There were $OtherLogs.RawValue other unclassified messages. These files were searched: $FilesFound"
  }

exit
