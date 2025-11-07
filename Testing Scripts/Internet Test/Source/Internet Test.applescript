-- By: Pico Mitchell
-- For: MacLand @ Free Geek
--
-- MIT License
--
-- Copyright (c) 2021 Free Geek
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
-- WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
--

-- Version: 2025.10.23-1

-- App Icon is “Satellite Antenna” from Twemoji (https://github.com/twitter/twemoji) by Twitter (https://twitter.com)
-- Licensed under CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/)

use AppleScript version "2.7"
use scripting additions

repeat -- dialogs timeout when screen is asleep or locked (just in case)
	set isAwake to true
	try
		set isAwake to ((run script "ObjC.import('CoreGraphics'); $.CGDisplayIsActive($.CGMainDisplayID())" in "JavaScript") is equal to 1)
	end try
	
	set isUnlocked to true
	try
		set isUnlocked to ((do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :IOConsoleUsers:0:CGSSessionScreenIsLocked' /dev/stdin <<< \"$(ioreg -ac IORegistryEntry -k IOConsoleUsers -d 1)\""))) is not equal to "true")
	end try
	
	if (isAwake and isUnlocked) then
		exit repeat
	else
		delay 1
	end if
end repeat

try
	set infoPlistPath to ((POSIX path of (path to me)) & "Contents/Info.plist")
	((infoPlistPath as POSIX file) as alias)
	
	set intendedAppName to "Internet Test" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
	try
		do shell script ("/usr/libexec/PlistBuddy -c 'Print :FGBuiltByMacLandScriptBuilder' " & (quoted form of infoPlistPath))
		((((POSIX path of (path to me)) & "Contents/MacOS/" & intendedAppName) as POSIX file) as alias)
	on error
		try
			activate
		end try
		display alert "
“" & (name of me) & "” must be built by the “MacLand Script Builder” script." buttons {"Quit"} default button 1 as critical
		quit
		delay 10
	end try
	
	set AppleScript's text item delimiters to "-"
	set intendedBundleIdentifier to ("org.freegeek." & ((words of intendedAppName) as text))
	set currentBundleIdentifier to ((do shell script ("/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' " & (quoted form of infoPlistPath))) as text)
	if (currentBundleIdentifier is not equal to intendedBundleIdentifier) then error "“" & (name of me) & "” does not have the correct Bundle Identifier.


Current Bundle Identifier:
	" & currentBundleIdentifier & "

Intended Bundle Identifier:
	" & intendedBundleIdentifier
on error checkInfoPlistError
	if (checkInfoPlistError does not start with "Can’t make file") then
		try
			activate
		end try
		display alert checkInfoPlistError buttons {"Quit"} default button 1 as critical
		quit
		delay 10
	end if
end try

try
	set mainScptPath to ((POSIX path of (path to me)) & "Contents/Resources/Scripts/main.scpt")
	((mainScptPath as POSIX file) as alias)
	do shell script "osadecompile " & (quoted form of mainScptPath)
	error "
“" & (name of me) & "” must be exported as a Run-Only Script."
on error checkReadOnlyErrorMessage
	if ((checkReadOnlyErrorMessage does not contain "errOSASourceNotAvailable") and (checkReadOnlyErrorMessage does not start with "Can’t make file")) then
		activate
		display alert checkReadOnlyErrorMessage buttons {"Quit"} default button 1 as critical
		quit
		delay 10
	end if
end try


set freeGeekUpdaterAppPath to "/Applications/Free Geek Updater.app"
set freeGeekUpdaterIsRunning to false
try
	((freeGeekUpdaterAppPath as POSIX file) as alias)
	set freeGeekUpdaterIsRunning to (application freeGeekUpdaterAppPath is running)
end try

global adminUsername, adminPassword, lastDoShellScriptAsAdminAuthDate -- Needs to be accessible in doShellScriptAsAdmin function.
set lastDoShellScriptAsAdminAuthDate to 0

set adminUsername to "Staff"
set adminPassword to "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]"

set buildInfoPath to ((POSIX path of (path to shared documents folder)) & "Build Info/")

try
	(((buildInfoPath & ".fgSetupSkipped") as POSIX file) as alias)
	
	try
		do shell script ("mkdir " & (quoted form of buildInfoPath))
	end try
	try
		set AppleScript's text item delimiters to "-"
		doShellScriptAsAdmin("touch " & (quoted form of (buildInfoPath & ".fgLaunchAfterSetup-org.freegeek." & ((words of (name of me)) as text))))
	end try
	
	if (not freeGeekUpdaterIsRunning) then
		try
			-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited so this will not actually ever open a new instance.
			do shell script "open -na '/Applications/Test Boot Setup.app'"
		end try
	end if
	
	quit
	delay 10
end try

if (freeGeekUpdaterIsRunning) then -- Quit if Updater is running so that this app can be updated if needed.
	quit
	delay 10
end if


set systemVersion to (system version of (system info))
considering numeric strings
	set isCatalinaOrNewer to (systemVersion ≥ "10.15")
	set isBigSurOrNewer to (systemVersion ≥ "11.0")
	set isVenturaOrNewer to (systemVersion ≥ "13.0")
	set isSequoiaFifteenDotSixOrNewer to (systemVersion ≥ "15.6")
end considering

set tabOrNulAndTab to tab
if (isVenturaOrNewer) then
	-- On macOS 13 Ventura and newer with the "extended" alert style AND on macOS 26 Tahoe where alerts text will be left aligned,
	-- the system still trim leading spaces like the centered text alerts of macOS 11 Big Sur.
	-- So, need to work around this trimming behaviro by using NUL+TAB instead of just TAB so that the line will no longer
	-- start with whitespace (since it will start with a NUL char instead) and therefore will NOT be trimmed.
	
	set tabOrNulAndTab to ((ASCII character 0) & tab)
end if

repeat
	set progress total steps to -1
	set progress description to "
🔄	Checking for Ethernet Connection"
	set progress additional description to ""
	
	set isLaptop to false
	set manufacturedWithoutEthernetPort to false
	try
		set shortModelName to "Unknown Model"
		try
			set shortModelName to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :0:_items:0:machine_name' /dev/stdin <<< \"$(system_profiler -xml SPHardwareDataType)\"")))
		end try
		if ((words of shortModelName) contains "MacBook") then set isLaptop to true
		set modelIdentifier to (do shell script "sysctl -n hw.model")
		set modelIdentifierName to (do shell script "echo " & (quoted form of modelIdentifier) & " | tr -d '[:digit:],'")
		set modelIdentifierMajorNumber to ((text ((length of modelIdentifierName) + 1) thru ((offset of "," in modelIdentifier) - 1) of modelIdentifier) as number)
		set manufacturedWithoutEthernetPort to ((modelIdentifierName is equal to "MacBookAir") or ((modelIdentifierName is equal to "MacBookPro") and (modelIdentifierMajorNumber ≥ 10)) or ((modelIdentifierName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 8)))
	on error (checkHasEthernetError) number (checkHasEthernetErrorNumber)
		if (checkHasEthernetErrorNumber is equal to -128) then quit
	end try
	
	set wiFiNetworkDeviceIDs to {}
	set ethernetNetworkDeviceIDs to {}
	
	try
		set allNetworkInterfaces to (do shell script "networksetup -listallhardwareports")
		
		set AppleScript's text item delimiters to ": "
		repeat with thisNetworkInterfaceLine in (paragraphs of allNetworkInterfaces)
			if (thisNetworkInterfaceLine starts with "Hardware Port:") then
				set thisNetworkDeviceName to ((last text item of thisNetworkInterfaceLine) as text)
			else if (thisNetworkInterfaceLine starts with "Device:") then
				set thisNetworkDeviceID to ((last text item of thisNetworkInterfaceLine) as text)
				if (thisNetworkDeviceName contains "Wi-Fi") then
					set (end of wiFiNetworkDeviceIDs) to thisNetworkDeviceID
				else if ((thisNetworkDeviceName contains "Ethernet") or (thisNetworkDeviceName contains " LAN")) then
					set (end of ethernetNetworkDeviceIDs) to thisNetworkDeviceID
				end if
			end if
		end repeat
	on error (checkHardwarePortsError) number (checkHardwarePortsErrorNumber)
		if (checkHardwarePortsErrorNumber is equal to -128) then quit
	end try
	
	set hasEthernetPort to ((count of ethernetNetworkDeviceIDs) > 0)
	set ethernetCableConnected to false
	set connectedToAppleViaEthernet to false
	set connectedToGoogleViaEthernet to false
	set ethernetTestPassed to false
	set ethernetTestSkipped to false
	
	set hasWiFiCard to ((count of wiFiNetworkDeviceIDs) > 0)
	set wiFiIsOff to true
	set connectedWiFiNetworkName to ""
	set connectedToAppleViaWiFi to false
	set connectedToGoogleViaWiFi to false
	set wiFiTestPassed to false
	set wiFiTestSkipped to false
	
	repeat
		if (hasEthernetPort and (not ethernetTestPassed) and (not ethernetTestSkipped)) then
			set progress description to "
🔄	Checking for Ethernet Connection"
			repeat
				repeat
					repeat with thisEthernetNetworkDeviceID in ethernetNetworkDeviceIDs
						try
							if ((do shell script "ipconfig getifaddr " & thisEthernetNetworkDeviceID) is not equal to "") then
								set ethernetCableConnected to true
								exit repeat
							end if
						end try
					end repeat
					
					if (ethernetCableConnected or (hasWiFiCard and (not wiFiTestPassed) and (not wiFiTestSkipped))) then -- Do Wi-Fi test first if Ethernet is not connected
						exit repeat
					else
						try
							set noEthernetCableDetectedAlertTitle to "🚫	No Ethernet Cable Detected"
							set noEthernetCableDetectedAlertMessage to "🔌	PLUG IN an Ethernet cable and then click \"Test Ethernet Again\".

‼️	If an Ethernet cable is plugged in and is not detected after multiple
" & tabOrNulAndTab & "attempts, click \"Skip Ethernet Test\" and CONSULT AN INSTRUCTOR."
							
							set noEthernetCableDetectedAlertButtons to {"Open Test Sites in Safari", "Skip Ethernet Test", "Test Ethernet Again"}
							
							try
								activate
							end try
							if (isBigSurOrNewer and (not isVenturaOrNewer)) then
								-- On macOS 11 Big Sur and macOS 12 Monterey, alerts will only ever be a "compact" layout with a narrow window and centered text (and long text could need to be scrolled).
								-- That style looks very bad for long detailed messages, so "display dialog" will be used instead of "display alert" on those versions of macOS.
								
								display dialog (noEthernetCableDetectedAlertTitle & linefeed & linefeed & linefeed & noEthernetCableDetectedAlertMessage) buttons noEthernetCableDetectedAlertButtons cancel button 2 default button 3 with title (name of me) with icon caution giving up after 30
							else
								display alert (noEthernetCableDetectedAlertTitle & linefeed) message noEthernetCableDetectedAlertMessage buttons noEthernetCableDetectedAlertButtons cancel button 2 default button 3 as critical giving up after 30
							end if
							
							if ((button returned of result) is equal to "Open Test Sites in Safari") then openTestSitesInSafari()
							delay 2
						on error
							set ethernetTestSkipped to true
							exit repeat
						end try
					end if
				end repeat
				
				if (not ethernetCableConnected) then exit repeat
				
				set progress description to "
📡	Testing Internet via Ethernet"
				
				repeat with thisEthernetNetworkDeviceID in ethernetNetworkDeviceIDs
					repeat 5 times
						try
							set connectedToAppleViaEthernet to ((do shell script "ping -b " & thisEthernetNetworkDeviceID & " -t 2 -c 1 www.apple.com") contains "1 packets transmitted, 1 ")
						end try
						try
							set connectedToGoogleViaEthernet to ((do shell script "ping -b " & thisEthernetNetworkDeviceID & " -t 2 -c 1 www.google.com") contains "1 packets transmitted, 1 ")
						end try
						
						if (connectedToAppleViaEthernet or connectedToGoogleViaEthernet) then
							set ethernetTestPassed to true
							exit repeat
						else
							delay 1
						end if
					end repeat
					
					if (ethernetTestPassed) then exit repeat
				end repeat
				
				if (ethernetTestPassed) then
					exit repeat
				else
					try
						set failedEthernetTestAlertTitle to "❌	Failed to Connect to the Internet via Ethernet"
						set failedEthernetTestAlertMessage to "🔒	Make sure the Ethernet cable is SECURELY CONNECTED or connect
" & tabOrNulAndTab & "a DIFFERENT Ethernet cable and then click \"Test Ethernet Again\".

‼️	If the Ethernet cable is securely connected and this test fails after multiple
" & tabOrNulAndTab & "attempts, click \"Skip Ethernet Test\" and CONSULT AN INSTRUCTOR."
						
						set failedEthernetTestAlertButtons to {"Open Test Sites in Safari", "Skip Ethernet Test", "Test Ethernet Again"}
						
						try
							activate
						end try
						if (isBigSurOrNewer and (not isVenturaOrNewer)) then
							-- On macOS 11 Big Sur and macOS 12 Monterey, alerts will only ever be a "compact" layout with a narrow window and centered text (and long text could need to be scrolled).
							-- That style looks very bad for long detailed messages, so "display dialog" will be used instead of "display alert" on those versions of macOS.
							
							display dialog (failedEthernetTestAlertTitle & linefeed & linefeed & linefeed & failedEthernetTestAlertMessage) buttons failedEthernetTestAlertButtons cancel button 2 default button 3 with title (name of me) with icon caution giving up after 30
						else
							display alert (failedEthernetTestAlertTitle & linefeed) message failedEthernetTestAlertMessage buttons failedEthernetTestAlertButtons cancel button 2 default button 3 as critical giving up after 30
						end if
						
						if ((button returned of result) is equal to "Open Test Sites in Safari") then openTestSitesInSafari()
						delay 2
					on error
						set ethernetTestSkipped to true
						exit repeat
					end try
				end if
				
			end repeat
		end if
		
		if (hasWiFiCard and (not wiFiTestPassed) and (not wiFiTestSkipped)) then
			set progress description to "
📡	Testing Internet via Wi-Fi"
			
			repeat
				repeat
					repeat with thisWiFiNetworkDeviceID in wiFiNetworkDeviceIDs
						try
							set wiFiIsOff to ((do shell script "networksetup -getairportpower " & (quoted form of thisWiFiNetworkDeviceID)) ends with "): Off")
						end try
						
						if (wiFiIsOff) then
							try
								do shell script "networksetup -setairportpower " & (quoted form of thisWiFiNetworkDeviceID) & " on"
								set wiFiIsOff to ((do shell script "networksetup -getairportpower " & (quoted form of thisWiFiNetworkDeviceID)) ends with "): Off")
							end try
						end if
						
						if (not wiFiIsOff) then exit repeat
					end repeat
					
					if (wiFiIsOff) then
						try
							set failedToEnableWiFiAlertTitle to "🚫	Failed to Enable Wi-Fi"
							set failedToEnableWiFiAlertMessage to "☝️	Manually TURN ON Wi-Fi and then click \"Test Wi-Fi Again\".

👉	If Wi-Fi is turned on, DISCONNECT the Ethernet cable
" & tabOrNulAndTab & "and then click \"Test Wi-Fi Again\".

‼️	If Wi-Fi is turned on and the Ethernet cable is
" & tabOrNulAndTab & "disconnected and this test fails after multiple attempts,
" & tabOrNulAndTab & "click \"Skip Wi-Fi Test\" and CONSULT AN INSTRUCTOR."
							
							set failedToEnableWiFiAlertButtons to {"Open Test Sites in Safari", "Skip Wi-Fi Test", "Test Wi-Fi Again"}
							
							try
								activate
							end try
							if (isBigSurOrNewer and (not isVenturaOrNewer)) then
								-- On macOS 11 Big Sur and macOS 12 Monterey, alerts will only ever be a "compact" layout with a narrow window and centered text (and long text could need to be scrolled).
								-- That style looks very bad for long detailed messages, so "display dialog" will be used instead of "display alert" on those versions of macOS.
								
								display dialog (failedToEnableWiFiAlertTitle & linefeed & linefeed & linefeed & failedToEnableWiFiAlertMessage) buttons failedToEnableWiFiAlertButtons cancel button 2 default button 3 with title (name of me) with icon caution giving up after 30
							else
								display alert (failedToEnableWiFiAlertTitle & linefeed) message failedToEnableWiFiAlertMessage buttons failedToEnableWiFiAlertButtons cancel button 2 default button 3 as critical giving up after 30
							end if
							
							if (button returned of result is equal to "Open Test Sites in Safari") then openTestSitesInSafari()
							delay 2
						on error
							set wiFiTestSkipped to true
							exit repeat
						end try
					else
						exit repeat
					end if
				end repeat
				
				if (wiFiIsOff) then exit repeat
				
				set connectedWiFiNetworkName to ""
				
				repeat with thisWiFiNetworkDeviceID in wiFiNetworkDeviceIDs
					try
						set getWiFiNetworkOutput to (do shell script "networksetup -getairportnetwork " & (quoted form of thisWiFiNetworkDeviceID))
						set getWiFiNetworkColonOffset to (offset of ":" in getWiFiNetworkOutput)
						if (getWiFiNetworkColonOffset > 0) then
							set connectedWiFiNetworkName to (text (getWiFiNetworkColonOffset + 2) thru -1 of getWiFiNetworkOutput)
							exit repeat
						else if (getWiFiNetworkOutput is equal to "You are not associated with an AirPort network.") then
							-- Starting on macOS 15, "networksetup -getairportnetwork" will always output "You are not associated with an AirPort network." even when connected to a Wi-Fi network.
							-- So, fallback to using "ipconfig getsummary" instead.
							
							if (isSequoiaFifteenDotSixOrNewer) then
								-- Starting with macOS 15.6, the Wi-Fi name on the "SSID" line of "ipconfig getsummary" will be "<redacted>" unless "ipconfig setverbose 1" is set, which must be run as root.
								-- Apple support shared that "ipconfig setverbose 1" un-redacts the "ipconfig getsummary" output with a member of MacAdmins Slack who shared it there: https://macadmins.slack.com/archives/GA92U9YV9/p1757621890952369?thread_ts=1750227817.961659&cid=GA92U9YV9
								
								try
									tell me to doShellScriptAsAdmin("ipconfig setverbose 1")
								end try
							end if
							
							try
								set connectedWiFiNetworkName to (do shell script "ipconfig getsummary " & (quoted form of thisWiFiNetworkDeviceID) & " | awk -F ' SSID : ' '/ SSID : / { print $2; exit }'")
								if ((connectedWiFiNetworkName is not equal to "") and (connectedWiFiNetworkName is not equal to "<redacted>")) then -- Should never be "<redacted>", but still check just in case.
									exit repeat
								end if
							end try
							
							if (isSequoiaFifteenDotSixOrNewer) then
								-- Running "ipconfig setverbose 1" is a persistent system wide setting, so must manually disable it (which also requires running as root/sudo).
								
								try
									tell me to doShellScriptAsAdmin("ipconfig setverbose 0")
								end try
							end if
						end if
					end try
				end repeat
				
				if (connectedWiFiNetworkName is equal to "") then
					repeat with thisWiFiNetworkDeviceID in wiFiNetworkDeviceIDs
						try
							-- This needs admin privileges to add network to preferred network if it's not already preferred (it will pop up a gui prompt in this case if not run with admin).
							doShellScriptAsAdmin("networksetup -setairportnetwork " & (quoted form of thisWiFiNetworkDeviceID) & " 'FG Staff' " & (quoted form of "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD]"))
							exit repeat
						end try
					end repeat
					
					set AppleScript's text item delimiters to ": "
					repeat with thisWiFiNetworkDeviceID in wiFiNetworkDeviceIDs
						try
							set getWiFiNetworkOutput to (do shell script "networksetup -getairportnetwork " & (quoted form of thisWiFiNetworkDeviceID))
							set getWiFiNetworkColonOffset to (offset of ":" in getWiFiNetworkOutput)
							if (getWiFiNetworkColonOffset > 0) then
								set connectedWiFiNetworkName to (text (getWiFiNetworkColonOffset + 2) thru -1 of getWiFiNetworkOutput)
								exit repeat
							else if (getWiFiNetworkOutput is equal to "You are not associated with an AirPort network.") then
								-- Starting on macOS 15, "networksetup -getairportnetwork" will always output "You are not associated with an AirPort network." even when connected to a Wi-Fi network.
								-- So, fallback to using "ipconfig getsummary" instead.
								
								if (isSequoiaFifteenDotSixOrNewer) then
									-- Starting with macOS 15.6, the Wi-Fi name on the "SSID" line of "ipconfig getsummary" will be "<redacted>" unless "ipconfig setverbose 1" is set, which must be run as root.
									-- Apple support shared that "ipconfig setverbose 1" un-redacts the "ipconfig getsummary" output with a member of MacAdmins Slack who shared it there: https://macadmins.slack.com/archives/GA92U9YV9/p1757621890952369?thread_ts=1750227817.961659&cid=GA92U9YV9
									
									try
										tell me to doShellScriptAsAdmin("ipconfig setverbose 1")
									end try
								end if
								
								try
									set connectedWiFiNetworkName to (do shell script "ipconfig getsummary " & (quoted form of thisWiFiNetworkDeviceID) & " | awk -F ' SSID : ' '/ SSID : / { print $2; exit }'")
									if ((connectedWiFiNetworkName is not equal to "") and (connectedWiFiNetworkName is not equal to "<redacted>")) then -- Should never be "<redacted>", but still check just in case.
										exit repeat
									end if
								end try
								
								if (isSequoiaFifteenDotSixOrNewer) then
									-- Running "ipconfig setverbose 1" is a persistent system wide setting, so must manually disable it (which also requires running as root/sudo).
									
									try
										tell me to doShellScriptAsAdmin("ipconfig setverbose 0")
									end try
								end if
							end if
						end try
					end repeat
					
					if (connectedWiFiNetworkName is not equal to "") then
						set gotWiFiIP to true
						repeat 5 times
							repeat with thisWiFiNetworkDeviceID in wiFiNetworkDeviceIDs
								try
									if ((do shell script "ipconfig getifaddr " & (quoted form of thisWiFiNetworkDeviceID)) is equal to "") then
										delay 2 -- Wait for Wi-Fi to connect
									else
										set gotWiFiIP to true
										exit repeat
									end if
								end try
							end repeat
							
							if (gotWiFiIP) then exit repeat
						end repeat
					end if
				end if
				
				if (connectedWiFiNetworkName is not equal to "") then
					repeat 5 times
						repeat with thisWiFiNetworkDeviceID in wiFiNetworkDeviceIDs
							try
								set connectedToAppleViaWiFi to ((do shell script "ping -b " & (quoted form of thisWiFiNetworkDeviceID) & " -t 2 -c 1 www.apple.com") contains "1 packets transmitted, 1 ")
							end try
							try
								set connectedToGoogleViaWiFi to ((do shell script "ping -b " & (quoted form of thisWiFiNetworkDeviceID) & " -t 2 -c 1 www.google.com") contains "1 packets transmitted, 1 ")
							end try
							if (connectedToAppleViaWiFi or connectedToGoogleViaWiFi) then
								set wiFiTestPassed to true
								exit repeat
							else
								delay 1
							end if
						end repeat
						
						if (wiFiTestPassed) then exit repeat
					end repeat
				end if
				
				if (wiFiTestPassed) then
					exit repeat
				else
					try
						set wiFiTestFailedAlertTitle to "❌	Failed to Connect to the Internet via Wi-Fi"
						
						set differentOrNothing to ""
						if (connectedWiFiNetworkName is not equal to "") then set differentOrNothing to " DIFFERENT"
						set wiFiTestFailedAlertMessage to "☝️	MANUALLY CONNECT to a" & differentOrNothing & " Wi-Fi network
" & tabOrNulAndTab & "and then click \"Test Wi-Fi Again\".

‼️	If this computer is connected to a known good Wi-Fi
" & tabOrNulAndTab & "network and this test fails after multiple attempts,
" & tabOrNulAndTab & "click \"Skip Wi-Fi Test\" and CONSULT AN INSTRUCTOR."
						
						set wiFiTestFailedAlertButtons to {"Open Test Sites in Safari", "Skip Wi-Fi Test", "Test Wi-Fi Again"}
						
						try
							activate
						end try
						if (isBigSurOrNewer and (not isVenturaOrNewer)) then
							-- On macOS 11 Big Sur and macOS 12 Monterey, alerts will only ever be a "compact" layout with a narrow window and centered text (and long text could need to be scrolled).
							-- That style looks very bad for long detailed messages, so "display dialog" will be used instead of "display alert" on those versions of macOS.
							
							display dialog (wiFiTestFailedAlertTitle & linefeed & linefeed & linefeed & wiFiTestFailedAlertMessage) buttons wiFiTestFailedAlertButtons cancel button 2 default button 3 with title (name of me) with icon caution giving up after 30
						else
							display alert (wiFiTestFailedAlertTitle & linefeed) message wiFiTestFailedAlertMessage buttons wiFiTestFailedAlertButtons cancel button 2 default button 3 as critical giving up after 30
						end if
						
						if ((button returned of result) is equal to "Open Test Sites in Safari") then openTestSitesInSafari()
						delay 2
					on error
						set wiFiTestSkipped to true
						exit repeat
					end try
				end if
			end repeat
		end if
		
		if (((not hasWiFiCard) or wiFiTestPassed or wiFiTestSkipped) and ((not hasEthernetPort) or ethernetTestPassed or ethernetTestSkipped)) then
			exit repeat
		else
			delay 2
		end if
	end repeat
	
	
	set resultsTitle to ""
	set resultsOutput to ""
	
	if (hasWiFiCard) then
		if (wiFiTestPassed) then
			set resultsTitle to "✅	Wi-Fi Test Passed

"
		else
			set resultsTitle to "❌	Wi-Fi Test Failed

"
		end if
	end if
	
	if (hasEthernetPort) then
		if (ethernetTestPassed) then
			set resultsTitle to resultsTitle & "✅	Ethernet Test Passed"
		else
			set resultsTitle to resultsTitle & "❌	Ethernet Test Failed"
		end if
	else
		if (manufacturedWithoutEthernetPort) then
			set resultsTitle to resultsTitle & "✅	Manufactured Without Ethernet Port"
		else
			set resultsTitle to resultsTitle & "‼️	No Ethernet Port Detected"
		end if
	end if
	
	if (not hasWiFiCard) then set resultsTitle to resultsTitle & "

‼️	No Wi-Fi Card Detected"
	
	
	if (hasWiFiCard) then
		if (wiFiTestPassed) then
			set resultsOutput to "WI-FI TEST RESULTS: ✅ PASSED"
		else
			set resultsOutput to "WI-FI TEST RESULTS: ❌ FAILED"
		end if
		
		if (wiFiIsOff) then
			set resultsOutput to resultsOutput & "

🚫	Wi-Fi Not Enabled

‼️	TURN ON WI-FI AND TRY AGAIN"
		else
			if (wiFiTestPassed) then
				if (connectedToAppleViaWiFi and connectedToGoogleViaWiFi) then
					set resultsOutput to resultsOutput & "

👍	Successfully Connected to Apple.com
" & tabOrNulAndTab & "and Google.com via Wi-Fi"
				else
					if (connectedToAppleViaWiFi) then
						set resultsOutput to resultsOutput & "

👍	Successfully Connected to Apple.com via Wi-Fi"
					else
						set resultsOutput to resultsOutput & "

👍	Successfully Connected to Google.com via Wi-Fi"
					end if
				end if
			else
				set resultsOutput to resultsOutput & "

👎	Failed to Connect to Both Apple.com
" & tabOrNulAndTab & "and Google.com via Wi-Fi"
			end if
			
			if (connectedWiFiNetworkName is equal to "") then
				set resultsOutput to resultsOutput & "

🚫	Failed to Connect to a Wi-Fi Network

‼️	MANUALLY CONNECT TO A WI-FI
" & tabOrNulAndTab & "NETWORK AND TRY AGAIN"
			else
				set resultsOutput to resultsOutput & "

⚡️	Connected to Wi-Fi Network: " & connectedWiFiNetworkName
			end if
			
			if ((not wiFiTestPassed) and (connectedWiFiNetworkName is not equal to "")) then
				set resultsOutput to resultsOutput & "

‼️	MANUALLY CONNECT TO A DIFFERENT
" & tabOrNulAndTab & "WI-FI NETWORK AND TRY AGAIN"
			end if
		end if
		
		if ((count of wiFiNetworkDeviceIDs) > 1) then
			set resultsOutput to resultsOutput & "

‼️	MULTIPLE WI-FI CARDS DETECTED
" & tabOrNulAndTab & "ONLY ONE WI-FI CARD HAS BEEN TESTED"
		end if
	end if
	
	if (hasEthernetPort) then
		if (hasWiFiCard) then set resultsOutput to resultsOutput & "


"
		
		if (ethernetTestPassed) then
			set resultsOutput to resultsOutput & "ETHERNET TEST RESULTS: ✅ PASSED"
		else
			set resultsOutput to resultsOutput & "ETHERNET TEST RESULTS: ❌ FAILED"
		end if
		
		if (ethernetTestPassed) then
			if (connectedToAppleViaEthernet and connectedToGoogleViaEthernet) then
				set resultsOutput to resultsOutput & "

👍	Successfully Connected to Apple.com
" & tabOrNulAndTab & "and Google.com via Ethernet"
			else
				if (connectedToAppleViaEthernet) then
					set resultsOutput to resultsOutput & "

👍	Successfully Connected to Apple.com via Ethernet"
				else
					set resultsOutput to resultsOutput & "

👍	Successfully Connected to Google.com via Ethernet"
				end if
			end if
		else if (ethernetCableConnected) then
			set resultsOutput to resultsOutput & "

👎	Failed to Connect to Both Apple.com
" & tabOrNulAndTab & "and Google.com via Ethernet"
		else
			set resultsOutput to resultsOutput & "

🚫	No Ethernet Cable Detected

‼️	PLUG IN AN ETHERNET CABLE
" & tabOrNulAndTab & "AND TRY AGAIN"
		end if
		
		if ((count of ethernetNetworkDeviceIDs) > 1) then
			set resultsOutput to resultsOutput & "

‼️	MULTIPLE ETHERNET PORTS DETECTED

‼️	TEST EACH ETHERNET PORT BY RUNNING
" & tabOrNulAndTab & "THIS TEST MULTIPLE TIMES WITH ONLY
" & tabOrNulAndTab & "ONE CABLE PLUGGED IN"
		end if
	else if (not manufacturedWithoutEthernetPort) then
		if (hasWiFiCard) then set resultsOutput to resultsOutput & "


"
		set resultsOutput to resultsOutput & "‼️	NO ETHERNET PORT DETECTED"
	end if
	
	if (not hasWiFiCard) then
		if (hasEthernetPort or (not manufacturedWithoutEthernetPort)) then set resultsOutput to resultsOutput & "


"
		set resultsOutput to resultsOutput & "‼️	NO WI-FI CARD DETECTED

‼️	IF THIS COMPUTER SHOULD HAVE WI-FI
" & tabOrNulAndTab & "MAKE SURE WI-FI IS TURNED ON
" & tabOrNulAndTab & "AND TRY AGAIN"
	end if
	
	if ((hasWiFiCard and (connectedWiFiNetworkName is not equal to "") and (not wiFiTestPassed)) or (hasEthernetPort and ethernetCableConnected and (not ethernetTestPassed))) then
		set resultsOutput to resultsOutput & "


‼️	CONSULT AN INSTRUCTOR
" & tabOrNulAndTab & "SINCE INTERNET TEST FAILED"
	end if
	
	set didPassInternetTest to (wiFiTestPassed and (ethernetTestPassed or (manufacturedWithoutEthernetPort and (not hasEthernetPort))))
	if (((isLaptop or manufacturedWithoutEthernetPort) and (not hasWiFiCard)) or ((not manufacturedWithoutEthernetPort) and (not hasEthernetPort))) then set didPassInternetTest to false
	
	set progress description to "
📡	Finished Testing Internet"
	
	try
		activate
	end try
	
	set resultsButtons to {"Test Internet Again", "Done"}
	
	if didPassInternetTest then
		if ((count of ethernetNetworkDeviceIDs) > 1) then
			try
				if (isBigSurOrNewer and (not isVenturaOrNewer)) then
					-- On macOS 11 Big Sur and macOS 12 Monterey, alerts will only ever be a "compact" layout with a narrow window and centered text (and long text could need to be scrolled).
					-- That style looks very bad for long detailed messages, so "display dialog" will be used instead of "display alert" on those versions of macOS.
					
					display dialog (resultsTitle & linefeed & linefeed & linefeed & resultsOutput) buttons resultsButtons cancel button 1 default button 2 with title (name of me) with icon note
				else
					display alert (resultsTitle & linefeed) message resultsOutput buttons resultsButtons cancel button 1 default button 2
				end if
				
				exit repeat
			end try
		else
			set progress total steps to 1
			set progress completed steps to 1
			
			set resultsButtons to {"Done"}
			if (isBigSurOrNewer and (not isVenturaOrNewer)) then
				-- On macOS 11 Big Sur and macOS 12 Monterey, alerts will only ever be a "compact" layout with a narrow window and centered text (and long text could need to be scrolled).
				-- That style looks very bad for long detailed messages, so "display dialog" will be used instead of "display alert" on those versions of macOS.
				
				display dialog (resultsTitle & linefeed & linefeed & linefeed & resultsOutput) buttons resultsButtons default button 1 with title (name of me) with icon note
			else
				display alert (resultsTitle & linefeed) message resultsOutput buttons resultsButtons default button 1
			end if
			
			exit repeat
		end if
	else
		try
			if (isBigSurOrNewer and (not isVenturaOrNewer)) then
				-- On macOS 11 Big Sur and macOS 12 Monterey, alerts will only ever be a "compact" layout with a narrow window and centered text (and long text could need to be scrolled).
				-- That style looks very bad for long detailed messages, so "display dialog" will be used instead of "display alert" on those versions of macOS.
				
				display dialog (resultsTitle & linefeed & linefeed & linefeed & resultsOutput) buttons resultsButtons cancel button 1 default button 2 with title (name of me) with icon caution
			else
				display alert (resultsTitle & linefeed) message resultsOutput buttons resultsButtons cancel button 1 default button 2 as critical
			end if
			
			exit repeat
		end try
	end if
end repeat

try
	(("/Applications/Audio Test.app" as POSIX file) as alias)
	if (application id ("org.freegeek." & "Audio-Test") is not running) then -- Break up App ID or else build will fail if not found during compilation when app is not installed.
		try
			activate
		end try
		display alert "
Would you like to launch “Audio Test”?" buttons {"No", "Yes"} cancel button 1 default button 2 giving up after 30
		do shell script "open -na '/Applications/Audio Test.app'"
	end if
end try

on openTestSitesInSafari()
	try
		tell application id "com.apple.Safari"
			try
				activate
			end try
			close every window without saving
		end tell
		
		tell application id "com.apple.systemevents" to keystroke "n" using {shift down, command down} -- Open New Private Window
		
		repeat 10 times
			delay 1
			tell application id "com.apple.Safari"
				if ((count of windows) ≥ 1) then exit repeat -- Make sure New Private Window is Open
			end tell
		end repeat
		
		tell application id "com.apple.systemevents" to keystroke tab -- Tab to take focus out of address field
		
		tell application id "com.apple.Safari"
			if (application id "com.apple.Safari" is not running) then
				open location "https://google.com"
				try
					activate
				end try
			else
				try
					activate
				end try
				try
					set URL of front document to "https://google.com"
				on error
					open location "https://google.com"
				end try
			end if
			try
				activate
			end try
			delay 2
			open location "https://apple.com"
			try
				activate
			end try
			delay 3
		end tell
	end try
end openTestSitesInSafari

on doShellScriptAsAdmin(command)
	-- "do shell script with administrator privileges" caches authentication for 5 minutes: https://developer.apple.com/library/archive/technotes/tn2065/_index.html#//apple_ref/doc/uid/DTS10003093-CH1-TNTAG1-HOW_DO_I_GET_ADMINISTRATOR_PRIVILEGES_FOR_A_COMMAND_ & https://developer.apple.com/library/archive/releasenotes/AppleScript/RN-AppleScript/RN-10_4/RN-10_4.html#//apple_ref/doc/uid/TP40000982-CH104-SW10
	-- And, it takes reasonably longer to run "do shell script with administrator privileges" when credentials are passed vs without.
	-- In testing, 100 iteration with credentials took about 30 seconds while 100 interations without credentials after authenticated in advance took only 2 seconds.
	-- So, this function makes it easy to call "do shell script with administrator privileges" while only passing credentials when needed.
	-- Also, from testing, this 5 minute credential caching DOES NOT seem to be affected by any custom "sudo" timeout set in the sudoers file.
	-- And, from testing, unlike "sudo" the timeout DOES NOT keep extending from the last "do shell script with administrator privileges" without credentials but only from the last time credentials were passed.
	-- To be safe, "do shell script with administrator privileges" will be re-authenticated with the credentials every 4.5 minutes.
	-- NOTICE: "do shell script" calls are intentionally NOT in "try" blocks since detecting and catching those errors may be critical to the code calling the "doShellScriptAsAdmin" function.
	
	set currentDate to (current date)
	if ((lastDoShellScriptAsAdminAuthDate is equal to 0) or (currentDate ≥ (lastDoShellScriptAsAdminAuthDate + 270))) then -- 270 seconds = 4.5 minutes.
		set commandOutput to (do shell script command user name adminUsername password adminPassword with administrator privileges)
		set lastDoShellScriptAsAdminAuthDate to currentDate -- Set lastDoShellScriptAsAdminAuthDate to date *BEFORE* command was run since the command itself could have updated the date and the 5 minute timeout started when the command started, not when it finished.
	else
		set commandOutput to (do shell script command with prompt "This “" & (name of me) & "” password prompt should not have been displayed.

Please inform Free Geek I.T. that you saw this password prompt.

You can just press “Cancel” below to continue." with administrator privileges)
	end if
	
	return commandOutput
end doShellScriptAsAdmin
