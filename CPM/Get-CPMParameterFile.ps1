Function Get-CPMParameterFile {
	<#
	.SYNOPSIS
	Copies a specific CPM Parameter file from the CPM tmp directory to a specified output folder.

	.DESCRIPTION
	Designed to be run locally on a CyberArk CPM Server.
	When executed, watches the Password Manager tmp directory for a parameter file related to a CPM operation on
	a specified account to be created.
	Once found, the parameter file is copied to an output location for further review, or use in CPM plugin debugging
	or development.

	.PARAMETER accountName
	The name of the account in the vault (not the username).
	This is required to be the value from the "Name" property on the Account Details page in PVWA.

	.PARAMETER path
	The path to the CPM tmp Directory.
	Usually <Drive>:\Program Files (x86)\CyberArk\Password Manager\tmp
	If not specified, path will be built using data from the registry.

	.PARAMETER outputPath
	A folder to copy the CPM Parameter file to.
	Defaults to the logged on user's MyDocuments folder

	.PARAMETER restartCPMService
	Optionally restart the Password Manager Windows Service on the local computer.

	.EXAMPLE
	Get-CPMParameterFile -accountName "Operating System-Windows-machine-DomainAdminUser" -Verbose

	Once generated, copies Parameter File relating to account "Operating System-Windows-machine-DomainAdminUser" to the
	logged on user's MyDocuments folder. Verbose log messages are displayed.

	.EXAMPLE
	Get-CPMParameterFile -accountName "Operating System-unixssh-machine-RootUser23" -outputPath D:\Temp

	Once generated, copies Parameter File relating to account "Operating System-unixssh-machine-RootUser23" to the
	D:\Temp folder.

	.EXAMPLE
	Get-CPMParameterFile -accountName Application-Cyberark-10.10.10.10-CyberUser -restartCPMService -Verbose

	First, restarts the local Password Manager Service, then, once generated, copies Parameter File relating to account
	"Operating System-Windows-machine-DomainAdminUser" to the logged on user's MyDocuments folder.
	Verbose log messages are displayed.

	.NOTES
	Only intended for execution on a CPM Server.
	#>
	[CmdletBinding()]
	param(
		#The name of the account in PVWA
		[parameter(
			Mandatory = $true
		)]
		[string]$accountName,

		#<Drive>:\Program Files (x86)\CyberArk\Password Manager\tmp
		#CPM tmp Directory
		[parameter(
			Mandatory = $false
		)]
		[ValidateScript( {Test-Path $_})]
		[string]$path,

		#Path to copy the file to
		[parameter(
			Mandatory = $false
		)]
		[ValidateScript( {Test-Path $_})]
		[string]$outputPath = [Environment]::GetFolderPath("MyDocuments"),

		#Whether to restart the CPM Service
		[parameter(
			Mandatory = $false
		)]
		[ValidateScript( {Get-Service -Name "CyberArk Password Manager"})]
		[switch]$restartCPMService
	)

	Begin {

		Function Get-CPMTempDirectory {

			Try {

				(Join-Path (Get-ItemProperty -EA SilentlyContinue -Path Registry::$(
				(Get-ChildItem "HKLM:\SOFTWARE\Wow6432Node\CyberArk\CyberArk Password Manager" -EA SilentlyContinue |
				Where-Object {$_.Property -eq "HomeDirectory"} | Sort-Object Name -Descending) |
					Select-Object -First 1 -ExpandProperty Name) |
							Select-Object -ExpandProperty HomeDirectory) "tmp")
			}

			Catch {

				throw "Path to the local \CyberArk\Password Manager\tmp directory not found. Ensure execution is on a CPM server, or specify the correct path."

			}

		}

	}

	Process {

		If(-not($path)) {

			$path = Get-CPMTempDirectory

		}

		Write-Verbose "CPM Directory: $path"

		if($restartCPMService) {

			Try {

				#Find the CPM Service
				Get-Service -Name "CyberArk Password Manager" |
					Restart-Service -Force -ErrorAction Stop -Verbose

			}

			Catch {

				Write-Error $_

			}

			Finally {

				Write-Verbose "CyberArk Password Manager Status: $(
					(Get-Service "CyberArk Password Manager").Status)" -Verbose

			}

		}

		#Start a timer for progress indication
		$elapsedTime = [system.diagnostics.stopwatch]::StartNew()

		do {

			#Search CPM tmp directory for Parameter file
			$file = Get-ChildItem -Path $path -File -Filter "*$accountName*"

			Write-Progress -activity "Watching '$path' for '$accountName' Parameter File" -status "$(
		        [string]::Format("Time Elapsed: {0:d2}:{1:d2}", $elapsedTime.Elapsed.minutes, $elapsedTime.Elapsed.seconds))"

			#stop when found
		} until ($file.count -eq 1)

		Write-Verbose "File Found: $($file.Name) (
            $([string]::Format("Time Elapsed: {0:d2}:{1:d2}", $elapsedTime.Elapsed.minutes, $elapsedTime.Elapsed.seconds)))"

		#Copy CPM Parameter file to output directory, output full path
		$file.CopyTo((Join-Path $outputPath $file.Name)) | Select-Object -ExpandProperty FullName

		#Stop the timer
		$elapsedTime.stop()

		Write-Verbose "File Copied To: $outputPath"

	}

}