<#
.SYNOPSIS
    Partion and format the disk.
.DESCRIPTION
    Partion and format the disk.
.LINK
    https://github.com/FriendsOfMDT/PSD
.NOTES
          FileName: PSDPartition.ps1
          Solution: PowerShell Deployment for MDT
          Author: PSD Development Team
          Contact: @Mikael_Nystrom , @jarwidmark , @mniehaus
          Primary: @Mikael_Nystrom 
          Created: 
          Modified: 2024-10-23

          Version - 0.0.1 - () - Finalized functional version 1.
          Version - 0.0.5 - () - Fixed spelling.
          Version - 0.0.6 - (Mikael_Nystrom) - Replaced Clear-Disk with Clear-PSDDisk
		  Version - 0.0.7 - (Patrick Scherling) (2024-10-24) - Rewriting this script so that we can work with the values from the TS
		  Version - 0.0.8 - (Patrick Scherling) (2024-10-28) - Finalized functional version.
		  Version - 0.0.9 - (Patrick Scherling) (2024-11-04) - The check for Data on disk is now the first step of the partitioning and do the initialization of the disk.
		  Version - 0.0.10 - (Patrick Scherling) (2024-11-06) - Finalized functional version.

          TODO:
		  Some cleanup stuff and additional checks needed
		  
		
.Example
#>

[CmdLetBinding()]
param(
)

if($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
    $VerbosePreference = "Continue"
}
Write-Verbose "Verbose is on"

# Set scriptversion for logging
$ScriptVersion = "0.0.10"

# Load core modules
Import-Module Microsoft.BDD.TaskSequenceModule -Scope Global
Import-Module PSDUtility

# Check for debug in PowerShell and TSEnv
if($TSEnv:PSDDebug -eq "YES"){
    $Global:PSDDebug = $true
}
if($PSDDebug -eq $true)
{
    $verbosePreference = "Continue"
}

Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Starting: $($MyInvocation.MyCommand.Name) - Version $ScriptVersion"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): The task sequencer log is located at $("$tsenv:_SMSTSLogPath\SMSTS.LOG"). For task sequence failures, please consult this log."
Write-PSDEvent -MessageID 41000 -severity 1 -Message "Starting: $($MyInvocation.MyCommand.Name)"

# Keep the logging out of the way

$currentLocalDataPath = Get-PSDLocalDataPath
if ($currentLocalDataPath -NotLike "X:\*")
{
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Stop-PSDLogging, need to keep the logging out of the way"
    Stop-PSDLogging
    $logPath = "X:\MININT\Logs"
    if ((Test-Path $logPath) -eq $false) {
        New-Item -ItemType Directory -Force -Path $logPath | Out-Null
    }
    Start-Transcript "$logPath\PSDPartition.ps1.log"
}

# Get the dynamic variable
foreach($i in (Get-ChildItem -Path TSEnv:)){
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property $($i.Name) is $($i.Value)"
	#Write-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Property $($i.Name) is $($i.Value)"
}

# Fetch Partitioning Information from task sequence
Show-PSDActionProgress -Message "Fetching Partition Information - Number of partitions: $tsenv:OSDPartitions - PartitionStyle: $tsenv:OSDPartitionStyle" -Step "1" -MaxStep "20"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Number of partitions to be created is $tsenv:OSDPartitions"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): PartitionStyle is $tsenv:OSDPartitionStyle"
#Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Number of partitions to be created is $tsenv:OSDPartitions"
#Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): PartitionStyle is $tsenv:OSDPartitionStyle"

# Get number of partitions from Task Sequence
$numofpart = $tsenv:OSDPartitions
$partitions = @()


# Fetch Partition Information from Task Sequence an write them into an array
for($x=0;$x -lt $numofpart;$x++) {
	
	$partitiontype = "OSDPartitions${x}Type"
	$partitionfs = "OSDPartitions${x}FileSystem"
	$partitionbootable = "OSDPartitions${x}Bootable"
	$partitionqf = "OSDPartitions${x}QuickFormat"
	$partitionvn = "OSDPartitions${x}VolumeName"
	$partitionsize = "OSDPartitions${x}Size"
	$partitionsu = "OSDPartitions${x}SizeUnits"
	$partitionvlv = "OSDPartitions${x}VolumeLetterVariable"
	
	# Check if environmental variable exists
    foreach ($var in @($partitiontype, $partitionfs, $partitionbootable, $partitionqf, $partitionvn, $partitionsize, $partitionsu, $partitionvlv)) {
		
		# Get TSEnv Variables and their values and check it they are empty and write them into an array
        if (Test-Path "tsenv:\$var") {
            
			$item = Get-Item -Path "tsenv:\$var"
			$partitions += $item
            
        } else {
            
            Set-Item -Path "tsenv:\$var" -Value "null"

			$item = Get-Item -Path "tsenv:\$var"
			$partitions += $item
  
        }
		
		# Create Log Messages
		$itemName = $item.Name
        $itemValue = $item.Value
		
		Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property: $itemName is $itemValue"
		# Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Property: $itemName is $itemValue"
    }
	
	
}


# If System is UEFI
if ($tsenv:IsUEFI -eq "True"){
	
	# UEFI partitioning
	Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): UEFI partitioning"
	
	# Partition and format the disk
	Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Partition and format the disk [$tsenv:OSDDiskIndex]"
	Show-PSDActionProgress -Message "Partition and format disk [$tsenv:OSDDiskIndex]" -Step "2" -MaxStep "20"
	
	# Get Disk
	Update-Disk -Number $tsenv:OSDDiskIndex
	$disk = Get-Disk -Number $tsenv:OSDDiskIndex
	
	# Clean the disk if it isn't raw	
	Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Clean the disk if it isn't raw"
	#Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Clean the disk if it isn't raw"
	if ($disk.PartitionStyle -ne "RAW")
	{
		Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Clearing disk"
		Show-PSDActionProgress -Message "Clearing disk" -Step "3" -MaxStep "20"
		Clear-Disk -Number $tsenv:OSDDiskIndex -RemoveData -RemoveOEM -Confirm:$false
		# Clear-PSDDisk -Number $tsenv:OSDDiskIndex
		#Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Cleared disk"
		
		Update-Disk -Number $tsenv:OSDDiskIndex
		$disk = Get-Disk -Number $tsenv:OSDDiskIndex
	}
	
	
	# Initialize the disk
	Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Initialize the disk"
	Show-PSDActionProgress -Message "Initialize the disk" -Step "4" -MaxStep "20"
	Initialize-Disk -Number $tsenv:OSDDiskIndex -PartitionStyle $tsenv:OSDPartitionStyle
	# Get-Disk -Number $tsenv:OSDDiskIndex

	
	# Convert the disk sizes
	# 1GB = 1073741824 Byte
	$disksize = $disk.Size # size in Bytes
	$disksizeGB = $disk.Size / 1GB # size in GB
	$disksizeMB = $disk.Size / 1MB # size in MB
	$disksizeKB = $disk.Size / 1KB # size in KB
	# Show-PSDInfo -Message "Disk size in Byte: $disksize; In KB: $disksizeKB; In MB: $disksizeMB; In GB: $disksizeGB"
	
	# System Precheck for minimum reqired number of partitions (EFI, MSR, OS, Recovery, ...)
	if($numofpart -lt 4) {
		Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Disk [$tsenv:OSDDiskIndex] can not be partitioned. Your number of partitions < $numofpart > is insufficient for an UEFI system. Please check if you have at least EFI, MSR, Recovery and OS partitions configured."
		Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Disk [$tsenv:OSDDiskIndex] can not be partitioned. Your number of partitions < $numofpart > is insufficient for an UEFI system. Please check if you have at least EFI, MSR, Recovery and OS partitions configured." -Severity Error
		Exit 1
	}
	elseif($numofpart -eq 4) {
		<#
		First get all parameters where "OSDPartitions[0-n]*" is defined and write them into their own array
		Then convert all the values into new variables (mostly String and the sizes in UInt64)
		Now we can work dynamically with the parameters set in the TS and do not have to hard code it here
		
		I Comment the details for "Partion 0" Partition only, because it is repetetive.
		#>
		
		#### 
		#### Get partitioning information for Partition 0
		####
		
		$partition0 = @()
		# Fill the array
		$partition0 += $partitions | Where-Object {$_.Name -like "OSDPartitions0*"}
		
		$part0typeValue = $partition0 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		# String for Log and Output
		$part0type = $part0typeValue.Value
		
		$part0fsValue = $partition0 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		# String for Log and Output
		$part0fs = $part0fsValue.Value
		
		$part0qfValue = $partition0 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		# String for Log and Output
		$part0qfable = $part0qfValue.Value
		
		$part0vnValue = $partition0 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		# String for Log and Output
		$part0vn = $part0vnValue.Value
		
		$part0sizeValue = $partition0 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part0sizeUnit = $partition0 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value
		##### Check if size of partition is in % and recalculate the size in MB
		if($part0sizeUnit.Value -eq "%")
		{
			
			$part0sizeUnit.Value = "Byte"
			$remainingsize = $disksize - 1073741824
			$percentage = $part0sizeValue.Value / 100
			
			[UInt64]$part0sizeInt = $remainingsize * $percentage

		}
		elseif($part0sizeUnit.Value -eq "MB") {
			$part0sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part0sizeInt = $part0sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part0sizeInt = [UInt64]$part0sizeInt * 1MB
		}
		elseif($part0sizeUnit.Value -eq "GB") {
			$part0sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part0sizeInt = $part0sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part0sizeInt = [UInt64]$part0sizeInt * 1GB
		}
		
		$part0size = "$part0sizeInt"+$part0sizeUnit.Value
		
		$part0vlvValue = $partition0 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		# String for Log and Output
		$part0vlv = $part0vlvValue.Value
		
		
		#### 
		#### Get partitioning information for Partition 1 
		####		
		$partition1 = @()
		$partition1 += $partitions | Where-Object {$_.Name -like "OSDPartitions1*"}
		
		$part1typeValue = $partition1 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		$part1type = $part1typeValue.Value
		
		$part1fsValue = $partition1 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		$part1fs = $part1fsValue.Value
		
		$part1qfValue = $partition1 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		$part1qfable = $part1qfValue.Value
		
		$part1vnValue = $partition1 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		$part1vn = $part1vnValue.Value
		
		$part1sizeValue = $partition1 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part1sizeUnit = $partition1 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value
		##### Check if size of partition is in % and recalculate the size in MB
		if($part1sizeUnit.Value -eq "%")
		{
			
			$part1sizeUnit.Value = "Byte"
			$remainingsize = $disksize - $part0sizeInt - 1073741824
			$percentage = $part1sizeValue.Value / 100
			
			[UInt64]$part1sizeInt = $remainingsize * $percentage

		}
		elseif($part1sizeUnit.Value -eq "MB") {
			$part1sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part1sizeInt = $part1sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part1sizeInt = [UInt64]$part1sizeInt * 1MB
		}
		elseif($part1sizeUnit.Value -eq "GB") {
			$part1sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part1sizeInt = $part1sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part1sizeInt = [UInt64]$part1sizeInt * 1GB
		}
		
		$part1size = "$part1sizeInt"+$part1sizeUnit.Value
		
		$part1vlvValue = $partition1 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		$part1vlv = $part1vlvValue.Value
		
		
		#### 
		#### Get partitioning information for Partition 2 
		####		
		$partition2 = @()
		$partition2 += $partitions | Where-Object {$_.Name -like "OSDPartitions2*"}
		
		$part2typeValue = $partition2 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		$part2type = $part2typeValue.Value
		
		$part2fsValue = $partition2 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		$part2fs = $part2fsValue.Value
		
		$part2qfValue = $partition2 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		$part2qfable = $part2qfValue.Value
		
		$part2vnValue = $partition2 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		$part2vn = $part2vnValue.Value
		
		$part2sizeValue = $partition2 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part2sizeUnit = $partition2 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value
		##### Check if size of partition is in % and recalculate the size in MB
		if($part2sizeUnit.Value -eq "%")
		{
			
			$part2sizeUnit.Value = "Byte"
			$remainingsize = $disksize - $part0sizeInt - $part1sizeInt - 1073741824
			$percentage = $part2sizeValue.Value / 100
			
			[UInt64]$part2sizeInt = $remainingsize * $percentage

		}
		elseif($part2sizeUnit.Value -eq "MB") {
			$part2sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part2sizeInt = $part2sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part2sizeInt = [UInt64]$part2sizeInt * 1MB
		}
		elseif($part2sizeUnit.Value -eq "GB") {
			$part2sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part2sizeInt = $part2sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part2sizeInt = [UInt64]$part2sizeInt * 1GB
		}
		
		$part2size = "$part2sizeInt"+$part2sizeUnit.Value
		
		
		$part2vlvValue = $partition2 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		$part2vlv = $part2vlvValue.Value
		
		
		#### 
		#### Get partitioning information for Partition 3 
		####		
		$partition3 = @()
		$partition3 += $partitions | Where-Object {$_.Name -like "OSDPartitions3*"}
		
		$part3typeValue = $partition3 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		$part3type = $part3typeValue.Value
		
		$part3fsValue = $partition3 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		$part3fs = $part3fsValue.Value
		
		$part3qfValue = $partition3 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		$part3qfable = $part3qfValue.Value
		
		$part3vnValue = $partition3 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		$part3vn = $part3vnValue.Value
		
		$part3sizeValue = $partition3 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part3sizeUnit = $partition3 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value
		##### Check if size of partition is in % and recalculate the size in MB
		if($part3sizeUnit.Value -eq "%")
		{
			
			$part3sizeUnit.Value = "Byte"
			$remainingsize = $disksize - $part0sizeInt - $part1sizeInt - $part2sizeInt - 1073741824
			$percentage = $part2sizeValue.Value / 100
			
			[UInt64]$part3sizeInt = $remainingsize * $percentage

		}
		elseif($part3sizeUnit.Value -eq "MB") {
			$part3sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part3sizeInt = $part3sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part3sizeInt = [UInt64]$part3sizeInt * 1MB
		}
		elseif($part3sizeUnit.Value -eq "GB") {
			$part3sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part3sizeInt = $part3sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part3sizeInt = [UInt64]$part3sizeInt * 1GB
		}
		
		$part3size = "$part3sizeInt"+$part3sizeUnit.Value
		

		$part3vlvValue = $partition3 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		$part3vlv = $part3vlvValue.Value


		# Now we are checking, if the configured size of partitions in the TS is exceeding the overall disk Size
		# This value is in "Bytes"!
		$sumpartsize = $part0sizeInt + $part1sizeInt + $part2sizeInt + $part3sizeInt
		# Reconvert this to at least MB for better readability
		$sumpartsizeKB = $sumpartsize / 1KB
		$sumpartsizeKB = [Math]::Round($sumpartsizeKB, 2)
		
		$sumpartsizeMB = $sumpartsize / 1MB
		$sumpartsizeMB = [Math]::Round($sumpartsizeMB, 2)
		
		$sumpartsizeGB = $sumpartsize / 1GB
		$sumpartsizeGB = [Math]::Round($sumpartsizeGB, 2)
		
		# Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Sum of Partitioned Size: ${sumpartsize}Bytes; ${sumpartsizeKB}KB; ${sumpartsizeMB}MB; ${sumpartsizeGB}GB." # $part0sizeInt, $part1sizeInt, $part2sizeInt, $part3sizeInt"
	
	}
	elseif($numofpart -eq 5) {
		
		<#
		First get all parameters where "OSDPartitions[0-n]*" is defined and write them into their own array
		Then convert all the values into new variables (mostly String and the sizes in UInt64)
		Now we can work dynamically with the parameters set in the TS and do not have to hard code it here
		
		I Comment the details for "Partion 0" Partition only, because it is repetetive.
		#>
		
		#### 
		#### Get partitioning information for Partition 0
		####
		
		$partition0 = @()
		# Fill the array
		$partition0 += $partitions | Where-Object {$_.Name -like "OSDPartitions0*"}
		
		$part0typeValue = $partition0 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		# String for Log and Output
		$part0type = $part0typeValue.Value
		
		$part0fsValue = $partition0 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		# String for Log and Output
		$part0fs = $part0fsValue.Value
		
		$part0qfValue = $partition0 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		# String for Log and Output
		$part0qfable = $part0qfValue.Value
		
		$part0vnValue = $partition0 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		# String for Log and Output
		$part0vn = $part0vnValue.Value
		
		$part0sizeValue = $partition0 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part0sizeUnit = $partition0 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value
		##### Check if size of partition is in % and recalculate the size in MB
		if($part0sizeUnit.Value -eq "%")
		{
			
			$part0sizeUnit.Value = "Byte"
			$remainingsize = $disksize - 1073741824
			$percentage = $part0sizeValue.Value / 100
			
			[UInt64]$part0sizeInt = $remainingsize * $percentage

		}
		elseif($part0sizeUnit.Value -eq "MB") {
			$part0sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part0sizeInt = $part0sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part0sizeInt = [UInt64]$part0sizeInt * 1MB
		}
		elseif($part0sizeUnit.Value -eq "GB") {
			$part0sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part0sizeInt = $part0sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part0sizeInt = [UInt64]$part0sizeInt * 1GB
		}
		
		$part0size = "$part0sizeInt"+$part0sizeUnit.Value
		
		$part0vlvValue = $partition0 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		# String for Log and Output
		$part0vlv = $part0vlvValue.Value
		
		
		#### 
		#### Get partitioning information for Partition 1 
		####		
		$partition1 = @()
		$partition1 += $partitions | Where-Object {$_.Name -like "OSDPartitions1*"}
		
		$part1typeValue = $partition1 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		$part1type = $part1typeValue.Value
		
		$part1fsValue = $partition1 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		$part1fs = $part1fsValue.Value
		
		$part1qfValue = $partition1 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		$part1qfable = $part1qfValue.Value
		
		$part1vnValue = $partition1 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		$part1vn = $part1vnValue.Value
		
		$part1sizeValue = $partition1 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part1sizeUnit = $partition1 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value
		##### Check if size of partition is in % and recalculate the size in MB
		if($part1sizeUnit.Value -eq "%")
		{
			
			$part1sizeUnit.Value = "Byte"
			$remainingsize = $disksize - $part0sizeInt - 1073741824
			$percentage = $part1sizeValue.Value / 100
			
			[UInt64]$part1sizeInt = $remainingsize * $percentage

		}
		elseif($part1sizeUnit.Value -eq "MB") {
			$part1sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part1sizeInt = $part1sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part1sizeInt = [UInt64]$part1sizeInt * 1MB
		}
		elseif($part1sizeUnit.Value -eq "GB") {
			$part1sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part1sizeInt = $part1sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part1sizeInt = [UInt64]$part1sizeInt * 1GB
		}
		
		$part1size = "$part1sizeInt"+$part1sizeUnit.Value
		
		$part1vlvValue = $partition1 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		$part1vlv = $part1vlvValue.Value
		
		
		
		#### 
		#### Get partitioning information for Partition 2 
		####		
		$partition2 = @()
		$partition2 += $partitions | Where-Object {$_.Name -like "OSDPartitions2*"}
		
		$part2typeValue = $partition2 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		$part2type = $part2typeValue.Value
		
		$part2fsValue = $partition2 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		$part2fs = $part2fsValue.Value
		
		$part2qfValue = $partition2 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		$part2qfable = $part2qfValue.Value
		
		$part2vnValue = $partition2 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		$part2vn = $part2vnValue.Value
		
		$part2sizeValue = $partition2 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part2sizeUnit = $partition2 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value		
		##### Check if size of partition is in % and recalculate the size in MB
		if($part2sizeUnit.Value -eq "%")
		{
			
			$part2sizeUnit.Value = "Byte"
			$remainingsize = $disksize - $part0sizeInt - $part1sizeInt - 1073741824
			$percentage = $part2sizeValue.Value / 100
			
			[UInt64]$part2sizeInt = $remainingsize * $percentage

		}
		elseif($part2sizeUnit.Value -eq "MB") {
			$part2sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part2sizeInt = $part2sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part2sizeInt = [UInt64]$part2sizeInt * 1MB
		}
		elseif($part2sizeUnit.Value -eq "GB") {
			$part2sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part2sizeInt = $part2sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part2sizeInt = [UInt64]$part2sizeInt * 1GB
		}
		
		$part2size = "$part2sizeInt"+$part2sizeUnit.Value
		
		
		$part2vlvValue = $partition2 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		$part2vlv = $part2vlvValue.Value
		
		
		#### 
		#### Get partitioning information for Partition 3 
		####		
		$partition3 = @()
		$partition3 += $partitions | Where-Object {$_.Name -like "OSDPartitions3*"}
		
		$part3typeValue = $partition3 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		$part3type = $part3typeValue.Value
		
		$part3fsValue = $partition3 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		$part3fs = $part3fsValue.Value
		
		$part3qfValue = $partition3 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		$part3qfable = $part3qfValue.Value
		
		$part3vnValue = $partition3 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		$part3vn = $part3vnValue.Value
		
		$part3sizeValue = $partition3 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part3sizeUnit = $partition3 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value
		##### Check if size of partition is in % and recalculate the size in MB
		if($part3sizeUnit.Value -eq "%")
		{
			
			$part3sizeUnit.Value = "Byte"
			$remainingsize = $disksize - $part0sizeInt - $part1sizeInt - $part2sizeInt - 1073741824
			$percentage = $part3sizeValue.Value / 100
			
			[UInt64]$part3sizeInt = $remainingsize * $percentage

		}
		elseif($part3sizeUnit.Value -eq "MB") {
			$part3sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part3sizeInt = $part3sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part3sizeInt = [UInt64]$part3sizeInt * 1MB
		}
		elseif($part3sizeUnit.Value -eq "GB") {
			$part3sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part3sizeInt = $part3sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part3sizeInt = [UInt64]$part3sizeInt * 1GB
		}
		
		$part3size = "$part3sizeInt"+$part3sizeUnit.Value

		$part3vlvValue = $partition3 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		$part3vlv = $part3vlvValue.Value
		
		
		#### 
		#### Get partitioning information for Partition 4
		####		
		$partition4 = @()
		$partition4 += $partitions | Where-Object {$_.Name -like "OSDPartitions4*"}
		
		$part4typeValue = $partition4 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		$part4type = $part4typeValue.Value
		
		$part4fsValue = $partition4 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		$part4fs = $part4fsValue.Value
		
		$part4qfValue = $partition4 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		$part4qfable = $part4qfValue.Value
		
		$part4vnValue = $partition4 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		$part4vn = $part4vnValue.Value
		
		$part4sizeValue = $partition4 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part4sizeUnit = $partition4 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value
		##### Check if size of partition is in % and recalculate the size in MB
		if($part4sizeUnit.Value -eq "%")
		{
			
			$part4sizeUnit.Value = "Byte"
			$remainingsize = $disksize - $part0sizeInt - $part1sizeInt - $part2sizeInt - $part3sizeInt - 1073741824
			$percentage = $part4sizeValue.Value / 100
			
			[UInt64]$part4sizeInt = $remainingsize * $percentage

		}
		elseif($part4sizeUnit.Value -eq "MB") {
			$part4sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part4sizeInt = $part4sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part4sizeInt = [UInt64]$part4sizeInt * 1MB
		}
		elseif($part4sizeUnit.Value -eq "GB") {
			$part4sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part4sizeInt = $part4sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part4sizeInt = [UInt64]$part4sizeInt * 1GB
		}
		
		$part4size = "$part4sizeInt"+$part4sizeUnit.Value
		
		
		$part4vlvValue = $partition4 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		$part4vlv = $part4vlvValue.Value
		
		# Now we are checking, if the configured size of partitions in the TS is exceeding the overall disk Size
		# This value is in "Bytes"!
		$sumpartsize = $part0sizeInt + $part1sizeInt + $part2sizeInt + $part3sizeInt + $part4sizeInt
		# Reconvert this to at least MB for better readability
		$sumpartsizeKB = $sumpartsize / 1KB
		$sumpartsizeKB = [Math]::Round($sumpartsizeKB, 2)
		
		$sumpartsizeMB = $sumpartsize / 1MB
		$sumpartsizeMB = [Math]::Round($sumpartsizeMB, 2)
		
		$sumpartsizeGB = $sumpartsize / 1GB
		$sumpartsizeGB = [Math]::Round($sumpartsizeGB, 2)
		
		# Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Sum of Partitioned Size: ${sumpartsize}Bytes; ${sumpartsizeKB}KB; ${sumpartsizeMB}MB; ${sumpartsizeGB}GB." # $part0sizeInt, $part1sizeInt, $part2sizeInt, $part3sizeInt, $part4sizeInt"
	
	}
	elseif($numofpart -gt 5) {
		Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Disk [$tsenv:OSDDiskIndex] can not be partitioned. Your number of partitions < $numofpart > exceeds the maximum supported number of partitions. Please check if you have only EFI, MSR, Recovery, OS and one Data partition configured."
		Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Disk [$tsenv:OSDDiskIndex] can not be partitioned. Your number of partitions < $numofpart > exceeds the maximum supported number of partitions. Please check if you have only EFI, MSR, Recovery, OS and one Data partition configured." -Severity Error
		Exit 1
	}
	
	# Check if the disk size is enough for your partitioned size
	if($disksizeGB -lt $sumpartsizeGB) {
		Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Disk [$tsenv:OSDDiskIndex] can not be partitioned. Your disk size is lower then the size you want to deploy. Disksize: ${disksizeGB} - Needed Size: ${sumpartsizeGB}"
		Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Disk [$tsenv:OSDDiskIndex] can not be partitioned. Your disk size is lower then the size you want to deploy. Disksize: ${disksizeGB} - Needed Size: ${sumpartsizeGB}" -Severity Error
		Exit 1
	}
	elseif($disksizeGB -ge $sumpartsizeGB) {
		if($numofpart -eq 4) {
			
			### 
			### Create partitions 
			###
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partitions"
			Show-PSDActionProgress -Message "Create the paritions" -Step "5" -MaxStep "20"
			
			#### Partition0: Boot Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 0 - Type: $part0type - FileSystem: $part0fs - Bootable: $part0bootable - QuickFormat: $part0qf - VolumeName: $part0vn - Size and Unit: $part0size - VolumeVariable: $part0vlv"
			Show-PSDActionProgress -Message "Create the EFI partition" -Step "6" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 0 - Type: $part0type - FileSystem: $part0fs - VolumeName: $part0vn - Size: $part0size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 0 - Type: $part0type - FileSystem: $part0fs - VolumeName: $part0vn - Size: $part0size"
			try{
				#$efi = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size 499MB -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'
				$efi = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part0sizeInt -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'
			}
			catch {
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 0"
				Show-PSDInfo -Message "Partition 0: $_" -Severity Error
				Exit 1
			}
			
			#### Partition1: MSR Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 1 - Type: $part1type - FileSystem: $part1fs - Bootable: $part1bootable - QuickFormat: $part1qf - VolumeName: $part1vn - Size and Unit: $part1size - VolumeVariable: $part1vlv"
			Show-PSDActionProgress -Message "Create the MSR partition" -Step "7" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 1 - Type: $type - FileSystem: $part1fs - VolumeName: $part1vn - Size: $part1size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 1 - Type: $part1type - FileSystem: $part1fs - VolumeName: $part1vn - Size: $part1size"
			try{
				#$msr = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size 128MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
				$msr = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part1sizeInt -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 1"
				Show-PSDInfo -Message "Partition 1: $_" -Severity Error
				Exit 1
			}
			
			#### Partition2: OS Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 2 - Type: $part2type - FileSystem: $part2fs - Bootable: $part2bootable - QuickFormat: $part2qf - VolumeName: $part2vn - Size and Unit: $part2size - VolumeVariable: $part2vlv"
			Show-PSDActionProgress -Message "Create the OS partition" -Step "8" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 2 - Type: $part2type - FileSystem: $part2fs - VolumeName: $part2vn - Size: $part2size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 2 - Type: $part2type - FileSystem: $part2fs - VolumeName: $part2vn - Size: $part2size"
			try{
				#$os = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size -Size 153600MB
				$os = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part2sizeInt
			}
			catch {
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 2"
				Show-PSDInfo -Message "Partition 2: $_" -Severity Error
				Exit 1
			}
			
			
			#### Partition3: Recovery Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 3 - Type: $part3type - FileSystem: $part3fs - Bootable: $part3bootable - QuickFormat: $part3qf - VolumeName: $part3vn - Size and Unit: $part3size - VolumeVariable: $part3vlv"
			Show-PSDActionProgress -Message "Create the Recovery partition" -Step "9" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 3 - Type: $part3type - FileSystem: $part3fs - VolumeName: $part3vn - Size: $part3size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 3 - Type: $part3type - FileSystem: $part3fs - VolumeName: $part3vn - Size: $part3size"
			try{
				#$recovery = New-Partition -DiskNumber $tsenv:OSDDiskIndex -UseMaximumSize -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'
				$recovery = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part3sizeInt -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 3"
				Show-PSDInfo -Message "Partition 3: $_" -Severity Error
				Exit 1
			}
			
			
			
			#### 
			#### Assign driveletters
			####
		
			#### Assign driveletter to Boot
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Assigning drivletter for $part0type"
			try{
				$efi | Set-Partition -NewDriveLetter "W"
			}
			catch {
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not assign drive letter for partition 0"
				Show-PSDInfo -Message "Partition EFI: $_" -Severity Error
				Exit 1
			}
			Show-PSDActionProgress -Message "Assigning drivletter for $part0type" -Step "10" -MaxStep "20"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $part0type is set to W:"
			
			##### Save the drive letters and volume GUIDs to task sequence variables
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs for EFI to task sequence variables"
			$tsenv:BootVolume = "W"
			$tsenv:BootVolumeGuid = $efi.Guid
			
			
			#### Assign driveletter to OS
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Assigning drivletter for $part2type"
			try{
				$os | Set-Partition -NewDriveLetter "S"
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not assign drive letter for partition 2"
				Show-PSDInfo -Message "Partition OS: $_" -Severity Error
				Exit 1			
			}
			Show-PSDActionProgress -Message "Assigning drivletter for $part2type" -Step "11" -MaxStep "20"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $type is set to S:"
			##### Save the drive letters and volume GUIDs to task sequence variables
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs for OS to task sequence variables"
			$tsenv:OSVolume = "S"
			$tsenv:OSVolumeGuid = $os.Guid
			
			
			#### Assign driveletter to Recovery
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Assigning drivletter for $part3type"
			try{
				$recovery | Set-Partition -NewDriveLetter "R"
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not assign drive letter for partition 3"
				Show-PSDInfo -Message "Partition Recovery: $_" -Severity Error
				Exit 1			
			}
			Show-PSDActionProgress -Message "Assigning drivletter for $part3type" -Step "12" -MaxStep "20"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $part3type is set to R:"		
			##### Save the drive letters and volume GUIDs to task sequence variables
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs for Recovery to task sequence variables"
			$tsenv:RecoveryVolume = "R"
			$tsenv:RecoveryVolumeGuid = $recovery.Guid
			

			
			#### 
			#### Format the volumes
			####
			
			### Format the boot volume
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format $part0type volume as $part0fs and label it as $part0vn"
			Show-PSDActionProgress -Message "Format $part0type volume as $part0fs and label it as $part0vn" -Step "13" -MaxStep "20"
			try{
				#Format-Volume -DriveLetter $tsenv:BootVolume -FileSystem FAT32 -NewFileSystemLabel Boot
				Format-Volume -DriveLetter $tsenv:BootVolume -FileSystem $part0fs -NewFileSystemLabel $part0vn
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not format boot volume"
				Show-PSDInfo -Message "Volume Boot: $_" -Severity Error
				Exit 1			
			}
			
			### Format the OS volume
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format $part2type volume as $part2fs and label it as $part2vn"
			Show-PSDActionProgress -Message "Format $part2type volume as $part2fs and label it as $part2vn" -Step "14" -MaxStep "20"
			try{
				#Format-Volume -DriveLetter $tsenv:OSVolume -FileSystem NTFS -NewFileSystemLabel Windows
				Format-Volume -DriveLetter $tsenv:OSVolume -FileSystem $part2fs -NewFileSystemLabel $part2vn
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not format OS volume"
				Show-PSDInfo -Message "Volume OS: $_" -Severity Error
				Exit 1			
			}
			### Format the recovery volume
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format $part3type volume as $part3fs and label it as $part3vn"
			Show-PSDActionProgress -Message "Format $part3type volume as $part3fs and label it as $part3vn" -Step "15" -MaxStep "20"
			try{
				#Format-Volume -DriveLetter $tsenv:RecoveryVolume -FileSystem NTFS -NewFileSystemLabel Recovery
				Format-Volume -DriveLetter $tsenv:RecoveryVolume -FileSystem $part3fs -NewFileSystemLabel $part3vn
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not format recovery volume"
				Show-PSDInfo -Message "Volume Recovery: $_" -Severity Error
				Exit 1			
			}
		}
		if($numofpart -eq 5) {
			
			
			### 
			### Create partitions 
			###
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partitions"
			Show-PSDActionProgress -Message "Create the paritions" -Step "5" -MaxStep "20"
			
			#### Partition0: Boot Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 0 - Type: $part0type - FileSystem: $part0fs - Bootable: $part0bootable - QuickFormat: $part0qf - VolumeName: $part0vn - Size and Unit: $part0size - VolumeVariable: $part0vlv"
			Show-PSDActionProgress -Message "Create the EFI partition" -Step "6" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 0 - Type: $part0type - FileSystem: $part0fs - VolumeName: $part0vn - Size: $part0size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 0 - Type: $part0type - FileSystem: $part0fs - VolumeName: $part0vn - Size: $part0size"
			try{
				#$efi = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size 499MB -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'
				$efi = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part0sizeInt -GptType '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'
			}
			catch {
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 0"
				Show-PSDInfo -Message "Partition 0: $_" -Severity Error
				Exit 1
			}
			
			#### Partition1: MSR Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 1 - Type: $part1type - FileSystem: $part1fs - Bootable: $part1bootable - QuickFormat: $part1qf - VolumeName: $part1vn - Size and Unit: $part1size - VolumeVariable: $part1vlv"
			Show-PSDActionProgress -Message "Create the MSR partition" -Step "7" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 1 - Type: $type - FileSystem: $part1fs - VolumeName: $part1vn - Size: $part1size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 1 - Type: $part1type - FileSystem: $part1fs - VolumeName: $part1vn - Size: $part1size"
			try{
				#$msr = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size 128MB -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
				$msr = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part1sizeInt -GptType '{e3c9e316-0b5c-4db8-817d-f92df00215ae}'
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 1"
				Show-PSDInfo -Message "Partition 1: $_" -Severity Error
				Exit 1
			}
			
			#### Partition2: OS Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 2 - Type: $part2type - FileSystem: $part2fs - Bootable: $part2bootable - QuickFormat: $part2qf - VolumeName: $part2vn - Size and Unit: $part2size - VolumeVariable: $part2vlv"
			Show-PSDActionProgress -Message "Create the OS partition" -Step "8" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 2 - Type: $part2type - FileSystem: $part2fs - VolumeName: $part2vn - Size: $part2size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 2 - Type: $part2type - FileSystem: $part2fs - VolumeName: $part2vn - Size: $part2size"
			try{
				#$os = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size -Size 153600MB
				$os = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part2sizeInt
			}
			catch {
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 2"
				Show-PSDInfo -Message "Partition 2: $_" -Severity Error
				Exit 1
			}
			
			
			#### Partition3: Recovery Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 3 - Type: $part3type - FileSystem: $part3fs - Bootable: $part3bootable - QuickFormat: $part3qf - VolumeName: $part3vn - Size and Unit: $part3size - VolumeVariable: $part3vlv"
			Show-PSDActionProgress -Message "Create the Recovery partition" -Step "9" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 3 - Type: $part3type - FileSystem: $part3fs - VolumeName: $part3vn - Size: $part3size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 3 - Type: $part3type - FileSystem: $part3fs - VolumeName: $part3vn - Size: $part3size"
			try{
				#$recovery = New-Partition -DiskNumber $tsenv:OSDDiskIndex -UseMaximumSize -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'
				$recovery = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part3sizeInt -GptType '{de94bba4-06d1-4d40-a16a-bfd50179d6ac}'
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 3"
				Show-PSDInfo -Message "Partition 3: $_" -Severity Error
				Exit 1
			}
						
			#### Partition4: Data Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 4 - Type: $part4type - FileSystem: $part4fs - Bootable: $part4bootable - QuickFormat: $part4qf - VolumeName: $part4vn - Size and Unit: $part4size - VolumeVariable: $part4vlv"
			Show-PSDActionProgress -Message "Create the Data partition" -Step "10" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 4 - Type: $part4type - FileSystem: $part4fs - VolumeName: $part4vn - Size: $part4size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 4 - Type: $part4type - FileSystem: $part4fs - VolumeName: $part4vn - Size: $part4size"
			try{
				$data = New-Partition -DiskNumber $tsenv:OSDDiskIndex -UseMaximumSize
				#$data = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part4sizeInt
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 4"
				Show-PSDInfo -Message "Partition 4: $_" -Severity Error
				Exit 1
			}
			##### Check if size of partition is in % and recalculate the size in MB
			##### Obsolete, because we use the maximum remaining size
						
			
			
			#### 
			#### Assign driveletters
			####
		
			#### Assign driveletter to Boot
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Assigning driveletter for $part0type"
			try{
				$efi | Set-Partition -NewDriveLetter "W"
			}
			catch {
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not assign drive letter for partition 0"
				Show-PSDInfo -Message "Partition EFI: $_" -Severity Error
				Exit 1
			}
			Show-PSDActionProgress -Message "Assigning driveletter for $part0type" -Step "11" -MaxStep "20"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $part0type is set to W:"
			
			##### Save the drive letters and volume GUIDs to task sequence variables
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs for EFI to task sequence variables"
			$tsenv:BootVolume = "W"
			$tsenv:BootVolumeGuid = $efi.Guid
			
			
			#### Assign driveletter to OS
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Assigning driveletter for $part2type"
			try{
				$os | Set-Partition -NewDriveLetter "S"
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not assign drive letter for partition 2"
				Show-PSDInfo -Message "Partition OS: $_" -Severity Error
				Exit 1			
			}
			Show-PSDActionProgress -Message "Assigning driveletter for $part2type" -Step "12" -MaxStep "20"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $type is set to S:"
			##### Save the drive letters and volume GUIDs to task sequence variables
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs for OS to task sequence variables"
			$tsenv:OSVolume = "S"
			$tsenv:OSVolumeGuid = $os.Guid
			
			
			#### Assign driveletter to Recovery
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Assigning driveletter for $part3type"
			try{
				$recovery | Set-Partition -NewDriveLetter "R"
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not assign drive letter for partition 3"
				Show-PSDInfo -Message "Partition Recovery: $_" -Severity Error
				Exit 1			
			}
			Show-PSDActionProgress -Message "Assigning driveletter for $part3type" -Step "13" -MaxStep "20"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $part3type is set to R:"		
			##### Save the drive letters and volume GUIDs to task sequence variables
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs for Recovery to task sequence variables"
			$tsenv:RecoveryVolume = "R"
			$tsenv:RecoveryVolumeGuid = $recovery.Guid
			
			
			#### Assign driveletter to Data
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Assigning driveletter for $part4type"
			try{
				$data | Set-Partition -NewDriveLetter "D"
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not assign drive letter for partition 4"
				Show-PSDInfo -Message "Partition Data: $_" -Severity Error
				Exit 1			
			}
			Show-PSDActionProgress -Message "Assigning driveletter for $part4type" -Step "14" -MaxStep "20"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $part4type is set to D:"		
			##### Save the drive letters and volume GUIDs to task sequence variables
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs for Data to task sequence variables"
			$tsenv:DataVolume = "D"
			$tsenv:DataVolumeGuid = $data.Guid
			

			
			#### 
			#### Format the volumes
			####
			
			### Format the boot volume
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format $part0type volume as $part0fs and label it as $part0vn"
			Show-PSDActionProgress -Message "Format $part0type volume as $part0fs and label it as $part0vn" -Step "15" -MaxStep "20"
			try{
				#Format-Volume -DriveLetter $tsenv:BootVolume -FileSystem FAT32 -NewFileSystemLabel Boot
				Format-Volume -DriveLetter $tsenv:BootVolume -FileSystem $part0fs -NewFileSystemLabel $part0vn
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not format boot volume"
				Show-PSDInfo -Message "Volume Boot: $_" -Severity Error
				Exit 1			
			}
			
			### Format the OS volume
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format $part2type volume as $part2fs and label it as $part2vn"
			Show-PSDActionProgress -Message "Format $part2type volume as $part2fs and label it as $part2vn" -Step "16" -MaxStep "20"
			try{
				#Format-Volume -DriveLetter $tsenv:OSVolume -FileSystem NTFS -NewFileSystemLabel Windows
				Format-Volume -DriveLetter $tsenv:OSVolume -FileSystem $part2fs -NewFileSystemLabel $part2vn
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not format OS volume"
				Show-PSDInfo -Message "Volume OS: $_" -Severity Error
				Exit 1			
			}
			
			### Format the recovery volume
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format $part3type volume as $part3fs and label it as $part3vn"
			Show-PSDActionProgress -Message "Format $part3type volume as $part3fs and label it as $part3vn" -Step "17" -MaxStep "20"
			try{
				#Format-Volume -DriveLetter $tsenv:RecoveryVolume -FileSystem NTFS -NewFileSystemLabel Recovery
				Format-Volume -DriveLetter $tsenv:RecoveryVolume -FileSystem $part3fs -NewFileSystemLabel $part3vn
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not format recovery volume"
				Show-PSDInfo -Message "Volume Recovery: $_" -Severity Error
				Exit 1			
			}
			
			### Format the data volume
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format $part4type volume as $part4fs and label it as $part4vn"
			Show-PSDActionProgress -Message "Format $part4type volume as $part4fs and label it as $part4vn" -Step "18" -MaxStep "20"
			try{
				#Format-Volume -DriveLetter $tsenv:DataVolume -FileSystem NTFS -NewFileSystemLabel Data
				Format-Volume -DriveLetter $tsenv:DataVolume -FileSystem $part4fs -NewFileSystemLabel $part4vn
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not format data volume"
				Show-PSDInfo -Message "Volume Data: $_" -Severity Error
				Exit 1			
			}
		}
	}
	
}

# If Sytsem is not UEFI
elseif($tsenv:IsUEFI -ne "True"){
	
	<# To DO! 
		- TESTING
		(But we do not support Legacy BIOS anymore...) 
	#>
	
	
	# BIOS partitioning
	Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): BIOS partitioning"
	
	# Partition and format the disk
	Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Partition and format the disk [$tsenv:OSDDiskIndex]"
	Show-PSDActionProgress -Message "Partition and format disk [$tsenv:OSDDiskIndex]" -Step "2" -MaxStep "20"
	
	# Get Disk
	Update-Disk -Number $tsenv:OSDDiskIndex
	$disk = Get-Disk -Number $tsenv:OSDDiskIndex
	
	# Clean the disk if it isn't raw	
	Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Clean the disk if it isn't raw"
	if ($disk.PartitionStyle -ne "RAW")
	{
		Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Clearing disk"
		Show-PSDActionProgress -Message "Clearing disk" -Step "3" -MaxStep "20"
		Clear-Disk -Number $tsenv:OSDDiskIndex -RemoveData -RemoveOEM -Confirm:$false
		# Clear-PSDDisk -Number $tsenv:OSDDiskIndex
	}	
	
	
	# Initialize the disk
	Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Initialize the disk"
	Show-PSDActionProgress -Message "Initialize the disk" -Step "4" -MaxStep "20"
	Initialize-Disk -Number $tsenv:OSDDiskIndex -PartitionStyle $tsenv:OSDPartitionStyle
	# Get-Disk -Number $tsenv:OSDDiskIndex
	

	# Convert the disk sizes
	# 1GB = 1073741824 Byte
	$disksize = $disk.Size # size in Bytes
	$disksizeGB = $disk.Size / 1GB # size in GB
	$disksizeMB = $disk.Size / 1MB # size in MB
	$disksizeKB = $disk.Size / 1KB # size in KB
	# Show-PSDInfo -Message "Disk size in Byte: $disksize; In KB: $disksizeKB; In MB: $disksizeMB; In GB: $disksizeGB"
	
	# System Precheck for minimum reqired number of partitions (EFI, MSR, OS, Recovery, ...)
	if($numofpart -lt 3) {
		Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Disk [$tsenv:OSDDiskIndex] can not be partitioned. Your number of partitions < $numofpart > is insufficient for an UEFI system. Please check if you have at least EFI, MSR, Recovery and OS partitions configured."
		Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Disk [$tsenv:OSDDiskIndex] can not be partitioned. Your number of partitions < $numofpart > is insufficient for an UEFI system. Please check if you have at least EFI, MSR, Recovery and OS partitions configured." -Severity Error
		Exit 1
	}
	elseif($numofpart -eq 3) {
		<#
		First get all parameters where "OSDPartitions[0-n]*" is defined and write them into their own array
		Then convert all the values into new variables (mostly String and the sizes in UInt64)
		Now we can work dynamically with the parameters set in the TS and do not have to hard code it here
		
		I Comment the details for "Partion 0" Partition only, because it is repetetive.
		#>
		
		#### 
		#### Get partitioning information for Partition 0
		####
		
		$partition0 = @()
		# Fill the array
		$partition0 += $partitions | Where-Object {$_.Name -like "OSDPartitions0*"}
		
		$part0typeValue = $partition0 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		# String for Log and Output
		$part0type = $part0typeValue.Value
		
		$part0fsValue = $partition0 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		# String for Log and Output
		$part0fs = $part0fsValue.Value
		
		$part0qfValue = $partition0 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		# String for Log and Output
		$part0qfable = $part0qfValue.Value
		
		$part0vnValue = $partition0 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		# String for Log and Output
		$part0vn = $part0vnValue.Value
		
		$part0sizeValue = $partition0 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part0sizeUnit = $partition0 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value
		##### Check if size of partition is in % and recalculate the size in MB
		if($part0sizeUnit.Value -eq "%")
		{
			
			$part0sizeUnit.Value = "Byte"
			$remainingsize = $disksize - 1073741824
			$percentage = $part0sizeValue.Value / 100
			
			[UInt64]$part0sizeInt = $remainingsize * $percentage

		}
		elseif($part0sizeUnit.Value -eq "MB") {
			$part0sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part0sizeInt = $part0sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part0sizeInt = [UInt64]$part0sizeInt * 1MB
		}
		elseif($part0sizeUnit.Value -eq "GB") {
			$part0sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part0sizeInt = $part0sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part0sizeInt = [UInt64]$part0sizeInt * 1GB
		}
		
		$part0size = "$part0sizeInt"+$part0sizeUnit.Value
		
		$part0vlvValue = $partition0 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		# String for Log and Output
		$part0vlv = $part0vlvValue.Value
		
		
		#### 
		#### Get partitioning information for Partition 1 
		####		
		$partition1 = @()
		$partition1 += $partitions | Where-Object {$_.Name -like "OSDPartitions1*"}
		
		$part1typeValue = $partition1 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		$part1type = $part1typeValue.Value
		
		$part1fsValue = $partition1 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		$part1fs = $part1fsValue.Value
		
		$part1qfValue = $partition1 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		$part1qfable = $part1qfValue.Value
		
		$part1vnValue = $partition1 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		$part1vn = $part1vnValue.Value
		
		$part1sizeValue = $partition1 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part1sizeUnit = $partition1 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value
		##### Check if size of partition is in % and recalculate the size in MB
		if($part1sizeUnit.Value -eq "%")
		{
			
			$part1sizeUnit.Value = "Byte"
			$remainingsize = $disksize - $part0sizeInt - 1073741824
			$percentage = $part1sizeValue.Value / 100
			
			[UInt64]$part1sizeInt = $remainingsize * $percentage

		}
		elseif($part1sizeUnit.Value -eq "MB") {
			$part1sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part1sizeInt = $part1sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part1sizeInt = [UInt64]$part1sizeInt * 1MB
		}
		elseif($part1sizeUnit.Value -eq "GB") {
			$part1sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part1sizeInt = $part1sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part1sizeInt = [UInt64]$part1sizeInt * 1GB
		}
		
		$part1size = "$part1sizeInt"+$part1sizeUnit.Value
		
		$part1vlvValue = $partition1 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		$part1vlv = $part1vlvValue.Value
		
		
		#### 
		#### Get partitioning information for Partition 2 
		####		
		$partition2 = @()
		$partition2 += $partitions | Where-Object {$_.Name -like "OSDPartitions2*"}
		
		$part2typeValue = $partition2 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		$part2type = $part2typeValue.Value
		
		$part2fsValue = $partition2 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		$part2fs = $part2fsValue.Value
		
		$part2qfValue = $partition2 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		$part2qfable = $part2qfValue.Value
		
		$part2vnValue = $partition2 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		$part2vn = $part2vnValue.Value
		
		$part2sizeValue = $partition2 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part2sizeUnit = $partition2 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value
		##### Check if size of partition is in % and recalculate the size in MB
		if($part2sizeUnit.Value -eq "%")
		{
			
			$part2sizeUnit.Value = "Byte"
			$remainingsize = $disksize - $part0sizeInt - $part1sizeInt - 1073741824
			$percentage = $part2sizeValue.Value / 100
			
			[UInt64]$part2sizeInt = $remainingsize * $percentage

		}
		elseif($part2sizeUnit.Value -eq "MB") {
			$part2sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part2sizeInt = $part2sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part2sizeInt = [UInt64]$part2sizeInt * 1MB
		}
		elseif($part2sizeUnit.Value -eq "GB") {
			$part2sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part2sizeInt = $part2sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part2sizeInt = [UInt64]$part2sizeInt * 1GB
		}
		
		$part2size = "$part2sizeInt"+$part2sizeUnit.Value
		
		
		$part2vlvValue = $partition2 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		$part2vlv = $part2vlvValue.Value
		
		
		# Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Sum of Partitioned Size: ${sumpartsize}Bytes; ${sumpartsizeKB}KB; ${sumpartsizeMB}MB; ${sumpartsizeGB}GB." # $part0sizeInt, $part1sizeInt, $part2sizeInt"
	
	}
	elseif($numofpart -eq 4) {
		
		<#
		First get all parameters where "OSDPartitions[0-n]*" is defined and write them into their own array
		Then convert all the values into new variables (mostly String and the sizes in UInt64)
		Now we can work dynamically with the parameters set in the TS and do not have to hard code it here
		
		I Comment the details for "Partion 0" Partition only, because it is repetetive.
		#>
		
		#### 
		#### Get partitioning information for Partition 0
		####
		
		$partition0 = @()
		# Fill the array
		$partition0 += $partitions | Where-Object {$_.Name -like "OSDPartitions0*"}
		
		$part0typeValue = $partition0 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		# String for Log and Output
		$part0type = $part0typeValue.Value
		
		$part0fsValue = $partition0 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		# String for Log and Output
		$part0fs = $part0fsValue.Value
		
		$part0qfValue = $partition0 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		# String for Log and Output
		$part0qfable = $part0qfValue.Value
		
		$part0vnValue = $partition0 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		# String for Log and Output
		$part0vn = $part0vnValue.Value
		
		$part0sizeValue = $partition0 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part0sizeUnit = $partition0 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value
		##### Check if size of partition is in % and recalculate the size in MB
		if($part0sizeUnit.Value -eq "%")
		{
			
			$part0sizeUnit.Value = "Byte"
			$remainingsize = $disksize - 1073741824
			$percentage = $part0sizeValue.Value / 100
			
			[UInt64]$part0sizeInt = $remainingsize * $percentage

		}
		elseif($part0sizeUnit.Value -eq "MB") {
			$part0sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part0sizeInt = $part0sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part0sizeInt = [UInt64]$part0sizeInt * 1MB
		}
		elseif($part0sizeUnit.Value -eq "GB") {
			$part0sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part0sizeInt = $part0sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part0sizeInt = [UInt64]$part0sizeInt * 1GB
		}
		
		$part0size = "$part0sizeInt"+$part0sizeUnit.Value
		
		$part0vlvValue = $partition0 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		# String for Log and Output
		$part0vlv = $part0vlvValue.Value
		
		
		#### 
		#### Get partitioning information for Partition 1 
		####		
		$partition1 = @()
		$partition1 += $partitions | Where-Object {$_.Name -like "OSDPartitions1*"}
		
		$part1typeValue = $partition1 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		$part1type = $part1typeValue.Value
		
		$part1fsValue = $partition1 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		$part1fs = $part1fsValue.Value
		
		$part1qfValue = $partition1 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		$part1qfable = $part1qfValue.Value
		
		$part1vnValue = $partition1 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		$part1vn = $part1vnValue.Value
		
		$part1sizeValue = $partition1 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part1sizeUnit = $partition1 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value
		##### Check if size of partition is in % and recalculate the size in MB
		if($part1sizeUnit.Value -eq "%")
		{
			
			$part1sizeUnit.Value = "Byte"
			$remainingsize = $disksize - $part0sizeInt - 1073741824
			$percentage = $part1sizeValue.Value / 100
			
			[UInt64]$part1sizeInt = $remainingsize * $percentage

		}
		elseif($part1sizeUnit.Value -eq "MB") {
			$part1sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part1sizeInt = $part1sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part1sizeInt = [UInt64]$part1sizeInt * 1MB
		}
		elseif($part1sizeUnit.Value -eq "GB") {
			$part1sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part1sizeInt = $part1sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part1sizeInt = [UInt64]$part1sizeInt * 1GB
		}
		
		$part1size = "$part1sizeInt"+$part1sizeUnit.Value
		
		$part1vlvValue = $partition1 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		$part1vlv = $part1vlvValue.Value
		
		
		
		#### 
		#### Get partitioning information for Partition 2 
		####		
		$partition2 = @()
		$partition2 += $partitions | Where-Object {$_.Name -like "OSDPartitions2*"}
		
		$part2typeValue = $partition2 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		$part2type = $part2typeValue.Value
		
		$part2fsValue = $partition2 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		$part2fs = $part2fsValue.Value
		
		$part2qfValue = $partition2 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		$part2qfable = $part2qfValue.Value
		
		$part2vnValue = $partition2 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		$part2vn = $part2vnValue.Value
		
		$part2sizeValue = $partition2 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part2sizeUnit = $partition2 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value		
		##### Check if size of partition is in % and recalculate the size in MB
		if($part2sizeUnit.Value -eq "%")
		{
			
			$part2sizeUnit.Value = "Byte"
			$remainingsize = $disksize - $part0sizeInt - $part1sizeInt - 1073741824
			$percentage = $part2sizeValue.Value / 100
			
			[UInt64]$part2sizeInt = $remainingsize * $percentage

		}
		elseif($part2sizeUnit.Value -eq "MB") {
			$part2sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part2sizeInt = $part2sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part2sizeInt = [UInt64]$part2sizeInt * 1MB
		}
		elseif($part2sizeUnit.Value -eq "GB") {
			$part2sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part2sizeInt = $part2sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part2sizeInt = [UInt64]$part2sizeInt * 1GB
		}
		
		$part2size = "$part2sizeInt"+$part2sizeUnit.Value
		
		
		$part2vlvValue = $partition2 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		$part2vlv = $part2vlvValue.Value
		
		
		#### 
		#### Get partitioning information for Partition 3 
		####		
		$partition3 = @()
		$partition3 += $partitions | Where-Object {$_.Name -like "OSDPartitions3*"}
		
		$part3typeValue = $partition3 | where-object {$_.Name -like "*Type"} | select-object -Property Value
		$part3type = $part3typeValue.Value
		
		$part3fsValue = $partition3 | where-object {$_.Name -like "*FileSystem"} | select-object -Property Value
		$part3fs = $part3fsValue.Value
		
		$part3qfValue = $partition3 | where-object {$_.Name -like "*QuickFormat"} | select-object -Property Value
		$part3qfable = $part3qfValue.Value
		
		$part3vnValue = $partition3 | where-object {$_.Name -like "*VolumeName"} | select-object -Property Value
		$part3vn = $part3vnValue.Value
		
		$part3sizeValue = $partition3 | where-object {$_.Name -like "*Size"} | select-object -Property Value
		$part3sizeUnit = $partition3 | where-object {$_.Name -like "*SizeUnits"} | select-object -Property Value
		##### Check if size of partition is in % and recalculate the size in MB
		if($part3sizeUnit.Value -eq "%")
		{
			
			$part3sizeUnit.Value = "Byte"
			$remainingsize = $disksize - $part0sizeInt - $part1sizeInt - $part2sizeInt - 1073741824
			$percentage = $part3sizeValue.Value / 100
			
			[UInt64]$part3sizeInt = $remainingsize * $percentage

		}
		elseif($part3sizeUnit.Value -eq "MB") {
			$part3sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part3sizeInt = $part3sizeValue.Value
			# Now we have to convert the "MB" to "Byte" for later use to create a new partition
			[UInt64]$part3sizeInt = [UInt64]$part3sizeInt * 1MB
		}
		elseif($part3sizeUnit.Value -eq "GB") {
			$part3sizeUnit.Value = "Byte"
			# Convert the Value into a UInt64 variable for partioioning
			[UInt64]$part3sizeInt = $part3sizeValue.Value
			# Now we have to convert the "GB" to "Byte" for later use to create a new partition
			[UInt64]$part3sizeInt = [UInt64]$part3sizeInt * 1GB
		}
		
		$part3size = "$part3sizeInt"+$part3sizeUnit.Value

		$part3vlvValue = $partition3 | where-object {$_.Name -like "*VolumeLetterVariable"} | select-object -Property Value
		$part3vlv = $part3vlvValue.Value
		
		
		# Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Sum of Partitioned Size: ${sumpartsize}Bytes; ${sumpartsizeKB}KB; ${sumpartsizeMB}MB; ${sumpartsizeGB}GB." # $part0sizeInt, $part1sizeInt, $part2sizeInt, $part3sizeInt"
	
	}
	elseif($numofpart -gt 4) {
		Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Disk [$tsenv:OSDDiskIndex] can not be partitioned. Your number of partitions < $numofpart > exceeds the maximum supported number of partitions. Please check if you have only EFI, MSR, Recovery, OS and one Data partition configured."
		Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Disk [$tsenv:OSDDiskIndex] can not be partitioned. Your number of partitions < $numofpart > exceeds the maximum supported number of partitions. Please check if you have only EFI, MSR, Recovery, OS and one Data partition configured." -Severity Error
		Exit 1
	}
	
	# Check if the disk size is enough for your partitioned size
	if($disksizeGB -lt $sumpartsizeGB) {
		Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Disk [$tsenv:OSDDiskIndex] can not be partitioned. Your disk size is lower then the size you want to deploy. Disksize: ${disksizeGB} - Needed Size: ${sumpartsizeGB}"
		Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Disk [$tsenv:OSDDiskIndex] can not be partitioned. Your disk size is lower then the size you want to deploy. Disksize: ${disksizeGB} - Needed Size: ${sumpartsizeGB}" -Severity Error
		Exit 1
	}
	elseif($disksizeGB -ge $sumpartsizeGB) {
		if($numofpart -eq 3) {

			
			### 
			### Create partitions 
			###
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partitions"
			Show-PSDActionProgress -Message "Create the paritions" -Step "5" -MaxStep "20"
			
			#### Partition0: Boot Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 0 - Type: $part0type - FileSystem: $part0fs - Bootable: $part0bootable - QuickFormat: $part0qf - VolumeName: $part0vn - Size and Unit: $part0size - VolumeVariable: $part0vlv"
			Show-PSDActionProgress -Message "Create the EFI partition" -Step "6" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 0 - Type: $part0type - FileSystem: $part0fs - VolumeName: $part0vn - Size: $part0size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 0 - Type: $part0type - FileSystem: $part0fs - VolumeName: $part0vn - Size: $part0size"
			try{
				#$boot = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size 500MB -AssignDriveLetter -IsActive
				$boot = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part0sizeInt -IsActive
			}
			catch {
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 0"
				Show-PSDInfo -Message "Partition 0: $_" -Severity Error
				Exit 1
			}
			
			#### Partition2: OS Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 2 - Type: $part2type - FileSystem: $part2fs - Bootable: $part2bootable - QuickFormat: $part2qf - VolumeName: $part2vn - Size and Unit: $part2size - VolumeVariable: $part2vlv"
			Show-PSDActionProgress -Message "Create the OS partition" -Step "8" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 2 - Type: $part2type - FileSystem: $part2fs - VolumeName: $part2vn - Size: $part2size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 2 - Type: $part2type - FileSystem: $part2fs - VolumeName: $part2vn - Size: $part2size"
			try{
				#$os = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $osSize -AssignDriveLetter
				$os = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part1sizeInt
			}
			catch {
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 2"
				Show-PSDInfo -Message "Partition 2: $_" -Severity Error
				Exit 1
			}
			
			#### Partition3: Recovery Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 3 - Type: $part3type - FileSystem: $part3fs - Bootable: $part3bootable - QuickFormat: $part3qf - VolumeName: $part3vn - Size and Unit: $part3size - VolumeVariable: $part3vlv"
			Show-PSDActionProgress -Message "Create the Recovery partition" -Step "9" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 3 - Type: $part3type - FileSystem: $part3fs - VolumeName: $part3vn - Size: $part3size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 3 - Type: $part3type - FileSystem: $part3fs - VolumeName: $part3vn - Size: $part3size"
			try{
				#$recovery = New-Partition -DiskNumber $tsenv:OSDDiskIndex -UseMaximumSize -AssignDriveLetter
				$recovery = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part2sizeInt
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 3"
				Show-PSDInfo -Message "Partition 3: $_" -Severity Error
				Exit 1
			}
			
			
			
			#### 
			#### Assign driveletters
			####
		
			#### Assign driveletter to Boot
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Assigning driveletter for $part0type"
			try{
				$boot | Set-Partition -NewDriveLetter "W"
			}
			catch {
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not assign drive letter for partition 0"
				Show-PSDInfo -Message "Partition Boot: $_" -Severity Error
				Exit 1
			}
			Show-PSDActionProgress -Message "Assigning driveletter for $part0type" -Step "10" -MaxStep "20"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $part0type is set to W:"
			
			##### Save the drive letters and volume GUIDs to task sequence variables
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs for Boot to task sequence variables"
			$tsenv:BootVolume = "W"
			$tsenv:BootVolumeGuid = $boot.Guid
			
			
			#### Assign driveletter to OS
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Assigning driveletter for $part2type"
			try{
				$os | Set-Partition -NewDriveLetter "S"
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not assign drive letter for partition 2"
				Show-PSDInfo -Message "Partition OS: $_" -Severity Error
				Exit 1			
			}
			Show-PSDActionProgress -Message "Assigning driveletter for $part2type" -Step "11" -MaxStep "20"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $type is set to S:"
			##### Save the drive letters and volume GUIDs to task sequence variables
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs for OS to task sequence variables"
			$tsenv:OSVolume = "S"
			$tsenv:OSVolumeGuid = $os.Guid
			
			
			#### Assign driveletter to Recovery
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Assigning driveletter for $part3type"
			try{
				$recovery | Set-Partition -NewDriveLetter "R"
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not assign drive letter for partition 3"
				Show-PSDInfo -Message "Partition Recovery: $_" -Severity Error
				Exit 1			
			}
			Show-PSDActionProgress -Message "Assigning driveletter for $part3type" -Step "12" -MaxStep "20"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $part3type is set to R:"		
			##### Save the drive letters and volume GUIDs to task sequence variables
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs for Recovery to task sequence variables"
			$tsenv:RecoveryVolume = "R"
			$tsenv:RecoveryVolumeGuid = $recovery.Guid
			
			
			#### 
			#### Format the volumes
			####
			
			### Format the boot volume
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format $part0type volume as $part0fs and label it as $part0vn"
			Show-PSDActionProgress -Message "Format $part0type volume as $part0fs and label it as $part0vn" -Step "13" -MaxStep "20"
			try{
				#Format-Volume -DriveLetter $tsenv:BootVolume -FileSystem NTFS -FileSystemLabel "Boot" -Verbose
				Format-Volume -DriveLetter $tsenv:BootVolume -FileSystem $part0fs -NewFileSystemLabel $part0vn
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not format boot volume"
				Show-PSDInfo -Message "Volume Boot: $_" -Severity Error
				Exit 1			
			}
			
			### Format the OS volume
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format $part2type volume as $part2fs and label it as $part2vn"
			Show-PSDActionProgress -Message "Format $part2type volume as $part2fs and label it as $part2vn" -Step "14" -MaxStep "20"
			try{
				#Format-Volume -DriveLetter $tsenv:OSVolume -FileSystem NTFS -FileSystemLabel "Windows" -Verbose
				Format-Volume -DriveLetter $tsenv:OSVolume -FileSystem $part2fs -NewFileSystemLabel $part2vn
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not format OS volume"
				Show-PSDInfo -Message "Volume OS: $_" -Severity Error
				Exit 1			
			}
			### Format the recovery volume
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format $part3type volume as $part3fs and label it as $part3vn"
			Show-PSDActionProgress -Message "Format $part3type volume as $part3fs and label it as $part3vn" -Step "15" -MaxStep "20"
			try{
				#Format-Volume -DriveLetter $tsenv:RecoveryVolume -FileSystem NTFS -FileSystemLabel "Recovery" -Verbose
				Format-Volume -DriveLetter $tsenv:RecoveryVolume -FileSystem $part3fs -NewFileSystemLabel $part3vn
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not format recovery volume"
				Show-PSDInfo -Message "Volume Recovery: $_" -Severity Error
				Exit 1			
			}
			

			#Fix for MBR
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Getting Guids from the volumes"

			$tsenv:OSVolumeGuid = (Get-Volume | Where-Object Driveletter -EQ $tsenv:OSVolume).UniqueId.replace("\\?\Volume","").replace("\","")
			$tsenv:RecoveryVolumeGuid = (Get-Volume | Where-Object Driveletter -EQ $tsenv:RecoveryVolume).UniqueId.replace("\\?\Volume","").replace("\","")
			$tsenv:BootVolumeGuid = (Get-Volume | Where-Object Driveletter -EQ $tsenv:BootVolume).UniqueId.replace("\\?\Volume","").replace("\","")

			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property OSVolumeGuid is $tsenv:OSVolumeGuid"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property RecoveryVolumeGuid is $tsenv:RecoveryVolumeGuid"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property BootVolumeGuid is $tsenv:BootVolumeGuid"
			
		}
		if($numofpart -eq 4) {
			
			
			### 
			### Create partitions 
			###
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partitions"
			Show-PSDActionProgress -Message "Create the paritions" -Step "5" -MaxStep "20"
			
			
			#### Partition0: Boot Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 0 - Type: $part0type - FileSystem: $part0fs - Bootable: $part0bootable - QuickFormat: $part0qf - VolumeName: $part0vn - Size and Unit: $part0size - VolumeVariable: $part0vlv"
			Show-PSDActionProgress -Message "Create the EFI partition" -Step "6" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 0 - Type: $part0type - FileSystem: $part0fs - VolumeName: $part0vn - Size: $part0size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 0 - Type: $part0type - FileSystem: $part0fs - VolumeName: $part0vn - Size: $part0size"
			try{
				#$boot = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size 500MB -AssignDriveLetter -IsActive
				$boot = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part0sizeInt -IsActive
			}
			catch {
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 0"
				Show-PSDInfo -Message "Partition 0: $_" -Severity Error
				Exit 1
			}
			
			#### Partition2: OS Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 2 - Type: $part2type - FileSystem: $part2fs - Bootable: $part2bootable - QuickFormat: $part2qf - VolumeName: $part2vn - Size and Unit: $part2size - VolumeVariable: $part2vlv"
			Show-PSDActionProgress -Message "Create the OS partition" -Step "8" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 2 - Type: $part2type - FileSystem: $part2fs - VolumeName: $part2vn - Size: $part2size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 2 - Type: $part2type - FileSystem: $part2fs - VolumeName: $part2vn - Size: $part2size"
			try{
				#$os = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $osSize -AssignDriveLetter
				$os = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part1sizeInt
			}
			catch {
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 2"
				Show-PSDInfo -Message "Partition 2: $_" -Severity Error
				Exit 1
			}
			
			#### Partition3: Recovery Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 3 - Type: $part3type - FileSystem: $part3fs - Bootable: $part3bootable - QuickFormat: $part3qf - VolumeName: $part3vn - Size and Unit: $part3size - VolumeVariable: $part3vlv"
			Show-PSDActionProgress -Message "Create the Recovery partition" -Step "9" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 3 - Type: $part3type - FileSystem: $part3fs - VolumeName: $part3vn - Size: $part3size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 3 - Type: $part3type - FileSystem: $part3fs - VolumeName: $part3vn - Size: $part3size"
			try{
				#$recovery = New-Partition -DiskNumber $tsenv:OSDDiskIndex -UseMaximumSize -AssignDriveLetter
				$recovery = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part2sizeInt
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 3"
				Show-PSDInfo -Message "Partition 3: $_" -Severity Error
				Exit 1
			}
			
			
			
			#### Partition4: Data Partition
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Create the partition 4 - Type: $part4type - FileSystem: $part4fs - Bootable: $part4bootable - QuickFormat: $part4qf - VolumeName: $part4vn - Size and Unit: $part4size - VolumeVariable: $part4vlv"
			Show-PSDActionProgress -Message "Create the Data partition" -Step "10" -MaxStep "20"
			#Show-PSDActionProgress -Message "Create partition 4 - Type: $part4type - FileSystem: $part4fs - VolumeName: $part4vn - Size: $part4size" -Step "1" -MaxStep "1"
			#Show-PSDInfo -Message "Create partition 4 - Type: $part4type - FileSystem: $part4fs - VolumeName: $part4vn - Size: $part4size"
			try{
				$data = New-Partition -DiskNumber $tsenv:OSDDiskIndex -UseMaximumSize
				#$data = New-Partition -DiskNumber $tsenv:OSDDiskIndex -Size $part4sizeInt
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not create partition 4"
				Show-PSDInfo -Message "Partition 4: $_" -Severity Error
				Exit 1
			}
			
			
			
			#### 
			#### Assign driveletters
			####
		
			#### Assign driveletter to Boot
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Assigning driveletter for $part0type"
			try{
				$boot | Set-Partition -NewDriveLetter "W"
			}
			catch {
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not assign drive letter for partition 0"
				Show-PSDInfo -Message "Partition Boot: $_" -Severity Error
				Exit 1
			}
			Show-PSDActionProgress -Message "Assigning driveletter for $part0type" -Step "10" -MaxStep "20"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $part0type is set to W:"
			
			##### Save the drive letters and volume GUIDs to task sequence variables
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs for Boot to task sequence variables"
			$tsenv:BootVolume = "W"
			$tsenv:BootVolumeGuid = $boot.Guid
			
			
			#### Assign driveletter to OS
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Assigning driveletter for $part2type"
			try{
				$os | Set-Partition -NewDriveLetter "S"
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not assign drive letter for partition 2"
				Show-PSDInfo -Message "Partition OS: $_" -Severity Error
				Exit 1			
			}
			Show-PSDActionProgress -Message "Assigning driveletter for $part2type" -Step "11" -MaxStep "20"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $type is set to S:"
			##### Save the drive letters and volume GUIDs to task sequence variables
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs for OS to task sequence variables"
			$tsenv:OSVolume = "S"
			$tsenv:OSVolumeGuid = $os.Guid
			
			
			#### Assign driveletter to Recovery
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Assigning driveletter for $part3type"
			try{
				$recovery | Set-Partition -NewDriveLetter "R"
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not assign drive letter for partition 3"
				Show-PSDInfo -Message "Partition Recovery: $_" -Severity Error
				Exit 1			
			}
			Show-PSDActionProgress -Message "Assigning driveletter for $part3type" -Step "12" -MaxStep "20"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $part3type is set to R:"		
			##### Save the drive letters and volume GUIDs to task sequence variables
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs for Recovery to task sequence variables"
			$tsenv:RecoveryVolume = "R"
			$tsenv:RecoveryVolumeGuid = $recovery.Guid
			
			
			#### Assign driveletter to Data
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Assigning driveletter for $part4type"
			try{
				$data | Set-Partition -NewDriveLetter "D"
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not assign drive letter for partition 4"
				Show-PSDInfo -Message "Partition Data: $_" -Severity Error
				Exit 1			
			}
			Show-PSDActionProgress -Message "Assigning driveletter for $part4type" -Step "14" -MaxStep "20"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): $part4type is set to D:"		
			##### Save the drive letters and volume GUIDs to task sequence variables
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save the drive letters and volume GUIDs for Data to task sequence variables"
			$tsenv:DataVolume = "D"
			$tsenv:DataVolumeGuid = $data.Guid
			
			
			
			
			#### 
			#### Format the volumes
			####
			
			### Format the boot volume
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format $part0type volume as $part0fs and label it as $part0vn"
			Show-PSDActionProgress -Message "Format $part0type volume as $part0fs and label it as $part0vn" -Step "13" -MaxStep "20"
			try{
				#Format-Volume -DriveLetter $tsenv:BootVolume -FileSystem NTFS -FileSystemLabel "Boot" -Verbose
				Format-Volume -DriveLetter $tsenv:BootVolume -FileSystem $part0fs -NewFileSystemLabel $part0vn
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not format boot volume"
				Show-PSDInfo -Message "Volume Boot: $_" -Severity Error
				Exit 1			
			}
			
			### Format the OS volume
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format $part2type volume as $part2fs and label it as $part2vn"
			Show-PSDActionProgress -Message "Format $part2type volume as $part2fs and label it as $part2vn" -Step "14" -MaxStep "20"
			try{
				#Format-Volume -DriveLetter $tsenv:OSVolume -FileSystem NTFS -FileSystemLabel "Windows" -Verbose
				Format-Volume -DriveLetter $tsenv:OSVolume -FileSystem $part2fs -NewFileSystemLabel $part2vn
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not format OS volume"
				Show-PSDInfo -Message "Volume OS: $_" -Severity Error
				Exit 1			
			}
			### Format the recovery volume
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format $part3type volume as $part3fs and label it as $part3vn"
			Show-PSDActionProgress -Message "Format $part3type volume as $part3fs and label it as $part3vn" -Step "15" -MaxStep "20"
			try{
				#Format-Volume -DriveLetter $tsenv:RecoveryVolume -FileSystem NTFS -FileSystemLabel "Recovery" -Verbose
				Format-Volume -DriveLetter $tsenv:RecoveryVolume -FileSystem $part3fs -NewFileSystemLabel $part3vn
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not format recovery volume"
				Show-PSDInfo -Message "Volume Recovery: $_" -Severity Error
				Exit 1			
			}
			
			### Format the data volume
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Format $part4type volume as $part4fs and label it as $part4vn"
			Show-PSDActionProgress -Message "Format $part4type volume as $part4fs and label it as $part4vn" -Step "18" -MaxStep "20"
			try{
				#Format-Volume -DriveLetter $tsenv:DataVolume -FileSystem NTFS -NewFileSystemLabel Data
				Format-Volume -DriveLetter $tsenv:DataVolume -FileSystem $part4fs -NewFileSystemLabel $part4vn
			}
			catch{
				Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Unable to continue, could not format data volume"
				Show-PSDInfo -Message "Volume Data: $_" -Severity Error
				Exit 1			
			}
			

			#Fix for MBR
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Getting Guids from the volumes"

			$tsenv:OSVolumeGuid = (Get-Volume | Where-Object Driveletter -EQ $tsenv:OSVolume).UniqueId.replace("\\?\Volume","").replace("\","")
			$tsenv:RecoveryVolumeGuid = (Get-Volume | Where-Object Driveletter -EQ $tsenv:RecoveryVolume).UniqueId.replace("\\?\Volume","").replace("\","")
			$tsenv:BootVolumeGuid = (Get-Volume | Where-Object Driveletter -EQ $tsenv:BootVolume).UniqueId.replace("\\?\Volume","").replace("\","")
			$tsenv:DataVolumeGuid = (Get-Volume | Where-Object Driveletter -EQ $tsenv:DataVolume).UniqueId.replace("\\?\Volume","").replace("\","")

			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property OSVolumeGuid is $tsenv:OSVolumeGuid"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property RecoveryVolumeGuid is $tsenv:RecoveryVolumeGuid"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property BootVolumeGuid is $tsenv:BootVolumeGuid"
			Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Property DataVolumeGuid is $tsenv:DataVolumeGuid"
			
		}
	}
	
}
# If Sytsem is not UEFI and not BIOS
else {
	Write-PSDLog -Message "ERROR - $($MyInvocation.MyCommand.Name): Your Sytsem is not UEFI neither BIOS. Depyloment can not proceed!"
	Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Your Sytsem is not UEFI neither BIOS. Depyloment can not proceed!" -Severity Error
	Exit 1
}


# Make sure there is a PSDrive for the OS volume
if ((Test-Path "$($tsenv:OSVolume):\") -eq $false){
	# Show-PSDActionProgress -Message "Create new PSDrive for $tsenv:OSVolume"
    New-PSDrive -Name $tsenv:OSVolume -PSProvider FileSystem -Root "$($tsenv:OSVolume):\" -Verbose
}

# If the old local data path survived the partitioning, copy it to the new location
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): If the old local data path survived the partitioning, copy it to the new location"
if (Test-Path $currentLocalDataPath){
    # Copy files to new data path
    Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copy files to new data path"
    $newLocalDataPath = Get-PSDLocalDataPath -Move
    if ($currentLocalDataPath -ine $newLocalDataPath){
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Copying $currentLocalDataPath to $newLocalDataPath"
		# Show-PSDActionProgress -Message "$($MyInvocation.MyCommand.Name): Copying $currentLocalDataPath to $newLocalDataPath"
        Copy-PSDFolder $currentLocalDataPath $newLocalDataPath
        
        # Change log location for LogPath, since we now have a volume
        $Global:LogPath = "$newLocalDataPath\SMSOSD\OSDLOGS\PSDPartition.log"
        Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Now logging to $Global:LogPath"
		# Show-PSDActionProgress -Message "$($MyInvocation.MyCommand.Name): Now logging to $Global:LogPath"
    }
}

# Dumping out variables for troubleshooting
<#
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Dumping out variables for troubleshooting"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:BootVolume  is $tsenv:BootVolume"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:OSVolume is $tsenv:OSVolume"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:DataVolume is $tsenv:DataVolume"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:RecoveryVolume is $tsenv:RecoveryVolume"
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): tsenv:IsUEFI is $tsenv:IsUEFI"

Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Dumping out variables for troubleshooting"
Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): tsenv:BootVolume  is $tsenv:BootVolume"
Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): tsenv:OSVolume is $tsenv:OSVolume"
Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): tsenv:DataVolume is $tsenv:DataVolume"
Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): tsenv:RecoveryVolume is $tsenv:RecoveryVolume"
Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): tsenv:IsUEFI is $tsenv:IsUEFI"
#>
#Show-PSDInfo -Message "$($MyInvocation.MyCommand.Name): Partitioning complete"

# Save all the current variables for later use
Write-PSDLog -Message "$($MyInvocation.MyCommand.Name): Save all the current variables for later use"
Save-PSDVariables
