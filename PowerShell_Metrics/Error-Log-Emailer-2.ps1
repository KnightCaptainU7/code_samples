<#
 .SYNOPSIS
	Finds and compresses logs from a specific folder, then emails them.

 .DESCRIPTION
	Accepts variables to allow for script reuse to create multiple emails.

 .PARAMETER LogsPath
	A string for the top-level folder where all other log folders live.
	This must contain the ending backslash.
	Default value: "E:\Logs\"
 
 .PARAMETER FolderName
	A string for the specific folder we want to monitor.
	Default value: "Redis"
	
 .EXAMPLE
	Error-Log-Emailer-2.ps1

 .INPUTS
	Pipeline input has not been tested.

 .OUTPUTS
	Screen output and Windows Event Log Application Log.

 .NOTES
	Author		: Scott Cooper
	Created		: 2019-04-24
	Change Log	: 2019-05-29 Text variable now shrinks with each log level parsing,
					which should speed the script. Notice level removed, Fatal added.
#>

#region Parameters
Param(
	[String]$LogsPath,
	[String]$FolderName,
	[Int]$HoursBack,
	[String[]]$ToList,
	[String[]]$CCList
	)
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
Set-Variable -Name "ScriptTitle" -Value "Error Log Emailer 2"

# Some servers use .log, some use .txt.
Set-Variable -Name "Extension" -Value "txt"

# Testing
Set-Variable -Name "LogsPath" -Value "E:\Logs\"
Set-Variable -Name "FolderName" -Value "MCM4"
# Set number of minutes back to look for updates.
Set-Variable -Name "HoursBack" -Value "1"
# Email recipients, each must be listed with quotes.
Set-Variable -Name "ToList" -Value "User1@example.com", "User2@example.com"
Set-Variable -Name "CCList" -Value "DistroList3@example.com"

# Convert Path with extra slash to help things along.
Set-Variable -Name "SourcePath" -Value "$LogsPath\$FolderName"

# Variables for different data centers because DNS there was illogical
Set-Variable -Name "MailRelay" -Value "w.x.y.z"
Set-Variable -Name "Sender" -Value "DataCenterSender@example.com"
# Set-Variable -Name "MailRelay" -Value "a.b.c.d"
# Set-Variable -Name "Sender" -Value "SenderDataCenter@example.com"

#endregion

#region Main
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=

# Set a variable for the scripts start time for use in the Event Log.
Set-Variable -Name "StartTime" -Value (get-date -format "HH:mm:ss")

# Set a variable for today's date, hour, and minute.
Set-Variable -Name "DateStamp" -Value (get-date -format yyyy-MM-dd-HHmm)

# Set a variable for the compressed file name.
Set-Variable -Name "ZipFileName" -Value "$FolderName-Errors-$DateStamp"

# Create an Error-Log-Emailer folder if it does not exist.
if (!(Test-Path $SourcePath\Error-Log-Emailer)) {New-Item -Name "Error-Log-Emailer" -Path $SourcePath -ItemType Directory}

# First get the files within the $SourcePath folder only (no -recurse),
# then check for how many files have been updated within the last interval,
# which creates a variable of that list for logging output.
(Get-ChildItem -Path $SourcePath\*.* -Filter *.$Extension.* | ? {
  $_.LastWriteTime -gt (Get-Date).AddHours(-$HoursBack)
} -OutVariable FilesFound)

# Count how many files were found.
Set-Variable -Name "FileCount" -Value ($FilesFound.count)
#endregion

#region Counts
# Set for the Select-String search.
Set-Variable -Name "PriorHour" -Value (get-date (get-date).AddHours(-1) -format "yyyy-MM-dd HH:mm:")

# Set a pattern to match.
Set-Variable -Name "Pattern" -Value "\A$PriorHour"

# ForEach ($Folder in $FilesFound) { Write-Host Checking $FilesFound;
# Get the hour's worth of logs, and count the errors and warnings.
Get-Content -Path $FilesFound | Select-String -Pattern $Pattern -OutVariable "MinuteStrings" | Measure-Object -Line -OutVariable "Lines"

Set-Variable -Name "Lines" -Value ($Lines.lines)
Write-Host $Folder has $Lines total lines.`n

$MinuteStrings | Select-String -Pattern \.Error`t | Measure-Object -Line -OutVariable "Errors"
$MinuteStrings | Select-String -Pattern \.Warning`t | Measure-Object -Line -OutVariable "Warning"

Write-Host There are $Errors.Lines errors and $Warning.Lines warnings.

#endregion

#region Tail
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Get the output of the latest file, tailed.

# Select the latest file, since there may be multiple ones found.
Set-Variable -Name "LatestFile" -Value (Get-ChildItem $FilesFound | Sort-Object LastWriteTime | Select-Object -Last 1)

# Let's also include in the email body some of the last errors for faster handling.
Set-Variable -Name "TailOutput" -Value (Get-Content $LatestFile -Tail 50 | Format-Table | Out-String)

#endregion

#region Compression
#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Since we _should_ have files to report, compress the full file to send.
# Note that Compress-Archive is only available in PowerShell 5.0 and above,
# and that Compress-Archive -OutVariable does not provide any output.
Compress-Archive -CompressionLevel Optimal -Path $FilesFound -DestinationPath "$SourcePath\Error-Log-Emailer\$ZipFileName.zip"
#endregion




#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# If no files were found, write to the Event Log that nothing was found to report.
# If no error, write an Information message with EventID 888,
# if an error, write a Warning message with EventID 444.
if ($FileCount -lt "1") {
 Send-MailMessage -To $ToList -CC $CCList -Subject "$ZipFileName has no errors" -Body "$ScriptTitle started at $StartTime completed successfully, but found no updates in the last $HoursBack hour(s) in $SourcePath." -SmtpServer "$MailRelay" -From "$Sender"
 if (!($error)) {
  Write-EventLog -LogName "Application" -Source "Ansible Tower" -EventID 888 -EntryType Information -Message "$ScriptTitle started at $StartTime completed successfully, but found no updates in the last $HoursBack hour(s) in $SourcePath. An email confirming the lack of errors was sent to confirm this check was done." -Category 0
  } else {
  # Counts the errors and uses the correct singular or plural of "error".
  Set-Variable -Name "ErrorCount" -Value ($error.count)
  if ($ErrorCount -gt "1") {Set-Variable -Name "Error_or_Errors" -Value "errors"} else {Set-Variable -Name "Error_or_Errors" -Value "error"}
  Set-Variable -Name "ErrorMessages" -Value ($error | Format-List | Out-String) 
  Write-EventLog -LogName "Application" -Source "Ansible Tower" -EventID 444 -EntryType Warning -Message "$ScriptTitle started at $StartTime completed with $ErrorCount $Error_or_Errors`: $ErrorMessages" -Category 0
  Send-MailMessage -To $CCList -Subject "$ZipFileName $ScriptTitle had Errors" -Body "$ScriptTitle started at $StartTime completed with $ErrorCount $Error_or_Errors`: $ErrorMessages" -SmtpServer "$MailRelay" -From "$Sender"
}
# We can exit the script now since there is nothing else to do here.
# exit
}





Send-MailMessage -To $ToList -CC $CCList -Subject "$ZipFileName" -Body "$ScriptTitle started at $StartTime completed successfully, and found errors in the last $HoursBack hours at $SourcePath. Tail results:`n$TailOutput" -SmtpServer "$MailRelay" -From "$Sender" -Attachments "$SourcePath\Error-Log-Emailer\$ZipFileName.zip"

# Remove the zip file.
# Remove-Item -Path "$SourcePath\Error-Log-Emailer\$ZipFileName.zip"

#-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Write the event to the Event Log.
# If no error, write an Information message with EventID 888,
# if an error, write a Warning message with EventID 444.
if (!($error)) {
 if ($FileCount -gt "1") {Set-Variable -Name "Files" -Value "these $FileCount files"} else {Set-Variable -Name "Files" -Value "this $FileCount file"}
 # Format-Table because the details of Format-List here are overkill.
 Set-Variable -Name "FilesFound" -Value ($FilesFound | Format-Table | Out-String)
 Write-EventLog -LogName "Application" -Source "Ansible Tower" -EventID 888 -EntryType Information -Message "$ScriptTitle started at $StartTime completed successfully, created $ZipFileName.zip, and emailed from $Sender to $ToList and $CCList based on errors found in $Files`: $FilesFound" -Category 0
} else {
 # Counts the errors and uses the correct singular or plural of "error".
 Set-Variable -Name "ErrorCount" -Value ($error.count)
 if ($ErrorCount -gt "1") {Set-Variable -Name "Error_or_Errors" -Value "errors"} else {Set-Variable -Name "Error_or_Errors" -Value "error"}
 Set-Variable -Name "ErrorMessages" -Value ($error | Format-List | Out-String) 
 Write-EventLog -LogName "Application" -Source "Ansible Tower" -EventID 444 -EntryType Warning -Message "$ScriptTitle started at $StartTime completed with $ErrorCount $Error_or_Errors`: $ErrorMessages" -Category 0
 Send-MailMessage -To $CCList -Subject "$ZipFileName $ScriptTitle had Errors" -Body "$ScriptTitle started at $StartTime completed with $ErrorCount $Error_or_Errors`: $ErrorMessages" -SmtpServer "$MailRelay" -From "$Sender"
}

exit
