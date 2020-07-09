# We are using strict mode for added safety
Set-StrictMode -Version Latest

# We require a relatively new version of Powershell
#requires -Version 3.0

# AzLab Module dependency
$AzLabServicesModuleName = "Az.LabServices.psm1"
$AzLabServicesModuleSource = "https://raw.githubusercontent.com/Azure/azure-devtestlab/master/samples/ClassroomLabs/Modules/Library/Az.LabServices.psm1"
$global:AzLabServicesModulePath = Join-Path -Path (Resolve-Path ./) -ChildPath $AzLabServicesModuleName

# TODO Download secondary scripts
$global:AzLabServicesScriptsSource = "https://raw.githubusercontent.com/RogerBestMsft/azure-devtestlab-activedirectoryjoin/devModules/src/scripts/"
$global:JoinAzLabADStudentRenameVmScriptName = "Join-AzLabADStudent_RenameVm.ps1"
$global:JoinAzLabADStudentJoinVmScriptName = "Join-AzLabADStudent_JoinVm.ps1"
$global:JoinAzLabADStudentAddStudentScriptName = "Join-AzLabADStudent_AddStudent.ps1"
$global:JoinAzLabADStudentEnrollMDMScriptName = "Join-AzLabADStudent_EnrollMDM.ps1"

# The reason for using the following function and managing errors as done in the cmdlets below is described
# at the link here: https://github.com/PoshCode/PowerShellPracticeAndStyle/issues/37#issuecomment-347257738
# The scheme permits writing the cmdlet code assuming the code after an error is not executed,
# and at the same time allows the caller to decide if the cmdlet *overall* should stop or continue for errors
# by using the standard ErrorAction syntax. It also mentions the correct cmdlet name in the text for the error
# without exposing the innards of the function. The price to pay is boilerplate code, reduced by BeginPreamble.
# You might think you might reduce boilerplate even more by creating a function that takes
# a scriptBlock and wrap it in the correct begin{} process {try{} catch{}} end {}
# but that ends up showing the source line of the error as such function, not the cmdlet.

# Import (with . syntax) this at the start of each begin block
function BeginPreamble {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseDeclaredVarsMoreThanAssignments", "", Scope = "Function")]
    param()
    Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
    $callerEA = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
}

# TODO: consider reducing function below to just get ErrorActionPreference
# Taken from https://gallery.technet.microsoft.com/scriptcenter/Inherit-Preference-82343b9d
function Get-CallerPreference {
    [CmdletBinding(DefaultParameterSetName = 'AllVariables')]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateScript( { $_.GetType().FullName -eq 'System.Management.Automation.PSScriptCmdlet' })]
        $Cmdlet,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.SessionState]
        $SessionState,

        [Parameter(ParameterSetName = 'Filtered', ValueFromPipeline = $true)]
        [string[]]
        $Name
    )

    begin {
        $filterHash = @{ }
    }

    process {
        if ($null -ne $Name) {
            foreach ($string in $Name) {
                $filterHash[$string] = $true
            }
        }
    }

    end {
        # List of preference variables taken from the about_Preference_Variables help file in PowerShell version 4.0

        $vars = @{
            'ErrorView'                     = $null
            'FormatEnumerationLimit'        = $null
            'LogCommandHealthEvent'         = $null
            'LogCommandLifecycleEvent'      = $null
            'LogEngineHealthEvent'          = $null
            'LogEngineLifecycleEvent'       = $null
            'LogProviderHealthEvent'        = $null
            'LogProviderLifecycleEvent'     = $null
            'MaximumAliasCount'             = $null
            'MaximumDriveCount'             = $null
            'MaximumErrorCount'             = $null
            'MaximumFunctionCount'          = $null
            'MaximumHistoryCount'           = $null
            'MaximumVariableCount'          = $null
            'OFS'                           = $null
            'OutputEncoding'                = $null
            'ProgressPreference'            = $null
            'PSDefaultParameterValues'      = $null
            'PSEmailServer'                 = $null
            'PSModuleAutoLoadingPreference' = $null
            'PSSessionApplicationName'      = $null
            'PSSessionConfigurationName'    = $null
            'PSSessionOption'               = $null

            'ErrorActionPreference'         = 'ErrorAction'
            'DebugPreference'               = 'Debug'
            'ConfirmPreference'             = 'Confirm'
            'WhatIfPreference'              = 'WhatIf'
            'VerbosePreference'             = 'Verbose'
            'WarningPreference'             = 'WarningAction'
        }


        foreach ($entry in $vars.GetEnumerator()) {
            if (([string]::IsNullOrEmpty($entry.Value) -or -not $Cmdlet.MyInvocation.BoundParameters.ContainsKey($entry.Value)) -and
                ($PSCmdlet.ParameterSetName -eq 'AllVariables' -or $filterHash.ContainsKey($entry.Name))) {
                $variable = $Cmdlet.SessionState.PSVariable.Get($entry.Key)

                if ($null -ne $variable) {
                    if ($SessionState -eq $ExecutionContext.SessionState) {
                        Set-Variable -Scope 1 -Name $variable.Name -Value $variable.Value -Force -Confirm:$false -WhatIf:$false
                    }
                    else {
                        $SessionState.PSVariable.Set($variable.Name, $variable.Value)
                    }
                }
            }
        }

        if ($PSCmdlet.ParameterSetName -eq 'Filtered') {
            foreach ($varName in $filterHash.Keys) {
                if (-not $vars.ContainsKey($varName)) {
                    $variable = $Cmdlet.SessionState.PSVariable.Get($varName)

                    if ($null -ne $variable) {
                        if ($SessionState -eq $ExecutionContext.SessionState) {
                            Set-Variable -Scope 1 -Name $variable.Name -Value $variable.Value -Force -Confirm:$false -WhatIf:$false
                        }
                        else {
                            $SessionState.PSVariable.Set($variable.Name, $variable.Value)
                        }
                    }
                }
            }
        }

    } # end

} # function Get-CallerPreference

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

        Remove-Item -Path $modulePath -ErrorAction SilentlyContinue

        $WebClient = New-Object System.Net.WebClient
        $WebClient.DownloadFile($Source, $modulePath)
    }
    
    Import-Module $modulePath
}
  
function Import-AzLabModule {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to update an existing Az.LabServices module")]
        [switch]
        $Update = $false
    )

    begin { . BeginPreamble }
    process {
        try {
            Import-RemoteModule -Source $AzLabServicesModuleSource -ModuleName $AzLabServicesModuleName -Update:$Update
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
    end{}
}

function Write-LogFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Message
    )

    begin { . BeginPreamble }
    process {
        try {
            # Get the current date
            $LogDate = (Get-Date).tostring("yyyyMMdd")

            $CurrentDir = (Resolve-Path .\).Path
            $ScriptName = @(Get-PSCallStack)[1].InvocationInfo.MyCommand.Name

            # Frame Log File with Current Directory and date
            $LogFile = $CurrentDir + "\" + "$ScriptName`_$LogDate" + ".txt"

            # Add Content to the Log File
            $TimeStamp = (Get-Date).toString("dd/MM/yyyy HH:mm:ss:fff tt")
            $Line = "$TimeStamp - $Message"

            Add-content -Path $Logfile -Value $Line -ErrorAction SilentlyContinue

<<<<<<< HEAD
            #Write-Output "Message: '$Message' has been logged to file: $LogFile"
=======
            Write-Output "Message: '$Message' has been logged to file: $LogFile"
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c
        }
        catch {

        }
    }
    end{}
}

function Write-DebugFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Message
    )

<<<<<<< HEAD
    begin { . BeginPreamble }
    process {
        try {
=======
    begin { . BeginPreamble }
    process {
        try {
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c


            if ($DebugPreference -eq 'Continue') {
                Write-LogFile($Message)
            }
<<<<<<< HEAD
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
=======
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c
    end{}
}

function Register-ScheduledScriptTask {
    [CmdletBinding()]
    param(

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of the scheduled task")]
        [string]
        $TaskName,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Path to the .ps1 script")]
        [string]
        $ScriptPath,
        
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Arguments to the .ps1 script")]
        [string]
        $Arguments = "",

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Local Account username")]
        [string]
        $LocalUser,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Local Account password")]
        [string]
        $LocalPassword,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Event triggering the task (Startup, Logon, Shutdown, Logoff)")]
        [ValidateSet("Startup","Logon","Shutdown","Logoff")] 
        [string] $EventTrigger,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Specifies an array of one or more trigger objects that start a scheduled task. A task can have a maximum of 48 triggers")]
        [CimInstance[]] 
        $TimeTrigger,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Specifies a configuration that the Task Scheduler service uses to determine how to run a task")]
        [CimInstance] 
        $Settings,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to execute the command as SYSTEM")]
        [switch]
        $AsSystem = $false,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to run the script once if successful")]
        [switch]
        $RunOnce = $false,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to restart the system upon succesful completion")]
        [switch]
        $Restart = $false
    )

<<<<<<< HEAD
    begin { . BeginPreamble }
    process {
        try {
=======
    begin { . BeginPreamble }
    process {
        try {
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c

            $scriptDirectory = Split-Path $ScriptPath
    
            $runOnceCommand = ""
            if ($RunOnce) {
                $runOnceCommand = "; Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"
            }

            $restartCommand = ""
            if ($Restart) {
                $restartCommand = "; Restart-Computer -Force"
            }

            $taskActionArgument = "-ExecutionPolicy Bypass -Command `"try { . '$scriptPath' $Arguments $runOnceCommand $restartCommand } catch { Write `$_.Exception.Message | Out-File ScheduledScriptTask_Log.txt } finally { } `""
            $taskAction = New-ScheduledTaskAction -Execute "$PSHome\powershell.exe" -Argument $taskActionArgument -WorkingDirectory $scriptDirectory
    
            $params = @{
                Force    = $True
                Action   = $taskAction
                RunLevel = "Highest"
                TaskName = $TaskName
            }

            if ($EventTrigger -eq "Startup") {
                $taskTrigger = New-ScheduledTaskTrigger -AtStartup
            }
            elseif ($EventTrigger -eq "Logon") {
                $taskTrigger = New-ScheduledTaskTrigger -AtLogOn
            }
            # TODO add support for Shutdown and Logoff triggers through eventID: https://community.spiceworks.com/how_to/123434-run-powershell-script-on-windows-event

            if ($TimeTrigger) {
                $taskTrigger += $TimeTrigger
            }

            if ($taskTrigger) {
                $params.Add("Trigger", $taskTrigger)
            }

            if ($Settings) {
                $params.Add("Settings", $Settings)
            }

            if ($AsSystem) {
                $params.Add("User", "NT AUTHORITY\SYSTEM")
            }
            else {
                $params.Add("User", $LocalUser)
                $params.Add("Password", $LocalPassword)
            }

            Register-ScheduledTask @params
<<<<<<< HEAD
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
=======
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c
    end{}
}

function Register-AzLabADStudentTask {
    [CmdletBinding()]
    param(
        [parameter(Mandatory = $true, HelpMessage = "Resource group name of Lab Account.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $LabAccountResourceGroupName,

        [parameter(Mandatory = $true, HelpMessage = "Name of Lab Account.", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        $LabAccountName,
    
        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of Lab.")]
        [ValidateNotNullOrEmpty()]
        $LabName,

        [parameter(Mandatory = $true, HelpMessage = "1 or more AD Domain Service addresses (Domain Controller).", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]] $DomainServiceAddress,

        [parameter(Mandatory = $true, HelpMessage = "Domain Name (e.g. contoso.com).", ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [string] $Domain,

        [parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, HelpMessage = "Local User created when setting up the Lab")]
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

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "OUPath")]
        [string]
        $OUPath,
        
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to enroll the VMs to Intune (for Hybrid AD only)")]
        [switch]
        $EnrollMDM = $false,

        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Name of the script")]
        [string]
        $ScriptName
    )
<<<<<<< HEAD
    begin { . BeginPreamble }
    process {
        try {
=======
    begin { . BeginPreamble }
    process {
        try {
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c

            # Serialize arguments for the scheduled startup script
            $domainServiceAddressStr = New-SerializedStringArray $DomainServiceAddress
    
            # Domain join script to run at next startup
            $nextScriptPath = Join-Path (Resolve-Path .\).Path $ScriptName
            $nextTaskName = "Scheduled Task - " + $ScriptName

    $nextScriptArgs =
@"
-LabAccountResourceGroupName '$($LabAccountResourceGroupName)'
-LabAccountName '$($LabAccountName)'
-LabName '$($LabName)'
-DomainServiceAddress $domainServiceAddressStr
-Domain '$Domain'
-LocalUser '$LocalUser'
-DomainUser '$DomainUser'
-LocalPassword '$LocalPassword'
-DomainPassword '$DomainPassword'
-OUPath '$OUPath'
-EnrollMDM:`$$EnrollMDM
-CurrentTaskName '$NextTaskName'
"@.Replace("`n", " ").Replace("`r", "")
    
            Write-LogFile("Schedule Script Task - '$nextTaskName'")
            # Schedule next startup task
            Register-ScheduledScriptTask `
                    -TaskName $nextTaskName `
                    -ScriptPath $nextScriptPath `
                    -Arguments $nextScriptArgs `
                    -LocalUser $LocalUser `
                    -LocalPassword $LocalPassword `
                    -EventTrigger Startup
<<<<<<< HEAD
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
=======
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c
    end{}
}

function Get-UniqueStudentVmName {
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string] $TemplateVmName,
        
        [ValidateNotNullOrEmpty()]
        [string] $StudentVmName
    )

<<<<<<< HEAD
    begin { . BeginPreamble }
    process {
=======
    begin { . BeginPreamble }
    process {
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c
        try {
            $TemplateVmId = $TemplateVmName.Replace("ML-RefVm-", "")
            $StudentVmId = $StudentVmName.Replace("ML-EnvVm-", "")

            # Max Length for Computer name: 15
            # Student Vm name too long. Trunked to last 3 digits.
            # Name of the Template VM: ML-RefVm-924446 -> 924446
            # Name of a VM in the VM pool: ML-EnvVm-987312527 -> 987312527
            # First 9 digits for Pool VM. Second 6 digits for Template

            # TODO convert 1st digit to ASCII character

            # Computer name cannot start with a digit. Prepending a 'M'. Last digit of $TemplateVmId is left out.
            return "M" + $StudentVmId + $TemplateVmId
<<<<<<< HEAD
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
=======
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c
    end{}
}

function Get-AzLabCurrentTemplateVm {
<<<<<<< HEAD
    begin { . BeginPreamble }
    process {
=======
    begin { . BeginPreamble }
    process {
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c
        try {
            # The Azure Instance Metadata Service (IMDS) provides information about currently running virtual machine instances
            $computeVmId = Invoke-RestMethod -Headers @{"Metadata" = "true" } -URI "http://169.254.169.254/metadata/instance/compute/vmId?api-version=2019-11-01&format=text" -Method Get -TimeoutSec 5 
            # Correlate by VM id
            $templateVm = Get-AzLabAccount | Get-AzLab | Get-AzLabTemplateVM | Where-Object { $_.properties.resourceSettings.referenceVm.computeVmId -eq $computeVmId }

            if ($null -eq $templateVm) {
                # Script was run from a Student VM or another VM outside of this Lab.
                throw "Script must be run from the Template VM"
            }

            return $templateVm
<<<<<<< HEAD
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
=======
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c
    end{}
}

# Ideally to be used only once from the Template if we don't uniquely know the Lab. O(LA*LAB*VM)
function Get-AzLabCurrentStudentVm {
<<<<<<< HEAD
    begin { . BeginPreamble }
    process {
        try {
            # The Azure Instance Metadata Service (IMDS) provides information about currently running virtual machine instances
            $computeVmId = Invoke-RestMethod -Headers @{"Metadata" = "true" } -URI "http://169.254.169.254/metadata/instance/compute/vmId?api-version=2019-11-01&format=text" -Method Get -TimeoutSec 5 
            # Correlate by VM id
            $studentVm = Get-AzLabAccount | Get-AzLab | Get-AzLabVm | Where-Object { $_.properties.resourceSets.computeVmId -eq $computeVmId }

            if ($null -eq $studentVm) {
                # Script was run from a Student VM or another VM outside of this Lab.
                throw "Script must be run from a Student VM"
            }

            return $studentVm
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
    end{}
=======
    # The Azure Instance Metadata Service (IMDS) provides information about currently running virtual machine instances
    $computeVmId = Invoke-RestMethod -Headers @{"Metadata" = "true" } -URI "http://169.254.169.254/metadata/instance/compute/vmId?api-version=2019-11-01&format=text" -Method Get -TimeoutSec 5 
    # Correlate by VM id
    $studentVm = Get-AzLabAccount | Get-AzLab | Get-AzLabVm | Where-Object { $_.properties.resourceSets.computeVmId -eq $computeVmId }

    if ($null -eq $studentVm) {
        # Script was run from a Student VM or another VM outside of this Lab.
        throw "Script must be run from a Student VM"
    }

    return $studentVm
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c
}

# To be used from the Student VM where we already know the Lab. O(VM)
function Get-AzLabCurrentStudentVmFromLab {
<<<<<<< HEAD
    [CmdletBinding()]
=======
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "VM claimed by user")]
        [ValidateNotNullOrEmpty()]
        $Lab
    )
<<<<<<< HEAD
    begin { . BeginPreamble }
    process {
        try {
            # The Azure Instance Metadata Service (IMDS) provides information about currently running virtual machine instances
            $computeVmId = Invoke-RestMethod -Headers @{"Metadata" = "true" } -URI "http://169.254.169.254/metadata/instance/compute/vmId?api-version=2019-11-01&format=text" -Method Get -TimeoutSec 5 
            # Correlate by VM id
            $studentVm = $Lab | Get-AzLabVm | Where-Object { $_.properties.resourceSets.computeVmId -eq $computeVmId }

            if ($null -eq $studentVm) {
                # Script was run from a Student VM or another VM outside of this Lab.
                throw "Script must be run from a Student VM"
            }

            return $studentVm
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
    end{}
}

function Get-AzLabUserForCurrentVm {
    [CmdletBinding()]
=======
    # The Azure Instance Metadata Service (IMDS) provides information about currently running virtual machine instances
    $computeVmId = Invoke-RestMethod -Headers @{"Metadata" = "true" } -URI "http://169.254.169.254/metadata/instance/compute/vmId?api-version=2019-11-01&format=text" -Method Get -TimeoutSec 5 
    # Correlate by VM id
    $studentVm = $Lab | Get-AzLabVm | Where-Object { $_.properties.resourceSets.computeVmId -eq $computeVmId }

    if ($null -eq $studentVm) {
        # Script was run from a Student VM or another VM outside of this Lab.
        throw "Script must be run from a Student VM"
    }

    return $studentVm
}

function Get-AzLabUserForCurrentVm {
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "Lab")]
        [ValidateNotNullOrEmpty()]
        $Lab,

        [parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "VM claimed by user")]
        [ValidateNotNullOrEmpty()]
        $Vm
    )
<<<<<<< HEAD
    begin { . BeginPreamble }
    process {
        try {
            $Lab | Get-AzLabUser | Where-Object { $_.name -eq $Vm.properties.claimedByUserPrincipalId }
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
    end{}
}

function Get-AzLabTemplateVmName {
    [CmdletBinding()]
=======

    $Lab | Get-AzLabUser | Where-Object { $_.name -eq $Vm.properties.claimedByUserPrincipalId }
}

function Get-AzLabTemplateVmName {
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "Template VM")]
        [ValidateNotNullOrEmpty()]
        $TemplateVm
    )
<<<<<<< HEAD
    begin { . BeginPreamble }
    process {
        try {
            $results = $TemplateVm.properties.resourceSettings.referenceVm.vmResourceId | Select-String -Pattern '([^/]*)$'
            $results.Matches.Value | Select-Object -Index 0
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
    end{}
}

function Get-AzureADJoinStatus {
    begin { . BeginPreamble }
    process {
        try {
            $status = dsregcmd /status 
            $status.Replace(":", ' ') | 
                ForEach-Object { $_.Trim() }  | 
                ConvertFrom-String -PropertyNames 'State', 'Status'
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
    end{}
} 

function Join-DeviceMDM {
    [CmdletBinding()]
=======

    $results = $TemplateVm.properties.resourceSettings.referenceVm.vmResourceId | Select-String -Pattern '([^/]*)$'
    $results.Matches.Value | Select-Object -Index 0
}

function Get-AzureADJoinStatus {
    $status = dsregcmd /status 
    $status.Replace(":", ' ') | 
        ForEach-Object { $_.Trim() }  | 
        ConvertFrom-String -PropertyNames 'State', 'Status'
} 

function Join-DeviceMDM {
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c
    param(
        [parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Whether to restart the system upon succesful completion")]
        [switch]
        $UseAADDeviceCredential = $false
    )
<<<<<<< HEAD
    begin { . BeginPreamble }
    process {
        try {
            if ($UseAADDeviceCredential){
                . "$env:windir\system32\deviceenroller.exe" /c /AutoEnrollMDMUsingAADDeviceCredential
            } else {
                . "$env:windir\system32\deviceenroller.exe" /c /AutoEnrollMDM
            }
        }
        catch {
            #Write-Error -ErrorRecord $_ -EA $callerEA
            Write-LogFile $_
        }
    }
    end{}
=======

    if ($UseAADDeviceCredential){
        . "$env:windir\system32\deviceenroller.exe" /c /AutoEnrollMDMUsingAADDeviceCredential
    } else {
        . "$env:windir\system32\deviceenroller.exe" /c /AutoEnrollMDM
    }
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c
}

function New-SerializedStringArray {
    param(
        [parameter(Mandatory = $true, ValueFromPipeline = $true, HelpMessage = "String Array")]
        [ValidateNotNullOrEmpty()]
        $Array
    )
    
    $ArrayStr = "'" + $Array[0] + "'"
    $Array | Select-Object -Skip 1 | ForEach-Object {
        $ArrayStr += ",'" + $_ + "'"
    }

    return $ArrayStr
<<<<<<< HEAD
}

Export-ModuleMember -Function   Join-DeviceMDM,
                                Import-AzLabModule,
                                Write-LogFile,
                                Write-DebugFile,
                                Register-ScheduledScriptTask,
                                Register-AzLabADStudentTask,
                                Get-UniqueStudentVmName,
                                Get-AzLabCurrentTemplateVm,
                                Get-AzLabCurrentStudentVm,
                                Get-AzLabCurrentStudentVmFromLab,
                                Get-AzLabUserForCurrentVm,
                                Get-AzLabTemplateVmName,
                                Get-AzureADJoinStatus
=======
}
>>>>>>> 089497fb5e634fd7986704fe0b5a69306904b45c
