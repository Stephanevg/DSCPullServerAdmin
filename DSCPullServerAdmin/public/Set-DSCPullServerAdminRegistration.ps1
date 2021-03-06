<#
    .SYNOPSIS
    Overwrites node registration entries (LCMv2) in a Pull Server Database.

    .DESCRIPTION
    LCMv2 (WMF5+ / PowerShell 5+) pull clients send information
    to the Pull Server which stores their data in the registrationdata table.
    This function will allow for manual overwrites of registrations properteis
    in the registrationdata table.

    .PARAMETER InputObject
    Pass in the registration object to be modified from the database.

    .PARAMETER AgentId
    Modify properties for the registration with specified AgentId.

    .PARAMETER LCMVersion
    Set the LCMVersion property for the existing device.

    .PARAMETER NodeName
    Set the NodeName property for the existing device.

    .PARAMETER IPAddress
    Set the IPAddress property for the existing device.

    .PARAMETER ConfigurationNames
    Set the ConfigurationNames property for the existing device.

    .PARAMETER Connection
    Accepts a specific Connection to be passed to target a specific database.
    When not specified, the currently Active Connection from memory will be used
    unless one off the parameters for ad-hoc connections (ESEFilePath, SQLServer)
    is used in which case, an ad-hoc connection is created.

    .PARAMETER ESEFilePath
    Define the EDB file path to use an ad-hoc ESE connection.

    .PARAMETER SQLServer
    Define the SQL Instance to use in an ad-hoc SQL connection.

    .PARAMETER Credential
    Define the Credentials to use with an ad-hoc SQL connection.

    .PARAMETER Database
    Define the database to use with an ad-hoc SQL connection.

    .EXAMPLE
    Set-DSCPullServerAdminRegistration -AgentId '80ee20f9-78df-480d-8175-9dd6cb09607a' -ConfigurationNames 'WebServer'

    .EXAMPLE
    Get-DSCPullServerAdminRegistration -AgentId '80ee20f9-78df-480d-8175-9dd6cb09607a' | Set-DSCPullServerAdminRegistration -ConfigurationNames 'WebServer'
#>
function Set-DSCPullServerAdminRegistration {
    [CmdletBinding(
        DefaultParameterSetName = 'InputObject_Connection',
        ConfirmImpact = 'Medium',
        SupportsShouldProcess
    )]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'InputObject_Connection')]
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName = 'InputObject_SQL')]
        [DSCNodeRegistration] $InputObject,

        [Parameter(Mandatory, ParameterSetName = 'Manual_Connection')]
        [Parameter(Mandatory, ParameterSetName = 'Manual_SQL')]
        [guid] $AgentId,

        [Parameter()]
        [ValidateSet('2.0')]
        [string] $LCMVersion = '2.0',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $NodeName,

        [Parameter()]
        [IPAddress[]] $IPAddress,

        [Parameter()]
        [string[]] $ConfigurationNames,

        [Parameter(ParameterSetName = 'InputObject_Connection')]
        [Parameter(ParameterSetName = 'Manual_Connection')]
        [DSCPullServerSQLConnection] $Connection = (Get-DSCPullServerAdminConnection -OnlyShowActive -Type SQL),

        [Parameter(Mandatory, ParameterSetName = 'InputObject_SQL')]
        [Parameter(Mandatory, ParameterSetName = 'Manual_SQL')]
        [ValidateNotNullOrEmpty()]
        [Alias('SQLInstance')]
        [string] $SQLServer,

        [Parameter(ParameterSetName = 'InputObject_SQL')]
        [Parameter(ParameterSetName = 'Manual_SQL')]
        [pscredential] $Credential,

        [Parameter(ParameterSetName = 'InputObject_SQL')]
        [Parameter(ParameterSetName = 'Manual_SQL')]
        [string] $Database
    )

    begin {
        if ($null -ne $Connection -and -not $PSBoundParameters.ContainsKey('Connection')) {
            [void] $PSBoundParameters.Add('Connection', $Connection)
        }
        $Connection = PreProc -ParameterSetName $PSCmdlet.ParameterSetName @PSBoundParameters
        if ($null -eq $Connection) {
            break
        }
    }
    process {
        if (-not $PSBoundParameters.ContainsKey('InputObject')) {
            $existingRegistration = Get-DSCPullServerAdminRegistration -Connection $Connection -AgentId $AgentId
            if ($null -eq $existingRegistration) {
                throw "A NodeRegistration with AgentId '$AgentId' was not found"
            }
        } else {
            $existingRegistration = $InputObject
        }

        $PSBoundParameters.Keys.Where{
            $_ -in ($existingRegistration | Get-Member -MemberType Property).Name
        }.ForEach{
            if ($null -ne $PSBoundParameters.$_) {
                $existingRegistration.$_ = $PSBoundParameters.$_
            }
        }

        $tsqlScript = $existingRegistration.GetSQLUpdate()

        if ($PSCmdlet.ShouldProcess("$($Connection.SQLServer)\$($Connection.Database)", $tsqlScript)) {
            Invoke-DSCPullServerSQLCommand -Connection $Connection -CommandType Set -Script $tsqlScript
        }
    }
}
