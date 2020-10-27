<#
	.SYNOPSIS
    	This script remove OMS agent to disable OMS monitoring.
	
	.DESCRIPTION
     	- The script remove Oms agent on selected VM 

	.INPUTS
        
        $VMResourceGroupName - The name of Resource Group where the VM needs to be created
        $VmName - The Name of VM provided by the customer
        $workspaceName - existing workspace name to connect vm
			
	.OUTPUTS
    	Displays processes step by step during execution
	
	.NOTES
        Author:      Arun Sabale
        Created:     11 Jan 2015
        Version:     1.0  
	
	.Note 
	    Enable the Log verbose records of runbook
		Need AzureRM.OperationalInsights module in automation account to perform this operation.
#> 

 param(
        [Parameter(Mandatory=$True)]
        [String]
        $VMresourcegroup,
        [Parameter(Mandatory=$True)]
        [String]
        $VmName,
		[Parameter(Mandatory=$True)]
        [String]
        $workspaceName
        )

        try
            {
			#The name of the Automation Credential Asset this runbook will use to authenticate to Azure.
			#Connect to your Azure Account   	
            $Conn = Get-AutomationConnection -Name AzurerunasConnection
            $AddAccount = Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID `
            -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint
			
            # Input Validation
            if ($VMResourceGroup -eq $null) {throw "Input parameter ResourceGroup missing"} 
            if ($VmName -eq $null) {throw "Input parameter VmName missing"} 
            if ($workspaceName -eq $null) {throw "Input parameter workspaceName missing"} 
			
				$workspace = (Get-AzureRmOperationalInsightsWorkspace).Where({$_.Name -eq $workspaceName}) 

                if ($workspace.Name -ne $workspaceName)
                {
                    throw "Unable to find OMS Workspace $workspaceName. Do you need to run Select-AzureRMSubscription?"
                }

                $workspaceId = $workspace.CustomerId
                $workspaceKey = (Get-AzureRmOperationalInsightsWorkspaceSharedKeys -ResourceGroupName $workspace.ResourceGroupName -Name $workspace.Name).PrimarySharedKey

                $vm = Get-AzureRmVM -ResourceGroupName $VMresourcegroup -Name $VMName -ErrorAction SilentlyContinue
                $vmStatus = Get-AzureRmVM -ResourceGroupName $VMresourcegroup -Name $VMName  -Status
                $vmStatus1 = $vmStatus.Statuses |where{$_.code -like "PowerState*"}
                if($vmStatus1.code -ne "PowerState/running")
                {
                    throw "VM is not in running state"
                }

                if(!($vm))
                {
                    throw "Unable to find VM"
                }
                $location = $vm.Location

                $OSType  = $vm.StorageProfile.OsDisk.OsType
                if(!($OSType))
                {
                    throw "OS type is not matching"
                }
                if($OSType -eq "windows")
                {
                    
                    remove-AzureRmVMExtension -ResourceGroupName $VMresourcegroup -VMName $VMName -Name 'MicrosoftMonitoringAgent' -Force
                }
                elseif($OSType -eq "linux")
                {
                    
                    remove-AzureRmVMExtension -ResourceGroupName $VMresourcegroup -VMName $VMName -Name 'OmsAgentForLinux' -Force
                    
                }
                Else
                {
                    throw "OS type is not matching"
                }

                #Validation 

                $vm = Get-AzureRmVM -ResourceGroupName $VMresourcegroup -Name $VMName -ErrorAction SilentlyContinue
                $vmExtensions = $vm.Extensions.VirtualMachineExtensionType 
                $vmExtensionsStatus = $false
                if($OSType -eq "windows")
                {
                    
                    if($vmExtensions -notlike "MicrosoftMonitoringAgent")
                    { 
                    $vmExtensionsStatus = $true
                    }
                }
                elseif($OSType -eq "linux")
                {
                   if($vmExtensions -notlike "OmsAgentForLinux")
                    { 
                    $vmExtensionsStatus = $true
                    }
                    
                }
                if($vmExtensionsStatus -like $true)
                {            
                $resultcode = "SUCCESS"
	            Write-Output -InputObject $resultcode
		        Write-Output -InputObject "VM removed from monitoring"
                }
                else
                {
                throw "unable to remove VM from monitoring"
                }
                
            }#end of Try
            catch
            {
                $ErrorState = 1
		        $ErrorMessage = "$_" 			
                $resultcode = "FAILURE"
		        Write-Output -InputObject $resultcode
		        Write-Output -InputObject $ErrorMessage 
            }
