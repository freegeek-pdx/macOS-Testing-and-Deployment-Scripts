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

-- Version: 2022.10.24-1

-- App Icon is “Satellite Antenna” from Twemoji (https://twemoji.twitter.com/) by Twitter (https://twitter.com)
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
	set intendedBundleIdentifier to ("org.freegeek." & ((words of intendedAppName) as string))
	set currentBundleIdentifier to ((do shell script ("/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' " & (quoted form of infoPlistPath))) as string)
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
		doShellScriptAsAdmin("touch " & (quoted form of (buildInfoPath & ".fgLaunchAfterSetup-org.freegeek." & ((words of (name of me)) as string))))
	end try
	
	if (not freeGeekUpdaterIsRunning) then
		try
			-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
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
end considering


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
				set thisNetworkDeviceName to ((last text item of thisNetworkInterfaceLine) as string)
			else if (thisNetworkInterfaceLine starts with "Device:") then
				set thisNetworkDeviceID to ((last text item of thisNetworkInterfaceLine) as string)
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
							try
								activate
							end try
							set noEthernetCableDetectedAlertReply to display dialog "🚫	No Ethernet Cable Detected


🔌	PLUG IN an Ethernet cable and then click \"Test Ethernet Again\".

‼️	If an Ethernet cable is plugged in and is not detected after multiple
	attempts, click \"Skip Ethernet Test\" and CONSULT AN INSTRUCTOR." buttons {"Open Test Sites in Safari", "Skip Ethernet Test", "Test Ethernet Again"} cancel button 2 default button 3 with title (name of me) with icon caution giving up after 30
							if (button returned of noEthernetCableDetectedAlertReply is equal to "Open Test Sites in Safari") then openTestSitesInSafari()
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
						try
							activate
						end try
						set failedEthernetTestAlertReply to display dialog "❌	Failed to Connect to the Internet via Etherent


🔒	Make sure the Ethernet cable is SECURELY CONNECTED or connect
	a DIFFERENT Ethernet cable and then click \"Test Ethernet Again\".

‼️	If the Ethernet cable is securely connected and this test fails after multiple
	attempts, click \"Skip Ethernet Test\" and CONSULT AN INSTRUCTOR." buttons {"Open Test Sites in Safari", "Skip Ethernet Test", "Test Ethernet Again"} cancel button 2 default button 3 with title (name of me) with icon caution giving up after 30
						if (button returned of failedEthernetTestAlertReply is equal to "Open Test Sites in Safari") then openTestSitesInSafari()
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
							set wiFiIsOff to ((do shell script "networksetup -getairportpower " & thisWiFiNetworkDeviceID) ends with "): Off")
						end try
						
						if (wiFiIsOff) then
							try
								do shell script "networksetup -setairportpower " & thisWiFiNetworkDeviceID & " on"
								set wiFiIsOff to ((do shell script "networksetup -getairportpower " & thisWiFiNetworkDeviceID) ends with "): Off")
							end try
						end if
						
						if (not wiFiIsOff) then exit repeat
					end repeat
					
					if (wiFiIsOff) then
						try
							try
								activate
							end try
							set failedToEnableWiFiAlertReply to display dialog "🚫	Failed to Enable Wi-Fi


☝️	Manually TURN ON Wi-Fi and then click \"Test Wi-Fi Again\".

👉	If Wi-Fi is turned on, DISCONNECT the Ethernet cable
	and then click \"Test Wi-Fi Again\".

‼️	If Wi-Fi is turned on and the Ethernet cable is
	disconnected and this test fails after multiple attempts,
	click \"Skip Wi-Fi Test\" and CONSULT AN INSTRUCTOR." buttons {"Open Test Sites in Safari", "Skip Wi-Fi Test", "Test Wi-Fi Again"} cancel button 2 default button 3 with title (name of me) with icon caution giving up after 30
							if (button returned of failedToEnableWiFiAlertReply is equal to "Open Test Sites in Safari") then openTestSitesInSafari()
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
						set getWiFiNetworkOutput to (do shell script "networksetup -getairportnetwork " & thisWiFiNetworkDeviceID)
						set getWiFiNetworkColonOffset to (offset of ":" in getWiFiNetworkOutput)
						if (getWiFiNetworkColonOffset > 0) then
							set connectedWiFiNetworkName to (text (getWiFiNetworkColonOffset + 2) thru -1 of getWiFiNetworkOutput)
							exit repeat
						end if
					end try
				end repeat
				
				if (connectedWiFiNetworkName is equal to "") then
					repeat with thisWiFiNetworkDeviceID in wiFiNetworkDeviceIDs
						try
							-- This needs admin privileges to add network to preferred network if it's not already preferred (it will pop up a gui prompt in this case if not run with admin).
							doShellScriptAsAdmin("networksetup -setairportnetwork " & thisWiFiNetworkDeviceID & " 'Free Geek'")
							exit repeat
						end try
					end repeat
					
					set AppleScript's text item delimiters to ": "
					repeat with thisWiFiNetworkDeviceID in wiFiNetworkDeviceIDs
						try
							set getWiFiNetworkOutput to (do shell script "networksetup -getairportnetwork " & thisWiFiNetworkDeviceID)
							set getWiFiNetworkColonOffset to (offset of ":" in getWiFiNetworkOutput)
							if (getWiFiNetworkColonOffset > 0) then
								set connectedWiFiNetworkName to (text (getWiFiNetworkColonOffset + 2) thru -1 of getWiFiNetworkOutput)
								exit repeat
							end if
						end try
					end repeat
					
					if (connectedWiFiNetworkName is not equal to "") then
						set gotWiFiIP to true
						repeat 5 times
							repeat with thisWiFiNetworkDeviceID in wiFiNetworkDeviceIDs
								try
									if ((do shell script "ipconfig getifaddr " & thisWiFiNetworkDeviceID) is equal to "") then
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
								set connectedToAppleViaWiFi to ((do shell script "ping -b " & thisWiFiNetworkDeviceID & " -t 2 -c 1 www.apple.com") contains "1 packets transmitted, 1 ")
							end try
							try
								set connectedToGoogleViaWiFi to ((do shell script "ping -b " & thisWiFiNetworkDeviceID & " -t 2 -c 1 www.google.com") contains "1 packets transmitted, 1 ")
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
						try
							activate
						end try
						set differentOrNothing to ""
						if (connectedWiFiNetworkName is not equal to "") then set differentOrNothing to " DIFFERENT"
						set wiFiTestFailedAlertReply to display dialog "❌	Failed to Connect to the Internet via Wi-Fi


☝️	MANUALLY CONNECT to a" & differentOrNothing & " Wi-Fi network
	and then click \"Test Wi-Fi Again\".

‼️	If this computer is connected to a known good Wi-Fi
	network and this test fails after multiple attempts,
	click \"Skip Wi-Fi Test\" and CONSULT AN INSTRUCTOR." buttons {"Open Test Sites in Safari", "Skip Wi-Fi Test", "Test Wi-Fi Again"} cancel button 2 default button 3 with title (name of me) with icon caution giving up after 30
						if (button returned of wiFiTestFailedAlertReply is equal to "Open Test Sites in Safari") then openTestSitesInSafari()
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
	and Google.com via Wi-Fi"
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
	and Google.com via Wi-Fi"
			end if
			
			if (connectedWiFiNetworkName is equal to "") then
				set resultsOutput to resultsOutput & "

🚫	Failed to Connect to a Wi-Fi Network

‼️	MANUALLY CONNECT TO A WI-FI
	NETWORK AND TRY AGAIN"
			else
				set resultsOutput to resultsOutput & "

⚡️	Connected to Wi-Fi Network: " & connectedWiFiNetworkName
			end if
			
			if ((not wiFiTestPassed) and (connectedWiFiNetworkName is not equal to "")) then
				set resultsOutput to resultsOutput & "

‼️	MANUALLY CONNECT TO A DIFFERENT
	WI-FI NETWORK AND TRY AGAIN"
			end if
		end if
		
		if ((count of wiFiNetworkDeviceIDs) > 1) then
			set resultsOutput to resultsOutput & "

‼️	MULTIPLE WI-FI CARDS DETECTED
	ONLY ONE WI-FI CARD HAS BEEN TESTED"
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
	and Google.com via Ethernet"
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
	and Google.com via Ethernet"
		else
			set resultsOutput to resultsOutput & "

🚫	No Ethernet Cable Detected

‼️	PLUG IN AN ETHERNET CABLE
	AND TRY AGAIN"
		end if
		
		if ((count of ethernetNetworkDeviceIDs) > 1) then
			set resultsOutput to resultsOutput & "

‼️	MULTIPLE ETHERNET PORTS DETECTED

‼️	TEST EACH ETHERNET PORT BY RUNNING
	THIS TEST MULTIPLE TIMES WITH ONLY
	ONE CABLE PLUGGED IN"
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
	MAKE SURE WI-FI IS TURNED ON
	AND TRY AGAIN"
	end if
	
	if ((hasWiFiCard and (connectedWiFiNetworkName is not equal to "") and (not wiFiTestPassed)) or (hasEthernetPort and ethernetCableConnected and (not ethernetTestPassed))) then
		set resultsOutput to resultsOutput & "


‼️	CONSULT AN INSTRUCTOR
	SINCE INTERNET TEST FAILED"
	end if
	
	set didPassInternetTest to (wiFiTestPassed and (ethernetTestPassed or (manufacturedWithoutEthernetPort and (not hasEthernetPort))))
	if (((isLaptop or manufacturedWithoutEthernetPort) and (not hasWiFiCard)) or ((not manufacturedWithoutEthernetPort) and (not hasEthernetPort))) then set didPassInternetTest to false
	
	set progress description to "
📡	Finished Testing Internet"
	
	try
		activate
	end try
	if didPassInternetTest then
		if ((count of ethernetNetworkDeviceIDs) > 1) then
			try
				display dialog resultsTitle & "


" & resultsOutput buttons {"Test Internet Again", "Done"} cancel button 1 default button 2 with title (name of me) with icon note
				exit repeat
			end try
		else
			set progress total steps to 1
			set progress completed steps to 1
			
			display dialog resultsTitle & "


" & resultsOutput buttons {"Done"} default button 1 with title (name of me) with icon note
			exit repeat
		end if
	else
		try
			display dialog resultsTitle & "


" & resultsOutput buttons {"Test Internet Again", "Done"} cancel button 1 default button 2 with title (name of me) with icon caution
			exit repeat
		end try
	end if
end repeat

try
	(("/Applications/Audio Test.app" as POSIX file) as alias)
	if (application ("Audio" & " Test") is not running) then
		try
			activate
		end try
		display alert "
Would you like to launch “Audio Test”?" buttons {"No", "Yes"} cancel button 1 default button 2 giving up after 30
		do shell script "open -na '/Applications/Audio Test.app'"
	end if
end try

on openTestSitesInSafari()
	tell application "Safari"
		try
			activate
		end try
		close every window without saving
	end tell
	
	tell application "System Events" to keystroke "n" using {shift down, command down} -- Open New Private Window
	
	repeat 10 times
		delay 1
		tell application "Safari"
			if ((count of windows) ≥ 1) then exit repeat -- Make sure New Private Window is Open
		end tell
	end repeat
	
	tell application "System Events" to keystroke tab -- Tab to take focus out of address field
	
	tell application "Safari"
		if (application "Safari" is not running) then
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
end openTestSitesInSafari

on doShellScriptAsAdmin(command)
	-- "do shell script with administrator privileges" caches authentication for 5 minutes: https://developer.apple.com/library/archive/technotes/tn2065/_index.html#//apple_ref/doc/uid/DTS10003093-CH1-TNTAG1-HOW_DO_I_GET_ADMINISTRATOR_PRIVILEGES_FOR_A_COMMAND_
	-- And, it takes reasonably longer to run "do shell script with administrator privileges" when credentials are passed vs without.
	-- In testing, 100 iteration with credentials took about 30 seconds while 100 interations without credentials after authenticated in advance took only 2 seconds.
	-- So, this function makes it easy to call "do shell script with administrator privileges" while only passing credentials when needed.
	-- Also, from testing, this 5 minute credential caching DOES NOT seem to be affected by any custom "sudo" timeout set in the sudoers file.
	-- And, from testing, unlike "sudo" the timeout DOES NOT keep extending from the last "do shell script with administrator privileges" without credentials but only from the last time credentials were passed.
	-- To be safe, "do shell script with administrator privileges" will be re-authenticated with the credentials every 4.5 minutes.
	-- NOTICE: "do shell script" calls are intentionally NOT in "try" blocks since detecting and catching those errors may be critical to the code calling the "doShellScriptAsAdmin" function.
	
	if ((lastDoShellScriptAsAdminAuthDate is equal to 0) or ((current date) ≥ (lastDoShellScriptAsAdminAuthDate + 270))) then -- 270 seconds = 4.5 minutes.
		set commandOutput to (do shell script command user name adminUsername password adminPassword with administrator privileges)
		set lastDoShellScriptAsAdminAuthDate to (current date)
	else
		set commandOutput to (do shell script command with administrator privileges)
	end if
	
	return commandOutput
end doShellScriptAsAdmin
