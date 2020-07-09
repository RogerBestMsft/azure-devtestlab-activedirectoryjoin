<#
The MIT License (MIT)
Copyright (c) Microsoft Corporation  
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.  
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
.SYNOPSIS
This script prepares a managed Lab for an Active Directory domain join. It schedules a chain of scripts to run at next startup, then publishes the Lab. The AD Domain Services Server must be reacheable from the peered VNet.
.LINK https://docs.microsoft.com/en-us/azure/lab-services/classroom-labs/how-to-connect-peer-virtual-network
.PARAMETER DomainServiceAddress
One or more AD Domain Services Server addresses.
.PARAMETER Domain
Domain Name (e.g. contoso.com).
.PARAMETER LocalUser
Local User created when setting up the Lab.
.PARAMETER DomainUser
Domain User (e.g. CONTOSO\frbona or frbona@contoso.com). It must have permissions to add computers to the domain.
.PARAMETER LocalPassword
Password of the Local User.
.PARAMETER DomainPassword
Password of the Domain User.
.PARAMETER OUPath
Organization Unit path (optional)
.PARAMETER EnrollMDM
Whether to enroll the VMs to Intune (for Hybrid AD only).
.NOTES
.EXAMPLE
. ".\Join-AzLabADTemplate.ps1" `
    -DomainServiceAddress '10.0.23.5','10.0.23.6' `
    -Domain 'contoso.com' `
    -LocalUser 'localUser' `
    -DomainUser 'domainUser' `
    -LocalPassword 'localPassword' `
    -DomainPassword 'domainPassword `
    -OUPath 'OU=OrgUnit,DC=domain,DC=Domain,DC=com'
    -EnrollMDM
#>

[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "One or more AD Domain Services Server addresses.")]
    [ValidateNotNullOrEmpty()]
    [string[]] $DomainServiceAddress,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Domain Name (e.g. contoso.com).")]
    [ValidateNotNullOrEmpty()]
    [string] $Domain,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Local User created when setting up the Lab.")]
    [ValidateNotNullOrEmpty()]
    [string] $LocalUser,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Domain User (e.g. CONTOSO\frbona or frbona@contoso.com). It must have permissions to add computers to the domain.")]
    [ValidateNotNullOrEmpty()]
    [string] $DomainUser,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Password of the Local User.")]
    [ValidateNotNullOrEmpty()]
    [string] $LocalPassword,

    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Password of the Domain User.")]
    [ValidateNotNullOrEmpty()]
    [string] $DomainPassword,
    
    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Specific Organization Path.")]
    [string]
    $OUPath = "no-op",

    [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to enroll the VMs to Intune (for Hybrid AD only)")]
    [switch]
    $EnrollMDM = $false
)

###################################################################################################

# Default exit code
$ExitCode = 0

try {
    
    $ErrorActionPreference = "Stop"
   
    $global:AzLabServicesModuleName = "Az.LabServices.psm1"
    $global:AzLabServicesModuleSource = "https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Modules/Library/"

    $global:AzLabServicesUtilManagementName = "Management.psm1"
    $global:AzLabServicesUtilName = "Utils.psm1"
    $global:AzLabServicesUtilSource = "https://raw.githubusercontent.com/RogerBestMsft/azure-devtestlab-activedirectoryjoin/devModules/src/modules/"

    # Load Management module
    $source = $AzLabServicesUtilSource + $AzLabServicesUtilManagementName
    $target = Join-Path -Path (Resolve-Path ./) -ChildPath $AzLabServicesUtilManagementName
    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile($source, $target)
    Import-Module $target -Global

    # Load Utils and Az.LabServices modules
    Import-RemoteModule -Source $AzLabServicesModuleSource -ModuleName $AzLabServicesModuleName
    Import-RemoteModule -Source $AzLabServicesUtilSource -ModuleName $AzLabServicesUtilName

    # TODO Download secondary scripts
    $global:AzLabServicesScriptsSource = "https://raw.githubusercontent.com/RogerBestMsft/azure-devtestlab-activedirectoryjoin/devModules/src/scripts/"
    $global:JoinAzLabADStudentRenameVmScriptName = "Join-AzLabADStudent_RenameVm.ps1"
    $global:JoinAzLabADStudentJoinVmScriptName = "Join-AzLabADStudent_JoinVm.ps1"
    $global:JoinAzLabADStudentAddStudentScriptName = "Join-AzLabADStudent_AddStudent.ps1"
    $global:JoinAzLabADStudentEnrollMDMScriptName = "Join-AzLabADStudent_EnrollMDM.ps1"

    #$modulePath = Join-Path -Path (Resolve-Path ./) -ChildPath $ModuleName
    Download-Scripts -Source $AzLabServicesScriptsSource + $JoinAzLabADStudentRenameVmScriptName -ModulePath (Join-Path -Path (Resolve-Path ./) -ChildPath $JoinAzLabADStudentRenameVmScriptName)
    Download-Scripts -Source $AzLabServicesScriptsSource + $JoinAzLabADStudentJoinVmScriptName -ModulePath (Join-Path -Path (Resolve-Path ./) -ChildPath $JoinAzLabADStudentJoinVmScriptName)
    Download-Scripts -Source $AzLabServicesScriptsSource + $JoinAzLabADStudentAddStudentScriptName -ModulePath (Join-Path -Path (Resolve-Path ./) -ChildPath $JoinAzLabADStudentAddStudentScriptName)
    Download-Scripts -Source $AzLabServicesScriptsSource + $JoinAzLabADStudentEnrollMDMScriptName -ModulePath (Join-Path -Path (Resolve-Path ./) -ChildPath $JoinAzLabADStudentEnrollMDMScriptName)
#

    Write-Output "Getting information on the currently running Template VM"
    $templateVm = Get-AzLabCurrentTemplateVm
    
    $lab = $templateVm | Get-AzLabForVm
    
    Write-Output "Details of the Lab for the template VM $env:COMPUTERNAME"
    Write-Output "Name of the Lab: $($lab.Name)"
    Write-Output "Name of the Lab Account: $($lab.LabAccountName)"
    Write-Output "Resource group of the Lab Account: $($lab.ResourceGroupName)"
    
    # Register Rename VM script to run at next startup
    Write-LogFile "Registering the '$JoinAzLabADStudentRenameVmScriptName' script to run at next startup"
    Register-AzLabADStudentTask `
        -LabAccountResourceGroupName $lab.ResourceGroupName `
        -LabAccountName $lab.LabAccountName `
        -LabName $lab.Name `
        -DomainServiceAddress $DomainServiceAddress `
        -Domain $Domain `
        -LocalUser $LocalUser `
        -DomainUser $DomainUser `
        -LocalPassword $LocalPassword `
        -DomainPassword $DomainPassword `
        -OUPath $OUPath `
        -ScriptName $JoinAzLabADStudentRenameVmScriptName `
        -EnrollMDM:$EnrollMDM

    Write-Output "Publishing the Lab"
    Write-Warning "Warning: Publishing the Lab may take up to 1 hour"
    $lab | Publish-AzLab
    
    # Behavior of the Template VM from here on out:
    # 1) After 10 minutes, VM is shutdown
    # 2) After 20 minutes, VM is spinned up again. I suspect this happens when the image snapshot has been captured.
    # 3) Template VM is shutdown once again. For some reasons I cannot log this event. A forced shutdown?
}
catch
{
    $message = $Error[0].Exception.Message
    if ($message) {        
        Write-Warning "`nERROR: $message"
    }

    Write-Output "`nThe script failed to run.`n"

    # Important note: Throwing a terminating error (using $ErrorActionPreference = "stop") still returns exit 
    # code zero from the powershell script. The workaround is to use try/catch blocks and return a non-zero 
    # exit code from the catch block. 
    $ExitCode = -1
}

finally {
    Write-Warning "`n The script failed to deploy the template VM, check your input and re-run the script. `n"
    Write-Output "Exiting with $ExitCode" 
    exit $ExitCode
}

# function Import-RemoteModule {
#     param(
#         [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Web source of the psm1 file")]
#         [ValidateNotNullOrEmpty()]
#         [string] $Source,
#         [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of the module")]
#         [ValidateNotNullOrEmpty()]
#         [string] $ModuleName,
#         [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to update and replace an existing psm1 file")]
#         [switch]
#         $Update = $false
#     )
  
#     $modulePath = Join-Path -Path (Resolve-Path ./) -ChildPath $ModuleName
  
#     if ($Update -Or !(Test-Path -Path $modulePath)) {

#         Download-Scripts -Source $Source -ModuleName $ModuleName -ModulePath $modulePath
#         #Remove-Item -Path $modulePath -ErrorAction SilentlyContinue

#         #$WebClient = New-Object System.Net.WebClient
#         #WebClient.DownloadFile($Source, $modulePath)
#     }
    
#     Import-Module $modulePath
# }

# function Download-Scripts {
#     param(
#         [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Web source of the psm1 file")]
#         [ValidateNotNullOrEmpty()]
#         [string] $Source,
#         [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of the module")]
#         [ValidateNotNullOrEmpty()]
#         [string] $ModuleName,
#         [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of the module")]
#         [ValidateNotNullOrEmpty()]
#         [string] $ModulePath
#     )

#     Remove-Item -Path $ModulePath -ErrorAction SilentlyContinue

#     $WebClient = New-Object System.Net.WebClient
#     $WebClient.DownloadFile($Source, $ModulePath)
# }