﻿function Register-PSFLoggingProvider
{
	<#
		.SYNOPSIS
			Registers a new logging provider to the PSFramework logging system.
		
		.DESCRIPTION
			This function registers all components of the PSFramework logging provider systems.
			It allows you to define your own logging destination and configuration and tie them into the default logging system.
			
			In order to properly utilize its power, it becomes necessary to understand how the logging works beneath the covers:
			- On Start of the logging script, it runs a one-time scriptblock per enabled provider (this will also occur when later enabling a provider)
			- Thereafter the script will continue, logging in cycles of Start > Log all Messages > Log all Errors > End
			Each of those steps has its own event, allowing for fine control over what happens where.
			- Finally, on shutdown of a provider it again offers an option to execute some code (to dispose/free resources in use)
			
			All providers share the same scope for the execution of ALL of those actions/scriptblocks!
			This makes it important to give your variables/functions a unique name, in order to avoid conflicts.
			General Guideline:
			- All variables should start with the name of the provider and an underscore. Example: $filesystem_root
			- All functions should use the name of the provider as prefix. Example: Clean-FileSystemErrorXml
			
			A simple implementation example can be seen with the FileSystem provider, stored in the module folder:
			internal/loggingProvider/filesystem.provider.ps1
		
		.PARAMETER Name
			A unique name for your provider. Registering a provider under a name already registered, NOTHING will happen.
			This function will instead silently terminate.
		
		.PARAMETER Enabled
			Setting this will enable the provider on registration.
		
		.PARAMETER RegistrationEvent
			Scriptblock that should be executed on registration.
			This allows you to perform installation actions synchroneously, with direct user interaction.
			At the same time, by adding it as this parameter, it will only performed on the initial registration, rather than every time the provider is registered (runspaces, Remove-Module/Import-Module)
		
		.PARAMETER BeginEvent
			The actions that should be taken once when setting up the logging.
			Can well be used to register helper functions or loading other resources that should be loaded on start only.
		
		.PARAMETER StartEvent
			The actions taken at the beginning of each logging cycle.
			Typically used to establish connections or do some necessary pre-connections.
		
		.PARAMETER MessageEvent
			The actions taken to process individual messages.
			The very act of writting logs.
			This scriptblock receives a message object (As returned by Get-PSFMessage) as first and only argument.
			Under some circumstances, this message may be a $null object, your scriptblock must be able to handle this.
		
		.PARAMETER ErrorEvent
			The actions taken to process individual error messages.
			The very act of writting logs.
			This scriptblock receives a message object (As returned by 'Get-PSFMessage -Errors') as first and only argument.
			Under some circumstances, this message may be a $null object, your scriptblock must be able to handle this.
			This consists of complex, structured data and may not be suitable to all logging formats.
			However all errors are ALWAYS accompanied by a message, making integrating this optional.
		
		.PARAMETER EndEvent
			Actions taken when finishing up a logging cycle. Can be used to close connections.
		
		.PARAMETER FinalEvent
			Final action to take when the logging terminates.
			This should release all resources reserved.
			This event will fire when:
			- The console is being closed
			- The logging script is stopped / killed
			- The logging provider is disabled
		
		.PARAMETER ConfigurationParameters
			The function Set-PSFLoggingProvider can be used to configure this logging provider.
			Using this parameter it is possible to register dynamic parameters when configuring your provider.
		
		.PARAMETER ConfigurationScript
			When using Set-PSFLoggingProvider, this script can be used to input given by the dynamic parameters generated by the -ConfigurationParameters parameter.
		
		.PARAMETER IsInstalledScript
			A scriptblock verifying that all prerequisites are properly installed.
		
		.PARAMETER InstallationScript
			A scriptblock performing the installation of the provider's prerequisites.
			Used by Install-PSFProvider in conjunction with the script provided by -InstallationParameters
		
		.PARAMETER InstallationParameters
			A scriptblock returning dynamic parameters that are offered when running Install-PSFprovider.
			Those can then be used by the installation scriptblock specified in the aptly named '-InstallationScript' parameter.
		
		.PARAMETER ConfigurationSettings
			This is executed before actually registering the scriptblock.
			It allows you to include any logic you wish, but it is specifically designed for configuration settings using Set-PSFConfig with the '-Initialize' parameter.
	
		.PARAMETER EnableException
			This parameters disables user-friendly warnings and enables the throwing of exceptions.
			This is less user friendly, but allows catching exceptions in calling scripts.
	
		.EXAMPLE
			Register-PSFLoggingProvider -Name "filesystem" -Enabled $true -RegistrationEvent $registrationEvent -BeginEvent $begin_event -StartEvent $start_event -MessageEvent $message_Event -ErrorEvent $error_Event -EndEvent $end_event -FinalEvent $final_event -ConfigurationParameters $configurationParameters -ConfigurationScript $configurationScript -IsInstalledScript $isInstalledScript -InstallationScript $installationScript -InstallationParameters $installationParameters -ConfigurationSettings $configuration_Settings
	
			Registers the filesystem provider, providing events for every single occasion.
#>
	[CmdletBinding(HelpUri = 'https://psframework.org/documentation/commands/PSFramework/Register-PSFLoggingProvider')]
	Param (
		[Parameter(Mandatory = $true)]
		[string]
		$Name,
		
		[switch]
		$Enabled,
		
		[System.Management.Automation.ScriptBlock]
		$RegistrationEvent,
		
		[System.Management.Automation.ScriptBlock]
		$BeginEvent = { },
		
		[System.Management.Automation.ScriptBlock]
		$StartEvent = { },
		
		[Parameter(Mandatory = $true)]
		[System.Management.Automation.ScriptBlock]
		$MessageEvent,
		
		[System.Management.Automation.ScriptBlock]
		$ErrorEvent = { },
		
		[System.Management.Automation.ScriptBlock]
		$EndEvent = { },
		
		[System.Management.Automation.ScriptBlock]
		$FinalEvent = { },
		
		[System.Management.Automation.ScriptBlock]
		$ConfigurationParameters = { },
		
		[System.Management.Automation.ScriptBlock]
		$ConfigurationScript = { },
		
		[System.Management.Automation.ScriptBlock]
		$IsInstalledScript = { $true },
		
		[System.Management.Automation.ScriptBlock]
		$InstallationScript = { },
		
		[System.Management.Automation.ScriptBlock]
		$InstallationParameters = { },
		
		[System.Management.Automation.ScriptBlock]
		$ConfigurationSettings,
		
		[switch]
		$EnableException
	)
	
	if ([PSFramework.Logging.ProviderHost]::Providers.ContainsKey($Name.ToLower()))
	{
		return
	}
	
	if ($ConfigurationSettings) { . $ConfigurationSettings }
	if (Test-PSFParameterBinding -ParameterName Enabled)
	{
		Set-PSFConfig -FullName "LoggingProvider.$Name.Enabled" -Value $Enabled.ToBool() -DisableHandler
	}
	
	$provider = New-Object PSFramework.Logging.Provider
	$provider.Name = $Name
	$provider.BeginEvent = $BeginEvent
	$provider.StartEvent = $StartEvent
	$provider.MessageEvent = $MessageEvent
	$provider.ErrorEvent = $ErrorEvent
	$provider.EndEvent = $EndEvent
	$provider.FinalEvent = $FinalEvent
	$provider.ConfigurationParameters = $ConfigurationParameters
	$provider.ConfigurationScript = $ConfigurationScript
	$provider.IsInstalledScript = $IsInstalledScript
	$provider.InstallationScript = $InstallationScript
	$provider.InstallationParameters = $InstallationParameters
	
	$provider.IncludeModules = Get-PSFConfigValue -FullName "LoggingProvider.$Name.IncludeModules" -Fallback @()
	$provider.ExcludeModules = Get-PSFConfigValue -FullName "LoggingProvider.$Name.ExcludeModules" -Fallback @()
	$provider.IncludeTags = Get-PSFConfigValue -FullName "LoggingProvider.$Name.IncludeTags" -Fallback @()
	$provider.ExcludeTags = Get-PSFConfigValue -FullName "LoggingProvider.$Name.ExcludeTags" -Fallback @()
	
	$provider.InstallationOptional = Get-PSFConfigValue -FullName "LoggingProvider.$Name.InstallOptional" -Fallback $false
	
	[PSFramework.Logging.ProviderHost]::Providers[$Name.ToLower()] = $provider
	
	try { if ($RegistrationEvent) { . $RegistrationEvent } }
	catch
	{
		[PSFramework.Logging.ProviderHost]::Providers.Remove($Name.ToLower())
		Stop-PSFFunction -Message "Failed to register logging provider '$Name' - Registration event failed." -ErrorRecord $_ -EnableException $EnableException -Tag 'logging', 'provider', 'fail', 'register'
		return
	}
	
	$shouldEnable = Get-PSFConfigValue -FullName "LoggingProvider.$Name.Enabled" -Fallback $false
	$isInstalled = [System.Management.Automation.ScriptBlock]::Create($provider.IsInstalledScript).Invoke()
	
	if (-not $isInstalled -and (Get-PSFConfigValue -FullName "LoggingProvider.$Name.AutoInstall" -Fallback $false))
	{
		try { Install-PSFLoggingProvider -Name $Name -EnableException }
		catch
		{
			if ($provider.InstallationOptional)
			{
				Write-PSFMessage -Level Warning -Message "Failed to install logging provider '$Name'" -ErrorRecord $_ -Tag 'logging', 'provider', 'fail', 'install' -EnableException $EnableException
			}
			else
			{
				Stop-PSFFunction -Message "Failed to install logging provider '$Name'" -ErrorRecord $_ -EnableException $EnableException -Tag 'logging', 'provider', 'fail', 'install'
				return
			}
		}
	}
	
	if ($shouldEnable)
	{
		if ($isInstalled) { $provider.Enabled = $true }
		else
		{
			Stop-PSFFunction -Message "Failed to enable logging provider $Name on registration! It was not recognized as installed. Consider running 'Install-PSFLoggingProvider' to properly install the prerequisites." -ErrorRecord $_ -EnableException $EnableException -Tag 'logging', 'provider', 'fail', 'install'
			return
		}
	}
}
