<#
 .SYNOPSIS
	Create permanent Performance Counters for Kiwi Syslog.

 .DESCRIPTION
	Accepts variables to allow for script reuse to create multiple Performance Counters for Kiwi Syslog.

 .PARAMETER LogsPath
	A string for the top-level folder where all other log folders live.
	This must contain the ending backslash.
	Default value: "E:\Logs\"
 
 .PARAMETER FolderName
	A string for the specific folder we want to monitor.
	Default value: "Billing"
	
 .EXAMPLE
	Kiwi-Syslog-Create-Performance-Counters.ps1
	Will prompt for parameters.
	
 .EXAMPLE
	Kiwi-Syslog-Create-Performance-Counters-v2.ps1 -LogsPath "E:\Logs\" -FolderName "Billing"
	Will create common performance counters under "Kiwi Syslog" for "Billing - All Logs" and others.

 .INPUTS
	Pipeline input has not been tested.

 .OUTPUTS
	Screen output and Event Log entries.

 .NOTES
	Author		: Scott Cooper
	Created		: 2019-04-23
	Change Log	: First Release
				: 2019-07-01 Removed "Notices" and added "Fatals"
#>

#region Parameters
Param(
	[String]$LogsPath,
	[String]$FolderName)
	# [String]$LogLevels)
#endregion

#region ClearErrors
# Allow this script to run.
Set-ExecutionPolicy -executionPolicy Unrestricted -Scope Process -Force
# The above _may_ throw an error that we don't care about.
# This clears the error and resets the count to zero.
$error.Clear()
#endregion

#region Header
Set-Variable -Name "ScriptTitle" -Value "Kiwi Syslog Create Performance Counters"
# Set a variable for the scripts start time.
Set-Variable -Name "StartTime" -Value (get-date -format "HH:mm:ss")
#endregion

#region Main
# Create a Log-Grab folder if it does not exist.
if (Test-Path $LogsPath\$FolderName) {Write-Host $LogsPath$FolderName found.} else {Write-Host $LogsPath$FolderName NOT found. | Write-Host "Cannot continue. Exit!" -ForegroundColor Yellow | pause }

# https://aero971.wordpress.com/2011/05/24/add-performance-counters-through-powershell/
# Global variable definition, needed to create before adding sublevels under it.
$newMetrics
$script:newMetrics = New-Object Diagnostics.CounterCreationDataCollection;
$LogLevels = "All Logs","Fatals","Errors","Warnings","Info","Debug","Other"

ForEach ($LogLevel in $LogLevels) {
  # Clear-Variable -Name "MetricName"
  Set-Variable -Name "MetricName" -Value $LogLevel
  Write-Host Creating $MetricName
  
  $counter = New-Object Diagnostics.CounterCreationData;
  $counter.CounterName = "$MetricName";
  $counter.CounterHelp = "$MetricName lines processed by Kiwi Syslog.";
  $counter.CounterType = [Diagnostics.PerformanceCounterType]::NumberOfItems64;
  $script:newMetrics.Add($counter);
  }

$newMetrics
Write-Host "Adding the counters to PerfMon";
[Diagnostics.PerformanceCounterCategory]::Create("Kiwi Syslog - $FolderName", "Metrics generated via PowerShell.", $script:newMetrics);
# pause
#endregion
