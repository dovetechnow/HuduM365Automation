param($Customer)
New-HuduAPIKey $env:HuduAPIKey
New-HuduBaseURL $env:HuduBaseDomain
$defaultdomain = $customer.DefaultDomainName
$CompanyResult = [PSCustomObject]@{
	Name    = $customer.DisplayName
	Users   = 0
	Devices = 0
	Errors  = [System.Collections.Generic.List[string]]@()
}
$PeopleLayoutName = $env:PeopleLayoutName
$CreateUsers = [System.Convert]::ToBoolean($env:CreateUsers)
$DesktopsName = $env:DesktopsName
$MobilesName = $env:MobilesName
$CreateDevices = [System.Convert]::ToBoolean($env:CreateDevices)
$CreateMobileDevices = [System.Convert]::ToBoolean($env:CreateMobileDevices)
$CreateInOverview = [System.Convert]::ToBoolean($env:CreateInOverview)
$OverviewCompany = $env:OverviewCompany
$importDomains = [System.Convert]::ToBoolean($env:importDomains)
$monitorDomains = [System.Convert]::ToBoolean($env:monitorDomains)
$IntuneDesktopDeviceTypes = $env:IntuneDesktopDeviceTypes -split ','
$ExcludeSerials = $env:ExcludeSerials -split ','
$LicenseLookup = Get-LicenseLookup
$AssignedMap = Get-AssignedMap
$AssignedNameMap = Get-AssignedNameMap
$EnableCIPP = [System.Convert]::ToBoolean($env:EnableCIPP)
$CIPPURL = $env:CIPPURL
try {
	$hududomain = Get-HuduWebsites -Name "https://$defaultdomain" -ea stop
	$domaincount = ($hududomain.id | Measure-Object).count
	if ($domaincount -eq 1) {
		$TenantFilter = $Customer.CustomerId
		$company_name = $hududomain[0].company_name
		$company_id = $hududomain[0].company_id
		try {
			$Authheaders = Get-GraphToken -tenantid $TenantFilter
		} catch {
			Throw 'Failed to authenticate to tenant'
		}
		$huduCustomerDetails = Get-HuduAssets -asset_layout_id 101 -company_id $company_id
		if (!($huduCustomerDetails)) {
			$huduCustomerDetails = New-HuduAsset -Name $($company_info.nickname) -CompanyId $($company_id) -AssetLayoutId 101 -PrimarySerial $company_info.nickname
			$huduCustomerDetails = Get-HuduAssets -asset_layout_id 101 -company_id $company_id
		}
		$PeopleLayout = Get-HuduAssetLayouts -Name $env:PeopleLayoutName
		$People = Get-HuduAssets -CompanyId $company_id -AssetLayoutId $PeopleLayout.id
		$DesktopsLayout = Get-HuduAssetLayouts -Name $env:DesktopsName
		$HuduDesktopDevices = Get-HuduAssets -CompanyId $company_id -AssetLayoutId $DesktopsLayout.id
		$MobilesLayout = Get-HuduAssetLayouts -Name $env:MobilesName
		$HuduMobileDevices = Get-HuduAssets -CompanyId $company_id -AssetLayoutId $MobilesLayout.id
		$HuduRelations = Get-HuduRelations
		try {
			$HuduDevices = $HuduDesktopDevices + $HuduMobileDevices
		} catch {
			try {
				$HuduDevices = $HuduMobileDevices + $HuduDesktopDevices
			} catch {
				$HuduDevices = $Null
			}
		}
		$CustomerLinks = "<div class=`"nasa__content`">
		<div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://portal.office.com/Partner/BeginClientSession.aspx?CTID=$($customer.CustomerId)&CSDEST=o365admincenter')`"><h3><i class=`"fas fa-cogs`">&nbsp;&nbsp;&nbsp;</i>M365 Admin Portal</h3></button></div>
		<div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://outlook.office365.com/ecp/?rfr=Admin_o365&exsvurl=1&delegatedOrg=$($Customer.DefaultDomainName)')`"><h3><i class=`"fas fa-mail-bulk`">&nbsp;&nbsp;&nbsp;</i>Exchange Admin Portal</h3></button></div>
		<div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://aad.portal.azure.com/$($Customer.DefaultDomainName)')`" ><h3><i class=`"fas fa-users-cog`">&nbsp;&nbsp;&nbsp;</i>Azure Active Directory</h3></button></div>
		<div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://endpoint.microsoft.com/$($customer.DefaultDomainName)/')`"><h3><i class=`"fas fa-laptop`">&nbsp;&nbsp;&nbsp;</i>Endpoint Management</h3></button></td></div>
		<div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://portal.office.com/Partner/BeginClientSession.aspx?CTID=$($Customer.CustomerId)&CSDEST=MicrosoftCommunicationsOnline')`"><h3><i class=`"fab fa-skype`">&nbsp;&nbsp;&nbsp;</i>Sfb Portal</h3></button></div>
		<div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://admin.teams.microsoft.com/?delegatedOrg=$($Customer.DefaultDomainName)')`"><h3><i class=`"fas fa-users`">&nbsp;&nbsp;&nbsp;</i>Teams Portal</h3></button></div>
		<div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://portal.azure.com/$($customer.DefaultDomainName)')`"><h3><i class=`"fas fa-server`">&nbsp;&nbsp;&nbsp;</i>Azure Portal</h3></button></div>
		<div class=`"nasa__block`"><button class=`"button`" onclick=`"window.open('https://account.activedirectory.windowsazure.com/usermanagement/multifactorverification.aspx?tenantId=$($Customer.CustomerId)&culture=en-us&requestInitiatedContext=users')`" ><h3><i class=`"fas fa-key`">&nbsp;&nbsp;&nbsp;</i>MFA Portal (Read Only)</h3></button></div>
		</div>"
		[System.Collections.Generic.List[PSCustomObject]]$TenantRequests = @(
			@{
				id      ='Users'
				method  = 'GET'
				url     = '/users?$filter=assignedLicenses/$count ne 0&$count=true'
				headers = @{
					'ConsistencyLevel' = 'eventual'
				}
			},
			@{
				id     = 'AllRoles'
				method = 'GET'
				url    = '/directoryRoles'
			},
			@{
				id     = 'RawDomains'
				method = 'GET'
				url    = '/domains'
			},
			@{
				id     = 'Licenses'
				method = 'GET'
				url    = '/subscribedSkus'
			},
			@{
				id     = 'Devices'
				method = 'GET'
				url    = '/deviceManagement/managedDevices'
			},
			@{
				id     = 'DeviceCompliancePolicies'
				method = 'GET'
				url    = '/deviceManagement/deviceCompliancePolicies/'
			},
			@{
				id     = 'DeviceApps'
				method = 'GET'
				url    = '/deviceAppManagement/mobileApps'
			},
			@{
				id     = 'Groups'
				method = 'GET'
				url    = '/groups'
			},
			@{
				id     = 'ConditionalAccess'
				method = 'GET'
				url    = '/identity/conditionalAccess/policies'
			}
		)
		try {
			$TenantResults = New-GraphBulkRequest -Headers $AuthHeaders -Requests $TenantRequests -tenantid $TenantFilter
		} catch {
			Write-Host $_.Exception.Message
			Throw 'Company: Failed to fetch bulk company data'
		}
		$Users = Get-BulkResultByID -Results $TenantResults -ID 'Users'
		$licensedUsers = $Users | Where-Object { $null -ne $_.AssignedLicenses.SkuId } | Sort-Object UserPrincipalName
		$CompanyResult.users = ($licensedUsers | Measure-Object).count
		$AllRoles = Get-BulkResultByID -Results $TenantResults -ID 'AllRoles'
		$SelectList = 'id', 'displayName', 'userPrincipalName'
		[System.Collections.Generic.List[PSCustomObject]]$RolesRequestArray = @()
		foreach ($Role in $AllRoles) {
			$RolesRequestArray.add(@{
					id     = $Role.id
					method = 'GET'
					url    = "/directoryRoles/$($Role.id)/members?`$select=$($selectlist -join ',')"
				})
		}
		try {
			$MemberReturn = New-GraphBulkRequest -Headers $AuthHeaders -Requests $RolesRequestArray -tenantid $TenantFilter
		} catch {
			$CompanyResult.Errors.add("Company: Unable to fetch roles $_")
			$MemberReturn = $null
		}
		$Roles = foreach ($Result in $MemberReturn) {
			[PSCustomObject]@{
				ID            = $Result.id
				DisplayName   = ($AllRoles | Where-Object { $_.id -eq $Result.id }).displayName
				Description   = ($AllRoles | Where-Object { $_.id -eq $Result.id }).description
				Members       = $Result.body.value
				ParsedMembers = $Result.body.value.Displayname -join ', '
			}
		}
		$pre = "<div class=`"nasa__block`"><header class='nasa__block-header'>
		<h1><i class='fas fa-users icon'></i>Assigned Roles</h1>
		</header>"
		$post = '</div>'
		$RolesHtml = $Roles | Select-Object DisplayName, Description, ParsedMembers | ConvertTo-Html -PreContent $pre -PostContent $post -Fragment | ForEach-Object { $tmp = $_ -replace '&lt;', '<'; $tmp -replace '&gt;', '>'; } | Out-String
		$AdminUsers = (($Roles | Where-Object { $_.Displayname -match 'Administrator' }).Members | Where-Object { $null -ne $_.displayName } | Select-Object @{N = 'Name'; E = { "<a target='_blank' href='https://aad.portal.azure.com/$($Customer.DefaultDomainName)/#blade/Microsoft_AAD_IAM/UserDetailsMenuBlade/Profile/userId/$($_.Id)'>$($_.DisplayName) - $($_.UserPrincipalName)</a>" } } -Unique).name -join '<br/>'
		$RawDomains = Get-BulkResultByID -Results $TenantResults -ID 'RawDomains'
		$customerDomains = ($RawDomains | Where-Object { $_.IsVerified -eq $True }).id -join ', ' | Out-String
		$detailstable = "<div class='nasa__block'>
		<header class='nasa__block-header'>
		<h1><i class='fas fa-info-circle icon'></i>Basic Info</h1>
		</header>
		<main>
		<article>
		<div class='basic_info__section'>
		<h2>Tenant Name</h2>
		<p>
		$($customer.DisplayName)
		</p>
		</div>
		<div class='basic_info__section'>
		<h2>Tenant ID</h2>
		<p>
		$($customer.customerId)
		</p>
		</div>
		<div class='basic_info__section'>
		<h2>Default Domain</h2>
		<p>
		$defaultdomain
		</p>
		</div>
		<div class='basic_info__section'>
		<h2>Customer Domains</h2>
		<p>
		$customerDomains
		</p>
		</div>
		<div class='basic_info__section'>
		<h2>Admin Users</h2>
		<p>
		$AdminUsers
		</p>
		</div>
		<div class='basic_info__section'>
		<h2>Last Updated</h2>
		<p>
		$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
		</p>
		</div>
		</article>
		</main>
		</div>"
		Set-HuduAsset -asset_id $huduCustomerDetails.id -Name $($huduCustomerDetails.name) -company_id $($company_id) -asset_layout_id 101 -Fields @(@{ 'Organization Display Name' = $($customer.DisplayName); 'Microsoft 365 Default Domain' = $($defaultdomain); 'Microsoft 365 All Domains' = $($customerDomains) ; 'Microsoft 365 TenantID' = $($customer.customerId); 'Microsoft 365 Summary' = "Users: $($CompanyResult.Users), Devices: $($CompanyResult.Devices)`r`nLast Sync: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" })
		$Licenses = Get-BulkResultByID -Results $TenantResults -ID 'Licenses'
		if ($Licenses) {
			$pre = "<div class=`"nasa__block`"><header class='nasa__block-header'>
			<h1><i class='fas fa-info-circle icon'></i>Current Licenses</h1>
			</header>"
			$post = '</div>'
			$licenseOut = $Licenses | Where-Object { $_.PrepaidUnits.Enabled -gt 0 } | Select-Object @{N = 'License Name'; E = { $($LicenseLookup.$($_.SkuPartNumber)) } }, @{N = 'Active'; E = { $_.PrepaidUnits.Enabled } }, @{N = 'Consumed'; E = { $_.ConsumedUnits } }, @{N = 'Unused'; E = { $_.PrepaidUnits.Enabled - $_.ConsumedUnits } }
			$licenseHTML = $licenseOut | ConvertTo-Html -PreContent $pre -PostContent $post -Fragment | Out-String
		}
		$devices = Get-BulkResultByID -Results $TenantResults -ID 'Devices'
		$CompanyResult.Devices = ($Devices | Measure-Object).count
		$DeviceCompliancePolicies = Get-BulkResultByID -Results $TenantResults -ID 'DeviceCompliancePolicies'
		[System.Collections.Generic.List[PSCustomObject]]$PolicyRequestArray = @()
		foreach ($CompliancePolicy in $DeviceCompliancePolicies) {
			$PolicyRequestArray.add(@{
					id     = $CompliancePolicy.id
					method = 'GET'
					url    = "/deviceManagement/deviceCompliancePolicies/$($CompliancePolicy.id)/deviceStatuses"
				})
		}
		try {
			$PolicyReturn = New-GraphBulkRequest -Headers $AuthHeaders -Requests $PolicyRequestArray -tenantid $TenantFilter
		} catch {
			$CompanyResult.Errors.add("Company: Unable to fetch Policies $_")
			$PolicyReturn = $null
		}
		$DeviceComplianceDetails = foreach ($Result in $PolicyReturn) {
			[pscustomobject]@{
				ID             = ($DeviceCompliancePolicies | Where-Object { $_.id -eq $Result.id }).id
				DisplayName    = ($DeviceCompliancePolicies | Where-Object { $_.id -eq $Result.id }).DisplayName
				DeviceStatuses = $Result.body.value
			}
		}
		$DeviceApps = Get-BulkResultByID -Results $TenantResults -ID 'DeviceApps'
		[System.Collections.Generic.List[PSCustomObject]]$RequestArray = @()
		foreach ($InstalledApp in $DeviceApps | Where-Object { $_.isAssigned -eq $True }) {
			$RequestArray.add(@{
					id     = $InstalledApp.id
					method = 'GET'
					url    = "/deviceAppManagement/mobileApps/$($InstalledApp.id)/deviceStatuses"
				})
		}
		try {
			$InstalledAppDetailsReturn = New-GraphBulkRequest -Headers $AuthHeaders -Requests $RequestArray -tenantid $TenantFilter
		} catch {
			$CompanyResult.Errors.add("Company: Unable to fetch Installed Device Details $_")
			$InstalledAppDetailsReturn = $null
		}
		$DeviceAppInstallDetails = foreach ($Result in $InstalledAppDetailsReturn) {
			[pscustomobject]@{
				ID                  = $Result.id
				DisplayName         = ($DeviceApps | Where-Object { $_.id -eq $Result.id }).DisplayName
				InstalledAppDetails = $result.body.value
			}
		}
		$AllGroups = Get-BulkResultByID -Results $TenantResults -ID 'Groups'
		[System.Collections.Generic.List[PSCustomObject]]$GroupRequestArray = @()
		foreach ($Group in $AllGroups) {
			$GroupRequestArray.add(@{
					id     = $Group.id
					method = 'GET'
					url    = "/groups/$($Group.id)/members"
				})
		}
		try {
			$GroupMembersReturn = New-GraphBulkRequest -Headers $AuthHeaders -Requests $GroupRequestArray -tenantid $TenantFilter
		} catch {
			$CompanyResult.Errors.add("Company: Unable to fetch Group Membership Details $_")
			$GroupMembersReturn = $null
		}
		$Groups = foreach ($Result in $GroupMembersReturn) {
			[pscustomobject]@{
				ID          = $Result.id
				DisplayName = ($AllGroups | Where-Object { $_.id -eq $Result.id }).DisplayName
				Members     = $result.body.value
			}
		}
		$AllConditionalAccessPolicies = Get-BulkResultByID -Results $TenantResults -ID 'ConditionalAccess'
		$ConditionalAccessMembers = foreach ($CAPolicy in $AllConditionalAccessPolicies) {
			[System.Collections.Generic.List[PSCustomObject]]$CAMembers = @()
			if ($CAPolicy.conditions.users.includeUsers -contains 'All') {
				$Users | ForEach-Object { $null = $CAMembers.add($_.id) }
			} else {
				$CAPolicy.conditions.users.includeUsers | ForEach-Object { $null = $CAMembers.add($_) }
			}
			foreach ($CAIGroup in $CAPolicy.conditions.users.includeGroups) {
				foreach ($Member in ($Groups | Where-Object { $_.id -eq $CAIGroup }).Members) {
					$null = $CAMembers.add($Member.id)
				}
			}
			foreach ($CAIRole in $CAPolicy.conditions.users.includeRoles) {
				foreach ($Member in ($Roles | Where-Object { $_.id -eq $CAIRole }).Members) {
					$null = $CAMembers.add($Member.id)
				}
			}
			$CAMembers = $CAMembers | Select-Object -Unique
			if ($CAMembers) {
				$CAPolicy.conditions.users.excludeUsers | ForEach-Object { $null = $CAMembers.remove($_) }
				foreach ($CAEGroup in $CAPolicy.conditions.users.excludeGroups) {
					foreach ($Member in ($Groups | Where-Object { $_.id -eq $CAEGroup }).Members) {
						$null = $CAMembers.remove($Member.id)
					}
				}
				foreach ($CAIRole in $CAPolicy.conditions.users.excludeRoles) {
					foreach ($Member in ($Roles | Where-Object { $_.id -eq $CAERole }).Members) {
						$null = $CAMembers.remove($Member.id)
					}
				}
			}
			[pscustomobject]@{
				ID          = $CAPolicy.id
				DisplayName = $CAPolicy.DisplayName
				Members     = $CAMembers
			}
		}
		try {
			$OneDriveDetails = New-GraphGetRequest -uri "https://graph.microsoft.com/beta/reports/getOneDriveUsageAccountDetail(period='D7')" -tenantid $TenantFilter | ConvertFrom-Csv
		} catch {
			$CompanyResult.Errors.add("Company: Unable to fetch One Drive Details $_")
			$OneDriveDetails = $null
		}
		try {
			$CASFull = New-GraphGetRequest -uri "https://outlook.office365.com/adminapi/beta/$($tenantfilter)/CasMailbox" -Tenantid $tenantfilter -scope ExchangeOnline -noPagination $true
		} catch {
			$CASFull = $null
			$CompanyResult.Errors.add("Company: Unable to fetch CAS Mailbox Details $_")
		}
		try {
			$MailboxDetailedFull = New-ExoRequest -TenantID $TenantFilter -cmdlet 'Get-Mailbox'
		} catch {
			$CompanyResult.Errors.add("Company: Unable to fetch Mailbox Details $_")
			$MailboxDetailedFull = $null
		}
		try {
			$MailboxStatsFull = New-GraphGetRequest -uri "https://graph.microsoft.com/v1.0/reports/getMailboxUsageDetail(period='D7')" -tenantid $TenantFilter | ConvertFrom-Csv
		} catch {
			$CompanyResult.Errors.add("Company: Unable to fetch Mailbox Statistic Details $_")
			$MailboxStatsFull = $null
		}
		if ($licensedUsers) {
			$pre = "<div class=`"nasa__block`"><header class='nasa__block-header'>
			<h1><i class='fas fa-users icon'></i>Licensed Users</h1>
			</header>"
			$post = '</div>'
			$OutputUsers = foreach ($user in $licensedUsers) {
				try {
					$UserGroups = foreach ($Group in $Groups) {
						if ($User.id -in $Group.Members.id) {
							$FoundGroup = $AllGroups | Where-Object { $_.id -eq $Group.id }
							[PSCustomObject]@{
								'Display Name'   = $FoundGroup.displayName
								'Mail Enabled'   = $FoundGroup.mailEnabled
								'Mail'           = $FoundGroup.mail
								'Security Group' = $FoundGroup.securityEnabled
								'Group Types'    = $FoundGroup.groupTypes -join ','
							}
						}
					}
					$UserPolicies = foreach ($cap in $ConditionalAccessMembers) {
						if ($User.id -in $Cap.Members) {
							$temp = [PSCustomObject]@{
								displayName = $cap.displayName
							}
							$temp
						}
					}
					$PermsRequest = ''
					$StatsRequest = ''
					$MailboxDetailedRequest = ''
					$CASRequest = ''
					$CASRequest = $CASFull | Where-Object { $_.ExternalDirectoryObjectId -eq $User.iD }
					$MailboxDetailedRequest = $MailboxDetailedFull | Where-Object { $_.ExternalDirectoryObjectId -eq $User.iD }
					$StatsRequest = $MailboxStatsFull | Where-Object { $_.'User Principal Name' -eq $User.UserPrincipalName }
					try {
						$PermsRequest = New-GraphGetRequest -uri "https://outlook.office365.com/adminapi/beta/$($tenantfilter)/Mailbox('$($User.ID)')/MailboxPermission" -Tenantid $tenantfilter -scope ExchangeOnline -noPagination $true
					} catch {
						$PermsRequest = $null
					}
					$ParsedPerms = foreach ($Perm in $PermsRequest) {
						if ($Perm.User -ne 'NT AUTHORITY\SELF') {
							[pscustomobject]@{
								User         = $Perm.User
								AccessRights = $Perm.PermissionList.AccessRights -join ', '
							}
						}
					}
					try {
						$TotalItemSize = [math]::Round($StatsRequest.'Storage Used (Byte)' / 1Gb, 2)
					} catch {
						$TotalItemSize = 0
					}
					$UserMailSettings = [pscustomobject]@{
						ForwardAndDeliver        = $MailboxDetailedRequest.DeliverToMailboxAndForward
						ForwardingAddress        = $MailboxDetailedRequest.ForwardingAddress + ' ' + $MailboxDetailedRequest.ForwardingSmtpAddress
						LitiationHold            = $MailboxDetailedRequest.LitigationHoldEnabled
						HiddenFromAddressLists   = $MailboxDetailedRequest.HiddenFromAddressListsEnabled
						EWSEnabled               = $CASRequest.EwsEnabled
						MailboxMAPIEnabled       = $CASRequest.MAPIEnabled
						MailboxOWAEnabled        = $CASRequest.OWAEnabled
						MailboxImapEnabled       = $CASRequest.ImapEnabled
						MailboxPopEnabled        = $CASRequest.PopEnabled
						MailboxActiveSyncEnabled = $CASRequest.ActiveSyncEnabled
						Permissions              = $ParsedPerms
						ProhibitSendQuota        = [math]::Round([float]($MailboxDetailedRequest.ProhibitSendQuota -split ' GB')[0], 2)
						ProhibitSendReceiveQuota = [math]::Round([float]($MailboxDetailedRequest.ProhibitSendReceiveQuota -split ' GB')[0], 2)
						ItemCount                = [math]::Round($StatsRequest.'Item Count', 2)
						TotalItemSize            = $TotalItemSize
					}
					$userDevices = ($devices | Where-Object { $_.userPrincipalName -eq $user.UserPrincipalName } | Select-Object @{N = 'Name'; E = { "<a target='_blank' href=https://endpoint.microsoft.com/$($customer.DefaultDomainName)/#blade/Microsoft_Intune_Devices/DeviceSettingsBlade/overview/mdmDeviceId/$($_.id)>$($_.deviceName) ($($_.operatingSystem))" } }).name -join '<br/>'
					$UserDevicesDetailsRaw = $devices | Where-Object { $_.userPrincipalName -eq $user.UserPrincipalName } | Select-Object @{N = 'Name'; E = { "<a target='_blank' href=https://endpoint.microsoft.com/$($customer.DefaultDomainName)/#blade/Microsoft_Intune_Devices/DeviceSettingsBlade/overview/mdmDeviceId/$($_.id)>$($_.deviceName)</a>" } }, @{n = 'Owner'; e = { $_.managedDeviceOwnerType } }, `
					@{n = 'Enrolled'; e = { $_.enrolledDateTime } }, `
					@{n = 'Last Sync'; e = { $_.lastSyncDateTime } }, `
					@{n = 'OS'; e = { $_.operatingSystem } }, `
					@{n = 'OS Version'; e = { $_.osVersion } }, `
					@{n = 'State'; e = { $_.complianceState } }, `
					@{n = 'Model'; e = { $_.model } }, `
					@{n = 'Manufacturer'; e = { $_.manufacturer } },
					deviceName,
					@{n = 'url'; e = { "https://endpoint.microsoft.com/$($customer.DefaultDomainName)/#blade/Microsoft_Intune_Devices/DeviceSettingsBlade/overview/mdmDeviceId/$($_.id)" } }
					$aliases = (($user.ProxyAddresses | Where-Object { $_ -cnotmatch 'SMTP' -and $_ -notmatch '.onmicrosoft.com' }) -replace 'SMTP:', ' ') -join ', '
					$userLicenses = ($user.AssignedLicenses.SkuID | ForEach-Object {
							$UserLic = $_
							$SkuPartNumber = ($Licenses | Where-Object { $_.SkuId -eq $UserLic }).SkuPartNumber
							try {
								"$($LicenseLookup.$SkuPartNumber)"
							} catch {
								"$SkuPartNumber"
							}
						}) -join ', '
					$userLicenses = $userLicenses -replace ', ,', ','
					$userLicenses = $userLicenses -replace ',,', ','
					$userLicenses = $userLicenses -replace 'Microsoft 365', 'M365'
					$UserOneDriveDetails = $OneDriveDetails | Where-Object { $_.'Owner Principal Name' -eq $user.UserPrincipalName }
					[System.Collections.Generic.List[PSCustomObject]]$OneDriveFormatted = @()
					if ($UserOneDriveDetails) {
						try {
							$OneDriveUsePercent = [math]::Round([float](($UserOneDriveDetails.'Storage Used (Byte)' / $UserOneDriveDetails.'Storage Allocated (Byte)') * 100), 2)
							$StorageUsed = [math]::Round($UserOneDriveDetails.'Storage Used (Byte)' / 1024 / 1024 / 1024, 2)
							$StorageAllocated = [math]::Round($UserOneDriveDetails.'Storage Allocated (Byte)' / 1024 / 1024 / 1024, 2)
						} catch {
							$OneDriveUsePercent = 100
							$StorageUsed = 0
							$StorageAllocated = 0
						}
						$OneDriveFormatted.add($(Get-FormatedField -Title 'Owner Principal Name' -Value "$($UserOneDriveDetails.'Owner Principal Name')"))
						$OneDriveFormatted.add($(Get-FormatedField -Title 'One Drive URL' -Value "<a href=$($UserOneDriveDetails.'Site URL')>$($UserOneDriveDetails.'Site URL')</a>"))
						$OneDriveFormatted.add($(Get-FormatedField -Title 'Is Deleted' -Value "$($UserOneDriveDetails.'Is Deleted')"))
						$OneDriveFormatted.add($(Get-FormatedField -Title 'Last Activity Date' -Value "$($UserOneDriveDetails.'Last Activity Date')"))
						$OneDriveFormatted.add($(Get-FormatedField -Title 'File Count' -Value "$($UserOneDriveDetails.'File Count')"))
						$OneDriveFormatted.add($(Get-FormatedField -Title 'Active File Count' -Value "$($UserOneDriveDetails.'Active File Count')"))
						$OneDriveFormatted.add($(Get-FormatedField -Title 'Storage Used (Byte)' -Value "$($UserOneDriveDetails.'Storage Used (Byte)')"))
						$OneDriveFormatted.add($(Get-FormatedField -Title 'Storage Allocated (Byte)' -Value "$($UserOneDriveDetails.'Storage Allocated (Byte)')"))
						$OneDriveUserUsage = "
						<div class=`"o365-usage`">
						<div class=`"o365-mailbox`">
						<div class=`"o365-used`" style=`"width: $($OneDriveUsePercent)%;`"></div>
						</div>
						<div><b>$($StorageUsed) GB</b> used, <b>$($OneDriveUsePercent)%</b> of <b>$($StorageAllocated) GB</b></div>
						</div>"
						$OneDriveFormatted.add($(Get-FormatedField -Title 'One Drive Usage' -Value $OneDriveUserUsage))
					}
					[System.Collections.Generic.List[PSCustomObject]]$UserMailSettingsFormatted = @()
					[System.Collections.Generic.List[PSCustomObject]]$UserMailboxDetailsFormatted = @()
					if ($UserMailSettings) {
						$UserMailSettingsFormatted.add($(Get-FormatedField -Title 'Forward and Deliver' -Value "$($UserMailSettings.ForwardAndDeliver)"))
						$UserMailSettingsFormatted.add($(Get-FormatedField -Title 'Forwarding Address' -Value "$($UserMailSettings.ForwardingAddress)"))
						$UserMailSettingsFormatted.add($(Get-FormatedField -Title 'Litiation Hold' -Value "$($UserMailSettings.LitiationHold)"))
						$UserMailSettingsFormatted.add($(Get-FormatedField -Title 'Hidden From Address Lists' -Value "$($UserMailSettings.HiddenFromAddressLists)"))
						$UserMailSettingsFormatted.add($(Get-FormatedField -Title 'EWS Enabled' -Value "$($UserMailSettings.EWSEnabled)"))
						$UserMailSettingsFormatted.add($(Get-FormatedField -Title 'MAPI Enabled' -Value "$($UserMailSettings.MailboxMAPIEnabled)"))
						$UserMailSettingsFormatted.add($(Get-FormatedField -Title 'OWA Enabled' -Value "$($UserMailSettings.MailboxOWAEnabled)"))
						$UserMailSettingsFormatted.add($(Get-FormatedField -Title 'IMAP Enabled' -Value "$($UserMailSettings.MailboxImapEnabled)"))
						$UserMailSettingsFormatted.add($(Get-FormatedField -Title 'POP Enabled' -Value "$($UserMailSettings.MailboxPopEnabled)"))
						$UserMailSettingsFormatted.add($(Get-FormatedField -Title 'Active Sync Enabled' -Value "$($UserMailSettings.MailboxActiveSyncEnabled)"))
						$UserMailboxDetailsFormatted.add($(Get-FormatedField -Title 'Permissions' -Value "$($UserMailSettings.Permissions | ConvertTo-Html -Fragment | Out-String)"))
						$UserMailboxDetailsFormatted.add($(Get-FormatedField -Title 'Prohibit Send Quota' -Value "$($UserMailSettings.ProhibitSendQuota)"))
						$UserMailboxDetailsFormatted.add($(Get-FormatedField -Title 'Prohibit Send Receive Quota' -Value "$($UserMailSettings.ProhibitSendReceiveQuota)"))
						$UserMailboxDetailsFormatted.add($(Get-FormatedField -Title 'Item Count' -Value "$($UserMailSettings.ItemCount)"))
						$UserMailboxDetailsFormatted.add($(Get-FormatedField -Title 'Total Mailbox Size' -Value "$($UserMailSettings.TotalItemSize)"))
						try {
							$UserMailboxUsePercent = [math]::Round([float](($UserMailSettings.TotalItemSize / $UserMailSettings.ProhibitSendReceiveQuota) * 100), 2)
						} catch {
							$UserMailboxUsePercent = 100
						}
						$UserMailboxUsage = "
						<div class=`"o365-usage`">
						<div class=`"o365-mailbox`">
						<div class=`"o365-used`" style=`"width: $($UserMailboxUsePercent)%;`"></div>
						</div>
						<div><b>$([math]::Round($UserMailSettings.TotalItemSize,2)) GB</b> used, <b>$($UserMailboxUsePercent)%</b> of <b>$([math]::Round($UserMailSettings.ProhibitSendReceiveQuota, 2)) GB</b></div>
						</div>"
						$UserMailboxDetailsFormatted.add($(Get-FormatedField -Title 'Mailbox Usage' -Value $UserMailboxUsage))
					}
					$UserPoliciesFormatted = '<ul>'
					foreach ($Policy in $UserPolicies) {
						$UserPoliciesFormatted = $UserPoliciesFormatted + "<li>$($Policy.displayName)</li>"
					}
					$UserPoliciesFormatted = $UserPoliciesFormatted + '</ul>'
					[System.Collections.Generic.List[PSCustomObject]]$UserOverviewFormatted = @()
					$UserOverviewFormatted.add($(Get-FormatedField -Title 'User Name' -Value "$($User.displayName)"))
					$UserOverviewFormatted.add($(Get-FormatedField -Title 'User Principal Name' -Value "$($User.userPrincipalName)"))
					$UserOverviewFormatted.add($(Get-FormatedField -Title 'User ID' -Value "$($User.ID)"))
					$UserOverviewFormatted.add($(Get-FormatedField -Title 'User Enabled' -Value "$($User.accountEnabled)"))
					$UserOverviewFormatted.add($(Get-FormatedField -Title 'Job Title' -Value "$($User.jobTitle)"))
					$UserOverviewFormatted.add($(Get-FormatedField -Title 'Mobile Phone' -Value "$($User.mobilePhone)"))
					$UserOverviewFormatted.add($(Get-FormatedField -Title 'Business Phones' -Value "$($User.businessPhones -join ', ')"))
					$UserOverviewFormatted.add($(Get-FormatedField -Title 'Office Location' -Value "$($User.officeLocation)"))
					$UserOverviewFormatted.add($(Get-FormatedField -Title 'Aliases' -Value "$aliases"))
					$UserOverviewFormatted.add($(Get-FormatedField -Title 'Licenses' -Value "$($userLicenses)"))
					$AssignedPlans = $User.assignedplans | Where-Object { $_.capabilityStatus -eq 'Enabled' } | Select-Object @{n = 'Assigned'; e = { $_.assignedDateTime } }, @{n = 'Service'; e = { $_.service } } -Unique
					[System.Collections.Generic.List[PSCustomObject]]$AssignedPlansFormatted = @()
					foreach ($AssignedPlan in $AssignedPlans) {
						if ($AssignedPlan.service -in ($AssignedMap | Get-Member -MemberType NoteProperty).name) {
							$CSSClass = $AssignedMap."$($AssignedPlan.service)"
							$PlanDisplayName = $AssignedNameMap."$($AssignedPlan.service)"
							$ParsedDate = Get-Date($AssignedPlan.Assigned) -Format 'yyyy-MM-dd HH:mm:ss'
							$AssignedPlansFormatted.add("<div class='o365__app $CSSClass' style='text-align:center'><strong>$PlanDisplayName</strong><font style='font-size: .72rem;'>Assigned $($ParsedDate)</font></div>")
						}
					}
					$AssignedPlansBlock = "<div class='o365'>$($AssignedPlansFormatted -join '')</div>"
					if ($UserMailSettingsFormatted) {
						$UserMailSettingsBlock = Get-FormattedBlock -Heading 'Mailbox Settings' -Body ($UserMailSettingsFormatted -join '')
					} else {
						$UserMailSettingsBlock = $null
					}
					if ($UserMailboxDetailsFormatted) {
						$UserMailDetailsBlock = Get-FormattedBlock -Heading 'Mailbox Details' -Body ($UserMailboxDetailsFormatted -join '')
					} else {
						$UserMailDetailsBlock = $null
					}
					if ($UserGroups) {
						$UserGroupsBlock = Get-FormattedBlock -Heading 'User Groups' -Body $($UserGroups | ConvertTo-Html -Fragment -As Table | Out-String)
					} else {
						$UserGroupsBlock = $null
					}
					if ($UserPoliciesFormatted) {
						$UserPoliciesBlock = Get-FormattedBlock -Heading 'Assigned Conditional Access Policies' -Body $UserPoliciesFormatted
					} else {
						$UserPoliciesBlock = $null
					}
					if ($OneDriveFormatted) {
						$OneDriveBlock = Get-FormattedBlock -Heading 'One Drive Details' -Body ($OneDriveFormatted -join '')
					} else {
						$OneDriveBlock = $null
					}
					if ($UserOverviewFormatted) {
						$UserOverviewBlock = Get-FormattedBlock -Heading 'User Details' -Body $UserOverviewFormatted
					} else {
						$UserOverviewBlock = $null
					}
					if ($UserDevicesDetailsRaw) {
						$UserDevicesDetailsBlock = Get-FormattedBlock -Heading 'Intune Devices' -Body $($UserDevicesDetailsRaw | Select-Object -ExcludeProperty deviceName, url | ConvertTo-Html -Fragment | ForEach-Object { $tmp = $_ -replace '&lt;', '<'; $tmp -replace '&gt;', '>'; } | Out-String)
					} else {
						$UserDevicesDetailsBlock = $null
					}
					$HuduUser = $People | Where-Object { $_.primary_mail -eq $user.UserPrincipalName -or ($_.cards.integrator_name -eq 'cw_manage' -and $_.cards.data.communicationItems.communicationType -eq 'Email' -and $_.cards.data.communicationItems.value -eq $user.UserPrincipalName) }
					[System.Collections.Generic.List[PSCustomObject]]$CIPPLinksFormatted = @()
					if ($EnableCIPP) {
						$CIPPLinksFormatted.add((Get-LinkBlock -URL "$($CIPPURL).auth/login/aad?post_login_redirect_uri=$($CIPPURL)identity/administration/users/view?userId=$($User.id)%26tenantDomain%3D$($Customer.defaultDomainName)" -Icon 'far fa-eye' -Title 'CIPP - View User'))
						$CIPPLinksFormatted.add((Get-LinkBlock -URL "$($CIPPURL).auth/login/aad?post_login_redirect_uri=$($CIPPURL)identity/administration/users/edit?userId=$($User.id)%26tenantDomain%3D$($Customer.defaultDomainName)" -Icon 'fas fa-user-cog' -Title 'CIPP - Edit User'))
						$CIPPLinksFormatted.add((Get-LinkBlock -URL "$($CIPPURL).auth/login/aad?post_login_redirect_uri=$($CIPPURL)identity/administration/ViewBec?userId=$($User.id)%26tenantDomain%3D$($Customer.defaultDomainName)" -Icon 'fas fa-user-secret' -Title 'CIPP - Research Compromise'))
					}
					[System.Collections.Generic.List[PSCustomObject]]$UserLinksFormatted = @()
					$UserLinksFormatted.add((Get-LinkBlock -URL "https://aad.portal.azure.com/$($Customer.defaultDomainName)/#blade/Microsoft_AAD_IAM/UserDetailsMenuBlade/Profile/userId/$($User.id)" -Icon 'fas fa-users-cog' -Title 'Azure AD'))
					$UserLinksFormatted.add((Get-LinkBlock -URL "https://aad.portal.azure.com/$($Customer.defaultDomainName)/#blade/Microsoft_AAD_IAM/UserDetailsMenuBlade/SignIns/userId/$($User.id)" -Icon 'fas fa-history' -Title 'Sign Ins'))
					$UserLinksFormatted.add((Get-LinkBlock -URL "https://admin.teams.microsoft.com/users/$($User.id)/account?delegatedOrg=$($Customer.defaultDomainName)" -Icon 'fas fa-users' -Title 'Teams Admin'))
					$UserLinksFormatted.add((Get-LinkBlock -URL "https://endpoint.microsoft.com/$($Customer.defaultDomainName)/#blade/Microsoft_AAD_IAM/UserDetailsMenuBlade/Profile/userId/$($User.ID)" -Icon 'fas fa-laptop' -Title 'EPM (User)'))
					$UserLinksFormatted.add((Get-LinkBlock -URL "https://endpoint.microsoft.com/$($Customer.defaultDomainName)/#blade/Microsoft_AAD_IAM/UserDetailsMenuBlade/Devices/userId/$($User.ID)" -Icon 'fas fa-laptop' -Title 'EPM (Devices)'))
					$UserLinksBlock = "<div>Management Links</div><div class='o365'>$($UserLinksFormatted -join '')$($CIPPLinksFormatted -join '')</div>"
					$UserBody = "<div>$AssignedPlansBlock<br />$UserLinksBlock<br /><div class=`"nasa__content`">$($UserOverviewBlock)$($UserMailDetailsBlock)$($OneDriveBlock)$($UserMailSettingsBlock)$($UserPoliciesBlock)</div><div class=`"nasa__content`">$($UserDevicesDetailsBlock)</div><div class=`"nasa__content`">$($UserGroupsBlock)</div></div>"
					$UserAssetFields = @{
						microsoft_365            = $UserBody
						'IT Managed User'        = $true
						'Job Title'              = $($User.jobTitle)
						'Department'             = $($User.Department)
						'User Name'              = $($User.displayName)
						'Primary Email'          = $($User.mail)
						'Phone'                  = $($User.businessPhones -join ', ')
						'Mobile Phone'           = $($User.mobilePhone)
						'M365 AD Directory Sync' = $($User.OnPremisesSyncEnabled)
						'M365 License Summary'   = $($userLicenses)
						'M365 Account Enabled'   = $($User.accountEnabled)
						'M365 UserPrincipalName' = $($User.userPrincipalName)
						'M365 Email Aliases'     = $aliases
					}
					$HuduUserCount = ($HuduUser | Measure-Object).count
					if ($HuduUserCount -eq 1) {
						$null = Set-HuduAsset -asset_id $HuduUser.id -Name $HuduUser.name -company_id $company_id -asset_layout_id $PeopleLayout.id -Fields $UserAssetFields
					} elseif ($HuduUserCount -eq 0) {
						if ($CreateUsers -eq $True) {
							$HuduUser = (New-HuduAsset -Name $User.DisplayName -company_id $company_id -asset_layout_id $PeopleLayout.id -Fields $UserAssetFields -primary_mail $user.UserPrincipalName).asset
						}
					} else {
						$CompanyResult.Errors.add("User $($User.UserPrincipalName): Multiple Users Matched to email address in Hudu: ($($HuduUser.name -join ', ') - $($($HuduUser.id -join ', '))) $_")
					}
					$UserLink = "<a target=_blank href=$($HuduUser.url)>$($user.DisplayName)</a>"
					[PSCustomObject]@{
						'Display Name'      = $UserLink
						'Addresses'         = "<strong>$($user.UserPrincipalName)</strong><br/>$aliases"
						'EPM Devices'       = $userDevices
						'Assigned Licenses' = $userLicenses
						'Options'           = "<a target=`"_blank`" href=https://aad.portal.azure.com/$($Customer.DefaultDomainName)/#blade/Microsoft_AAD_IAM/UserDetailsMenuBlade/Profile/userId/$($user.id)>Azure AD</a> | <a <a target=`"_blank`" href=https://portal.office.com/Partner/BeginClientSession.aspx?CTID=$($customer.CustomerContextId)&CSDEST=o365admincenter/Adminportal/Home#/users/:/UserDetails/$($user.id)>M365 Admin</a>"
					}
				} catch {
					$CompanyResult.Errors.add("User $($User.UserPrincipalName): A fatal error occured while processing user $_")
				}
			}
			$licensedUserHTML = $OutputUsers | ConvertTo-Html -PreContent $pre -PostContent $post -Fragment | ForEach-Object { $tmp = $_ -replace '&lt;', '<'; $tmp -replace '&gt;', '>'; } | Out-String
		}
		foreach ($Device in $Devices) {
			try {
				[System.Collections.Generic.List[PSCustomObject]]$DeviceOverviewFormatted = @()
				$DeviceOverviewFormatted.add($(Get-FormatedField -Title 'Device Name' -Value "$($Device.deviceName)"))
				$DeviceOverviewFormatted.add($(Get-FormatedField -Title 'User' -Value "$($Device.userDisplayName)"))
				$DeviceOverviewFormatted.add($(Get-FormatedField -Title 'User Email' -Value "$($Device.userPrincipalName)"))
				$DeviceOverviewFormatted.add($(Get-FormatedField -Title 'Owner' -Value "$($Device.ownerType)"))
				$DeviceOverviewFormatted.add($(Get-FormatedField -Title 'Enrolled' -Value "$($Device.enrolledDateTime)"))
				$DeviceOverviewFormatted.add($(Get-FormatedField -Title 'Last Checkin' -Value "$($Device.lastSyncDateTime)"))
				if ($Device.complianceState -eq 'compliant') {
					$CompliantSymbol = '<font color=green><em class="fas fa-check-circle">&nbsp;&nbsp;&nbsp;</em></font>'
				} else {
					$CompliantSymbol = '<font color=red><em class="fas fa-times-circle">&nbsp;&nbsp;&nbsp;</em></font>'
				}
				$DeviceOverviewFormatted.add($(Get-FormatedField -Title 'Compliant' -Value "$($CompliantSymbol)$($Device.complianceState)"))
				$DeviceOverviewFormatted.add($(Get-FormatedField -Title 'Management Type' -Value "$($Device.managementAgent)"))
				[System.Collections.Generic.List[PSCustomObject]]$DeviceHardwareFormatted = @()
				$DeviceHardwareFormatted.add($(Get-FormatedField -Title 'Serial Number' -Value "$($Device.serialNumber)"))
				$DeviceHardwareFormatted.add($(Get-FormatedField -Title 'OS' -Value "$($Device.operatingSystem)"))
				$DeviceHardwareFormatted.add($(Get-FormatedField -Title 'OS Versions' -Value "$($Device.osVersion)"))
				$DeviceHardwareFormatted.add($(Get-FormatedField -Title 'Chassis' -Value "$($Device.chassisType)"))
				$DeviceHardwareFormatted.add($(Get-FormatedField -Title 'Model' -Value "$($Device.model)"))
				$DeviceHardwareFormatted.add($(Get-FormatedField -Title 'Manufacturer' -Value "$($Device.manufacturer)"))
				$DeviceHardwareFormatted.add($(Get-FormatedField -Title 'Total Storage' -Value "$([math]::Round($Device.totalStorageSpaceInBytes /1024 /1024 /1024, 2))"))
				$DeviceHardwareFormatted.add($(Get-FormatedField -Title 'Free Storage' -Value "$([math]::Round($Device.freeStorageSpaceInBytes /1024 /1024 /1024, 2))"))
				[System.Collections.Generic.List[PSCustomObject]]$DeviceEnrollmentFormatted = @()
				$DeviceEnrollmentFormatted.add($(Get-FormatedField -Title 'Enrollment Type' -Value "$($Device.deviceEnrollmentType)"))
				$DeviceEnrollmentFormatted.add($(Get-FormatedField -Title 'Join Type' -Value "$($Device.joinType)"))
				$DeviceEnrollmentFormatted.add($(Get-FormatedField -Title 'Registration State' -Value "$($Device.deviceRegistrationState)"))
				$DeviceEnrollmentFormatted.add($(Get-FormatedField -Title 'Autopilot Enrolled' -Value "$($Device.autopilotEnrolled)"))
				$DeviceEnrollmentFormatted.add($(Get-FormatedField -Title 'Device Guard Requirements' -Value "$($Device.hardwareinformation.deviceGuardVirtualizationBasedSecurityHardwareRequirementState)"))
				$DeviceEnrollmentFormatted.add($(Get-FormatedField -Title 'Virtualistation Based Security' -Value "$($Device.hardwareinformation.deviceGuardVirtualizationBasedSecurityState)"))
				$DeviceEnrollmentFormatted.add($(Get-FormatedField -Title 'Credential Guard' -Value "$($Device.hardwareinformation.deviceGuardLocalSystemAuthorityCredentialGuardState)"))
				$DevicePoliciesTable = foreach ($Policy in $DeviceComplianceDetails) {
					if ($device.deviceName -in $Policy.DeviceStatuses.deviceDisplayName) {
						$Status = $Policy.DeviceStatuses | Where-Object { $_.deviceDisplayName -eq $device.deviceName }
						if ($Status.status -ne 'unknown') {
							[PSCustomObject]@{
								Name           = $Policy.DisplayName
								Status         = ($Status.status | Select-Object -Unique) -join ', '
								'Last Report'  = "$(Get-Date($Status.lastReportedDateTime[0]) -Format 'yyyy-MM-dd HH:mm:ss')"
								'Grace Expiry' = "$(Get-Date($Status.complianceGracePeriodExpirationDateTime[0]) -Format 'yyyy-MM-dd HH:mm:ss')"
							}
						}
					}
				}
				$DevicePoliciesFormatted = $DevicePoliciesTable | ConvertTo-Html -Fragment | Out-String
				$DeviceGroupsTable = foreach ($Group in $Groups) {
					if ($device.azureADDeviceId -in $Group.members.deviceId) {
						[PSCustomObject]@{
							Name = $Group.displayName
						}
					}
				}
				$DeviceGroupsFormatted = $DeviceGroupsTable | ConvertTo-Html -Fragment | Out-String
				$DeviceAppsTable = foreach ($App in $DeviceAppInstallDetails) {
					if ($device.id -in $App.InstalledAppDetails.deviceId) {
						$Status = $App.InstalledAppDetails | Where-Object { $_.deviceId -eq $device.id }
						[PSCustomObject]@{
							Name             = $App.DisplayName
							'Install Status' = ($Status.installState | Select-Object -Unique ) -join ','
						}
					}
				}
				$DeviceAppsFormatted = $DeviceAppsTable | ConvertTo-Html -Fragment | Out-String
				$DeviceOverviewBlock = Get-FormattedBlock -Heading 'Device Details' -Body ($DeviceOverviewFormatted -join '')
				$DeviceHardwareBlock = Get-FormattedBlock -Heading 'Hardware Details' -Body ($DeviceHardwareFormatted -join '')
				$DeviceEnrollmentBlock = Get-FormattedBlock -Heading 'Device Enrollment Details' -Body ($DeviceEnrollmentFormatted -join '')
				$DevicePolicyBlock = Get-FormattedBlock -Heading 'Compliance Policies' -Body ($DevicePoliciesFormatted -join '')
				$DeviceAppsBlock = Get-FormattedBlock -Heading 'App Details' -Body ($DeviceAppsFormatted -join '')
				$DeviceGroupsBlock = Get-FormattedBlock -Heading 'Device Groups' -Body ($DeviceGroupsFormatted -join '')
				if ("$($device.serialNumber)" -in $ExcludeSerials) {
					$HuduDevice = $HuduDevices | Where-Object { $_.name -eq $device.deviceName -or ($_.cards.integrator_name -eq 'cw_manage' -and $_.cards.data.name -contains $device.deviceName) }
				} else {
					$HuduDevice = $HuduDevices | Where-Object { $_.primary_serial -eq $device.serialNumber -or ($_.cards.integrator_name -eq 'cw_manage' -and $_.cards.data.serialNumber -eq $device.serialNumber) }
				}
				[System.Collections.Generic.List[PSCustomObject]]$DeviceLinksFormatted = @()
				$DeviceLinksFormatted.add((Get-LinkBlock -URL "https://endpoint.microsoft.com/$($Customer.defaultDomainName)/#blade/Microsoft_Intune_Devices/DeviceSettingsBlade/overview/mdmDeviceId/$($Device.id)" -Icon 'fas fa-laptop' -Title 'Endpoint Manager'))
				$DeviceLinksBlock = "<div>Management Links</div><div class='o365'>$($DeviceLinksFormatted -join '')</div>"
				$DeviceIntuneDetailshtml = "<div><div>$DeviceLinksBlock<br /><div class=`"nasa__content`">$($DeviceOverviewBlock)$($DeviceHardwareBlock)$($DeviceEnrollmentBlock)$($DevicePolicyBlock)$($DeviceAppsBlock)$($DeviceGroupsBlock)</div></div>"
				$DeviceAssetFields = @{
					microsoft_365 = $DeviceIntuneDetailshtml
				}
				if ($HuduDevice) {
					if (($HuduDevice | Measure-Object).count -eq 1) {
						$null = Set-HuduAsset -asset_id $HuduDevice.id -Name $HuduDevice.name -company_id $company_id -asset_layout_id $HuduDevice.asset_layout_id -Fields $DeviceAssetFields -PrimarySerial $Device.serialNumber
						$HuduUser = $People | Where-Object { $_.primary_mail -eq $Device.userPrincipalName -or ($_.cards.integrator_name -eq 'cw_manage' -and $_.cards.data.communicationItems.communicationType -eq 'Email' -and $_.cards.data.communicationItems.value -eq $Device.userPrincipalName) }
						if ($HuduUser) {
							$Relation = $HuduRelations | Where-Object { $_.fromable_type -eq 'Asset' -and $_.fromable_id -eq $HuduUser.id -and $_.toable_type -eq 'Asset' -and $_toable_id -eq $HuduDevice.id }
							if (-not $Relation) {
								try {
									$null = New-HuduRelation -FromableType 'Asset' -FromableID $HuduUser.id -ToableType 'Asset' -ToableID $HuduDevice.id -ea stop
								} catch {}
							}
						}
					} else {
						$CompanyResult.Errors.add("Device $($HuduDevice.name): Multiple devices matched on name or serial ($($device.serialNumber -join ', '))")
					}
				} else {
					if ($device.deviceType -in $IntuneDesktopDeviceTypes) {
						$DeviceLayoutID = $DesktopsLayout.id
						$DeviceCreation = $CreateDevices
					} else {
						$DeviceLayoutID = $MobilesLayout.id
						$DeviceCreation = $CreateMobileDevices
					}
					if ($DeviceCreation -eq $true) {
						$HuduDevice = (New-HuduAsset -Name $device.deviceName -company_id $company_id -asset_layout_id $DeviceLayoutID -Fields $DeviceAssetFields -PrimarySerial $Device.serialNumber).asset
						$HuduUser = $People | Where-Object { $_.primary_mail -eq $Device.userPrincipalName -or ($_.cards.integrator_name -eq 'cw_manage' -and $_.cards.data.communicationItems.communicationType -eq 'Email' -and $_.cards.data.communicationItems.value -eq $Device.userPrincipalName) }
						if ($HuduUser) {
							try {
								$null = New-HuduRelation -FromableType 'Asset' -FromableID $HuduUser.id -ToableType 'Asset' -ToableID $HuduDevice.id -ea stop
							} catch {
								# No need to do anything here as its will be when relations already exist.
							}
						}
					}
				}
			} catch {
				$CompanyResult.Errors.add("Device $($device.deviceName): A Fatal Error occured while processing the device $_")
			}
		}
		$body = "<div class='nasa__block'>
		<header class='nasa__block-header'>
		<h1><i class='fas fa-cogs icon'></i>Administrative Portals</h1>
		</header>
		<div>$CustomerLinks</div>
		<br/>
		</div>
		<br/>
		<div class=`"nasa__content`">
		$detailstable
		$licenseHTML
		</div>
		<br/>
		<div class=`"nasa__content`">
		$RolesHtml
		</div>
		<br/>
		<div class=`"nasa__content`">
		$licensedUserHTML
		</div>"
		try {
			$null = Set-HuduMagicDash -Title "Microsoft 365 - $($customer.DisplayName)" -company_name $company_name -Message "Users: $($CompanyResult.Users), Devices: $($CompanyResult.devices)`r`nLastSync: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -Icon 'fab fa-microsoft' -Content $body -Shade 'success'
		} catch {
			$CompanyResult.Errors.add("Company: Failed to add Magic Dash to Company: $_")
		}
		if ($CreateInOverview -eq $true) {
			try {
				$null = Set-HuduMagicDash -Title "$($customer.DisplayName)" -company_name $OverviewCompany -Message "Users: $($CompanyResult.Users), Devices: $($CompanyResult.devices)`r`nLastSync: $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -Icon 'fab fa-microsoft' -Content $body -Shade 'success'
			} catch {
				$CompanyResult.Errors.add("Company: Failed to add Magic Dash to Overview: $_")
			}
		}
		try {
			if ($importDomains) {
				$domainstoimport = $RawDomains
				foreach ($imp in $domainstoimport) {
					$impdomain = $imp.id
					$huduimpdomain = Get-HuduWebsites -Name "https://$impdomain"
					if ($($huduimpdomain.id.count) -eq 0) {
						if ($monitorDomains) {
							$null = New-HuduWebsite -Name "https://$impdomain" -Notes $HuduNotes -Paused 'false' -CompanyId $company_id -DisableDNS 'false' -DisableSSL 'false' -DisableWhois 'false'
						} else {
							$null = New-HuduWebsite -Name "https://$impdomain" -Notes $HuduNotes -Paused 'true' -CompanyId $company_id -DisableDNS 'true' -DisableSSL 'true' -DisableWhois 'true'
						}
					}
				}
			}
		} catch {
			$CompanyResult.Errors.add("Company: Failed to import domain: $_")
		}
	} elseif ($domaincount -eq 0) {
		$CompanyResult.Errors.add("Company: Domain not found in Hudu please add $defaultdomain to a company")
	} else {
		$CompanyResult.Errors.add("Company: Multiple companies matched in Hudu for $defaultdomain")
	}
} catch {
	$CompanyResult.Errors.add("Company: A fatal error occured: $_")
}
return $CompanyResult
