<#
The MIT License (MIT)
Copyright (c) Microsoft Corporation  
Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.  
THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
.SYNOPSIS
This script updates the lab vm count.
.PARAMETER MaxVMCount
Max VM count.
.EXAMPLE
. ".\Set-AzLabCapacity.ps1" `
    -MaxVMCount 5
#>

[CmdletBinding()]
param(
    [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Lab VM Capacity")]
    [ValidateNotNullOrEmpty()]
    [int] $MaxVMCount


)

###################################################################################################
try {

    $ErrorActionPreference = "Stop"

    #. ".\Utils.ps1"
    #Import-Module ".\modules\Utils.psm1"
    
    #Write-Output "Importing AzLab Module"
    #Import-AzLabModule

    $global:AzLabServicesModuleName = "Az.LabServices.psm1"
    $global:AzLabServicesModuleSource = "https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Modules/Library/"
    #$global:AzLabServicesModulePath = Join-Path -Path $AzLabServicesModuleSource -ChildPath $AzLabServicesModuleName

    Import-RemoteModule -Source $AzLabServicesModuleSource -ModuleName $AzLabServicesModuleName

    $global:AzLabServicesUtilName = "Utils.psm1"
    $global:AzLabServicesUtilSource = "https://raw.githubusercontent.com/RogerBestMsft/azure-devtestlab-activedirectoryjoin/devModules/src/modules/"

    Import-RemoteModule -Source $global:AzLabServicesUtilSource -ModuleName $global:AzLabServicesUtilName


    $templateVm = Get-AzLabCurrentTemplateVm

    Write-Output "Getting information on the currently running Template VM"

    $lab = $templateVm | Get-AzLabForVm

    Set-AzLab $lab -MaxUsers $MaxVMCount

    $ExitCode = 0
}

catch
{
    $message = $Error[0].Exception.Message
    if ($message) {
        Write-Error "`nERROR: $message"
    }

    Write-Error "`nThe script failed to run.`n"

    # Important note: Throwing a terminating error (using $ErrorActionPreference = "stop") still returns exit 
    # code zero from the powershell script. The workaround is to use try/catch blocks and return a non-zero 
    # exit code from the catch block. 
    $ExitCode = -1
}

finally {

    Write-Output "Exiting with $ExitCode" 
    exit $ExitCode
}

function Import-RemoteModule {
    param(
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Web source of the psm1 file")]
        [ValidateNotNullOrEmpty()]
        [string] $Source,
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of the module")]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleName,
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to update and replace an existing psm1 file")]
        [switch]
        $Update = $false
    )
  
    $modulePath = Join-Path -Path (Resolve-Path ./) -ChildPath $ModuleName
  
    if ($Update -Or !(Test-Path -Path $modulePath)) {

        Download-Scripts -Source $Source -ModuleName $ModuleName -ModulePath $modulePath
        #Remove-Item -Path $modulePath -ErrorAction SilentlyContinue

        #$WebClient = New-Object System.Net.WebClient
        #WebClient.DownloadFile($Source, $modulePath)
    }
    
    Import-Module $modulePath
}

function Download-Scripts {
    param(
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Web source of the psm1 file")]
        [ValidateNotNullOrEmpty()]
        [string] $Source,
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of the module")]
        [ValidateNotNullOrEmpty()]
        [string] $ModuleName,
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of the module")]
        [ValidateNotNullOrEmpty()]
        [string] $ModulePath
    )

    Remove-Item -Path $ModulePath -ErrorAction SilentlyContinue

    $WebClient = New-Object System.Net.WebClient
    $WebClient.DownloadFile($Source, $ModulePath)
}