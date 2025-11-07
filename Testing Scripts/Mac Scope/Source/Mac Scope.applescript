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

-- Version: 2025.10.27-1

-- App Icon is “Microscope” from Twemoji (https://github.com/twitter/twemoji) by Twitter (https://twitter.com)
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
	
	set intendedAppName to "Mac Scope" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
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
		try
			activate
		end try
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
		do shell script ("touch " & (quoted form of (buildInfoPath & ".fgLaunchAfterSetup-org.freegeek." & ((words of (name of me)) as text)))) user name adminUsername password adminPassword with administrator privileges
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
	set isMojaveOrNewer to (systemVersion ≥ "10.14")
	set isCatalinaOrNewer to (systemVersion ≥ "10.15")
	set isBigSurOrNewer to (systemVersion ≥ "11.0")
end considering

if (isMojaveOrNewer) then
	try
		tell application id "com.apple.systemevents" to every window -- To prompt for Automation access on Mojave
	on error automationAccessErrorMessage number automationAccessErrorNumber
		if (automationAccessErrorNumber is equal to -1743) then
			try
				tell application id "com.apple.systempreferences" to activate
			end try
			try
				open location "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation" -- The "Privacy_Automation" anchor is not exposed/accessible via AppleScript, but can be accessed via URL Scheme.
			end try
			try
				activate
			end try
			try
				display dialog "“" & (name of me) & "” must be allowed to control and perform actions in “System Events” to be able to function.


USE THE FOLLOWING STEPS TO FIX THIS ISSUE:

• Open the “System Preferences” application.

• Click the “Security & Privacy” preference pane.

• Select the “Privacy” tab.

• Select “Automation” in the source list on the left.

• Find “" & (name of me) & "” in the list on the right and turn on the “System Events” checkbox underneath it.

• Relaunch “" & (name of me) & "” (using the button below)." buttons {"Quit", "Relaunch “" & (name of me) & "”"} cancel button 1 default button 2 with title (name of me) with icon caution
				try
					do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -na \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
				end try
			end try
			quit
			delay 10
		end if
	end try
end if


repeat
	repeat 3 times -- Will exit early if got Hardware, Memory, and Graphics info. But try 3 times in case these critical things didn't load.
		try
			tell application id "com.apple.systemevents" to tell current location of network preferences
				repeat with thisActiveNetworkService in (every service whose active is true)
					if (((name of interface of thisActiveNetworkService) as text) is equal to "Wi-Fi") then
						try
							do shell script ("networksetup -setairportpower " & ((id of interface of thisActiveNetworkService) as text) & " on")
						end try
					end if
				end repeat
			end tell
		end try
		
		try
			activate
		end try
		
		set computerIcon to "🖥"
		
		set progress total steps to 14
		set progress completed steps to 1
		set progress description to "
" & computerIcon & "	Loading Model Information"
		set progress additional description to ""
		
		set showSystemInfoAppButton to false
		
		set AppleScript's text item delimiters to ""
		set tmpPath to ((POSIX path of (((path to temporary items) as text) & "::")) & "fg" & ((words of (name of me)) as text) & "-") -- On Catalina, writing to trailing folder "/TemporaryItems/" often fails with "Operation not permitted" for some reason. Also, prefix all files with "fg" and name of script.
		
		set hardwareInfoPath to tmpPath & "hardwareInfo.plist"
		set restOfSystemOverviewInfoPath to tmpPath & "restOfSystemOverviewInfo.plist"
		set bluetoothInfoPath to tmpPath & "bluetoothInfo.plist"
		
		do shell script "rm -f " & (quoted form of hardwareInfoPath) & " " & (quoted form of restOfSystemOverviewInfoPath) & " " & " " & (quoted form of bluetoothInfoPath)
		
		-- SYSTEM MODEL INFORMATION
		
		set didGetHardwareInfo to false
		set isLaptop to false
		set supportsHighSierra to false
		set supportsMojaveWithMetalCapableGPU to false
		set supportsCatalina to false
		set supportsBigSur to false
		set supportsMonterey to false
		set supportsVentura to false
		set supportsSonoma to false
		set supportsSequoia to false
		set supportsTahoe to false
		set shortModelName to "UNKNOWN Model Name  ⚠️"
		set modelIdentifier to "UNKNOWN Model Identifier"
		set memorySize to "⚠️	UNKNOWN Size"
		set memorySlots to {}
		set chipType to "UNKNOWN Chip" -- For Apple Silicon
		set isAppleSilicon to false
		set processorTotalCoreCount to "❓"
		set processorHyperthreadingValue to ""
		set processorsCount to "❓"
		set hasT2chip to false
		set serialNumber to "UNKNOWNXXXXX"
		set serialNumberDatePart to "AA"
		set serialNumberConfigCode to "XXXX"
		set modelIdentifierName to "⚠️	UNKNOWN Model ID"
		set modelIdentifierNumber to "⚠️	UNKNOWN Model ID"
		set modelIdentifierMajorNumber to 0
		set modelIdentifierMinorNumber to 0
		repeat 30 times -- system_profiler seems to fail sometimes when run on login.
			set showSystemInfoAppButton to false
			try
				do shell script "system_profiler -xml SPHardwareDataType > " & (quoted form of hardwareInfoPath)
				tell application id "com.apple.systemevents" to tell property list file hardwareInfoPath
					set hardwareItems to (first property list item of property list item "_items" of first property list item)
					
					try
						set serialNumber to ((value of property list item "serial_number" of hardwareItems) as text) -- https://www.macrumors.com/2010/04/16/apple-tweaks-serial-number-format-with-new-macbook-pro/
						set serialNumberLength to (length of serialNumber)
						if (serialNumber is equal to "Not Available") then
							set serialNumber to "UNKNOWNXXXXX"
						else if ((serialNumberLength is equal to 11) or (serialNumberLength is equal to 12)) then
							set serialNumberDatePart to (text 3 thru 5 of serialNumber)
							if (serialNumberLength is equal to 12) then set serialNumberDatePart to (text 2 thru -1 of serialNumberDatePart)
							set serialNumberConfigCode to (text 9 thru -1 of serialNumber) -- The Configuration Code part of the Serial Number which indicates the model is the last 4 characters for 12 character serials and the last 3 characters for 11 character serials (which are very old and shouldn't actually be encountered).
						else if (serialNumberLength < 8) then -- https://www.macrumors.com/2021/03/09/apple-randomized-serial-numbers-early-2021/
							set serialNumber to "UNKNOWNXXXXX"
						end if
					on error
						set serialNumber to "UNKNOWNXXXXX"
					end try
					
					set shortModelName to ((value of property list item "machine_name" of hardwareItems) as text)
					if ((words of shortModelName) contains "MacBook") then
						set computerIcon to "💻"
						set isLaptop to true
					end if
					set modelIdentifier to ((value of property list item "machine_model" of hardwareItems) as text)
					set modelIdentifierName to (do shell script "echo " & (quoted form of modelIdentifier) & " | tr -d '[:digit:],'") -- Need use this whenever comparing along with Model ID numbers since there could be false matches for the newer "MacXX,Y" style Model IDs if I used shortModelName in those conditions instead (which I used to do).
					set modelIdentifierNumber to (do shell script "echo " & (quoted form of modelIdentifier) & " | tr -dc '[:digit:],'")
					set AppleScript's text item delimiters to ","
					set modelNumberParts to (every text item of modelIdentifierNumber)
					set modelIdentifierMajorNumber to ((item 1 of modelNumberParts) as number)
					set modelIdentifierMinorNumber to ((last item of modelNumberParts) as number)
					
					if (((modelIdentifierName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 10)) or ((modelIdentifierName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 6)) or ((modelIdentifierName is equal to "MacBookPro") and (modelIdentifierMajorNumber ≥ 6)) or ((modelIdentifierName is equal to "MacBookAir") and (modelIdentifierMajorNumber ≥ 3)) or ((modelIdentifierName is equal to "Macmini") and (modelIdentifierMajorNumber ≥ 4)) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber ≥ 5)) or (modelIdentifierName is equal to "iMacPro")) then set supportsHighSierra to true
					
					if ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber = 5)) then set supportsMojaveWithMetalCapableGPU to true
					
					if (((modelIdentifierName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 13)) or ((modelIdentifierName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 8)) or ((modelIdentifierName is equal to "MacBookPro") and (modelIdentifierMajorNumber ≥ 9)) or ((modelIdentifierName is equal to "MacBookAir") and (modelIdentifierMajorNumber ≥ 5)) or ((modelIdentifierName is equal to "Macmini") and (modelIdentifierMajorNumber ≥ 6)) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber ≥ 6)) or (modelIdentifierName is equal to "iMacPro")) then set supportsCatalina to true
					
					if (((modelIdentifierName is equal to "iMac") and ((modelIdentifierNumber is equal to "14,4") or (modelIdentifierMajorNumber ≥ 15))) or ((modelIdentifierName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 8)) or ((modelIdentifierName is equal to "MacBookPro") and (modelIdentifierMajorNumber ≥ 11)) or ((modelIdentifierName is equal to "MacBookAir") and (modelIdentifierMajorNumber ≥ 6)) or ((modelIdentifierName is equal to "Macmini") and (modelIdentifierMajorNumber ≥ 7)) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber ≥ 6)) or (modelIdentifierName is equal to "iMacPro")) then set supportsBigSur to true
					
					if (((modelIdentifierName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 16)) or ((modelIdentifierName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 9)) or ((modelIdentifierName is equal to "MacBookPro") and ((modelIdentifierNumber is equal to "11,4") or (modelIdentifierNumber is equal to "11,5") or (modelIdentifierMajorNumber ≥ 12))) or ((modelIdentifierName is equal to "MacBookAir") and (modelIdentifierMajorNumber ≥ 7)) or ((modelIdentifierName is equal to "Macmini") and (modelIdentifierMajorNumber ≥ 7)) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber ≥ 6)) or (modelIdentifierName is equal to "iMacPro") or (modelIdentifierName is equal to "Mac")) then set supportsMonterey to true
					
					if (((modelIdentifierName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 18)) or ((modelIdentifierName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 10)) or ((modelIdentifierName is equal to "MacBookPro") and (modelIdentifierMajorNumber ≥ 14)) or ((modelIdentifierName is equal to "MacBookAir") and (modelIdentifierMajorNumber ≥ 8)) or ((modelIdentifierName is equal to "Macmini") and (modelIdentifierMajorNumber ≥ 8)) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber ≥ 7)) or (modelIdentifierName is equal to "iMacPro") or (modelIdentifierName is equal to "Mac")) then set supportsVentura to true
					
					if (((modelIdentifierName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 19)) or ((modelIdentifierName is equal to "MacBookPro") and (modelIdentifierMajorNumber ≥ 15)) or ((modelIdentifierName is equal to "MacBookAir") and (modelIdentifierMajorNumber ≥ 8)) or ((modelIdentifierName is equal to "Macmini") and (modelIdentifierMajorNumber ≥ 8)) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber ≥ 7)) or (modelIdentifierName is equal to "iMacPro") or (modelIdentifierName is equal to "Mac")) then set supportsSonoma to true
					
					if (((modelIdentifierName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 19)) or ((modelIdentifierName is equal to "MacBookPro") and (modelIdentifierMajorNumber ≥ 15)) or ((modelIdentifierName is equal to "MacBookAir") and (modelIdentifierMajorNumber ≥ 9)) or ((modelIdentifierName is equal to "Macmini") and (modelIdentifierMajorNumber ≥ 8)) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber ≥ 7)) or (modelIdentifierName is equal to "iMacPro") or (modelIdentifierName is equal to "Mac")) then set supportsSequoia to true
					
					if (((modelIdentifierName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 20)) or ((modelIdentifierName is equal to "MacBookPro") and ((modelIdentifierNumber is equal to "16,1") or (modelIdentifierNumber is equal to "16,2") or (modelIdentifierNumber is equal to "16,4") or (modelIdentifierMajorNumber ≥ 17))) or ((modelIdentifierName is equal to "MacBookAir") and (modelIdentifierMajorNumber ≥ 10)) or ((modelIdentifierName is equal to "Macmini") and (modelIdentifierMajorNumber ≥ 9)) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber ≥ 7)) or (modelIdentifierName is equal to "Mac")) then set supportsTahoe to true
					
					set memorySize to ((value of property list item "physical_memory" of hardwareItems) as text)
					
					try
						set chipType to ((value of property list item "chip_type" of hardwareItems) as text) -- This will only exist when running natively on Apple Silicon
						set isAppleSilicon to true
					end try
					
					try
						set processorsCount to ((value of property list item "packages" of hardwareItems) as text) -- This will only exist on Intel or Apple Silicon under Rosetta
					end try
					
					set processorTotalCoreCount to ((value of property list item "number_processors" of hardwareItems) as text)
					
					try
						set processorHyperthreadingValue to ((value of property list item "platform_cpu_htt" of hardwareItems) as text) -- This will only exist on Mojave and newer
					end try
				end tell
				set didGetHardwareInfo to true
				exit repeat
			on error (hardwareInfoErrorMessage) number (hardwareInfoErrorNumber)
				log "Hardware Info Error: " & hardwareInfoErrorMessage
				do shell script "rm -f " & (quoted form of hardwareInfoPath)
				if (hardwareInfoErrorNumber is equal to -128) then
					quit
					delay 10
				end if
				set showSystemInfoAppButton to true
				delay 1 -- Wait and try again because it seems to fail sometimes when run on login.
			end try
		end repeat
		do shell script "rm -f " & (quoted form of hardwareInfoPath)
		
		-- https://web.archive.org/web/20220620162055/https://support.apple.com/en-us/HT212163
		set macBookPro2016and2017RecalledBatteryRecall to ({"MacBookPro13,1", "MacBookPro13,2", "MacBookPro13,3", "MacBookPro14,1", "MacBookPro14,2", "MacBookPro14,3"} contains modelIdentifier)
		
		-- https://support.apple.com/15-inch-macbook-pro-battery-recall
		set macBookPro15inch2015PossibleBatteryRecall to ({"MacBookPro11,4", "MacBookPro11,5"} contains modelIdentifier)
		
		-- https://support.apple.com/keyboard-service-program-for-mac-notebooks
		set macBookProButterflyKeyboardRecall to ({"MacBook8,1", "MacBook9,1", "MacBook10,1", "MacBookAir8,1", "MacBookAir8,2", "MacBookPro13,1", "MacBookPro13,2", "MacBookPro13,3", "MacBookPro14,1", "MacBookPro14,2", "MacBookPro14,3", "MacBookPro15,1", "MacBookPro15,2", "MacBookPro15,3", "MacBookPro15,4"} contains modelIdentifier)
		
		-- https://support.apple.com/13-inch-macbook-pro-display-backlight-service
		set macBookPro13inch2016PossibleBacklightRecall to ({"MacBookPro13,1", "MacBookPro13,2"} contains modelIdentifier)
		
		-- Only the 2016 13-inch is covered by Apple for the FLEXGATE issue, but the 15-inch and 2017 models may also have the same issue
		set macBookProOtherFlexgate to ({"MacBookPro13,3", "MacBookPro14,1", "MacBookPro14,2", "MacBookPro14,3"} contains modelIdentifier)
		
		-- https://web.archive.org/web/20221208144358/https://support.apple.com/13-inch-macbook-pro-solid-state-drive-service
		set macBookPro13inch2017PossibleSSDRecall to ("MacBookPro14,1" is equal to modelIdentifier)
		
		-- https://web.archive.org/web/20221209124713/https://support.apple.com/13inch-macbookpro-battery-replacement
		set macBookPro13inch2016PossibleBatteryRecall to ({"MacBookPro13,1", "MacBookPro14,1"} contains modelIdentifier)
		
		-- https://www.macrumors.com/2017/11/17/apple-extends-free-staingate-repairs/
		set macBookProScreenDelaminationRecall to ({"MacBook8,1", "MacBook9,1", "MacBook10,1", "MacBookPro11,4", "MacBookPro11,5", "MacBookPro12,1", "MacBookPro13,1", "MacBookPro13,2", "MacBookPro13,3", "MacBookPro14,1", "MacBookPro14,2", "MacBookPro14,3"} contains modelIdentifier)
		
		-- https://web.archive.org/web/20190105114612/https://www.apple.com/support/macbookpro-videoissues/ & https://www.macrumors.com/2017/05/20/apple-ends-2011-macbook-pro-repair-program/
		set macBookProPossibleBadGraphics to ({"MacBookPro8,2", "MacBookPro8,3", "MacBookPro10,1"} contains modelIdentifier)
		
		-- https://www.macrumors.com/2016/11/29/imac-broken-hinge-refunds-repair-program/
		set iMacHingeRecall to ("iMac14,2" is equal to modelIdentifier)
		
		-- https://www.macrumors.com/2013/08/16/apple-initiates-graphic-card-replacement-program-for-mid-2011-27-inch-imac/
		set iMacPossibleBadGraphics to ((shortModelName is equal to "iMac") and ({"DHJQ", "DHJW", "DL8Q", "DNGH", "DNJ9", "DMW8", "DPM1", "DPM2", "DPNV", "DNY0", "DRVP", "DY6F", "F610"} contains serialNumberConfigCode))
		
		-- https://www.macrumors.com/2016/02/06/late-2013-mac-pro-video-issues-repair-program/
		set macProRecalledSerialDatePartsMatched to (("MacPro6,1" is equal to modelIdentifier) and ({"P5", "P6", "P7", "P8", "P9", "PC", "PD", "PF", "PG", "PH"} contains serialNumberDatePart))
		set macProRecalledGraphicsCards to {"AMD FirePro D500", "AMD FirePro D700"}
		set macProPossibleBadGraphics to false
		
		set restOfSystemOverviewInfoToLoad to {"SPMemoryDataType", "SPNVMeDataType", "SPSerialATADataType", "SPDisplaysDataType", "SPAirPortDataType", "SPBluetoothDataType", "SPDiscBurningDataType"}
		if (isLaptop) then set (end of restOfSystemOverviewInfoToLoad) to "SPPowerDataType"
		set AppleScript's text item delimiters to space
		set systemProfilerPID to (do shell script "system_profiler -xml " & (restOfSystemOverviewInfoToLoad as text) & " > " & (quoted form of restOfSystemOverviewInfoPath) & " 2> /dev/null & echo $!")
		
		
		set progress completed steps to (progress completed steps + 1)
		set progress description to "
🧠	Loading Processor Information"
		
		-- FULL PROCESSOR INFORMATION
		
		set processorInfo to "⚠️	UNKNOWN Processor  ⚠️
	‼️	CHECK “System Information” FOR HARDWARE  ‼️"
		
		try
			set processorsCountPart to ""
			try
				if ((processorsCount as number) > 1) then set processorsCountPart to processorsCount & " x "
			on error number (processorsCountPartErrorNumber)
				if (processorsCountPartErrorNumber is equal to -128) then
					try
						do shell script "killall 'system_profiler'"
					end try
					do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
					quit
					delay 10
				end if
			end try
			
			set processorHyperthreadingNote to ""
			set setProcessorTotalThreadCount to processorTotalCoreCount
			if (processorHyperthreadingValue is equal to "") then -- Only need to check actual thread count to compare to core count if "platform_cpu_htt" was not available, which should only happen on older than Mojave.
				try
					set setProcessorTotalThreadCount to (do shell script "sysctl -n hw.logicalcpu_max")
				end try
			else if (processorHyperthreadingValue is equal to "htt_enabled") then
				set processorHyperthreadingNote to " + HT"
			end if
			
			if (isAppleSilicon) then
				-- "machdep.cpu.brand_string" did not give useful info on Apple Silicon in macOS 11 prior to 11.1 (it would be "Apple" natively or "VirtualApple @ 2.50GHz processor" under Rosetta, but now is correctly "Apple M1" either way).
				-- Still, just use "Chip" from system_profiler instead since it is the same info and outputs the correct info regardless of OS version.
				-- For Apple Silicon, processorTotalCoreCount will looks like "proc 8:4:4" which means "8 cores (4 performance and 4 efficiency)"
				
				set processorTotalCoreCount to (do shell script "echo " & (quoted form of processorTotalCoreCount) & " | tr -dc '[:digit:]:'")
				
				set processorCoreTypesNote to ""
				if (processorTotalCoreCount contains ":") then
					set AppleScript's text item delimiters to ":"
					set processorTotalCoreCountParts to (every text item of processorTotalCoreCount)
					set processorTotalCoreCount to (first text item of processorTotalCoreCountParts)
					
					if ((count of processorTotalCoreCountParts) is equal to 3) then
						set processorCoreTypesNote to " (" & (text item 2 of processorTotalCoreCountParts) & "P + " & (last text item of processorTotalCoreCountParts) & "E)"
					end if
				end if
				
				if ((processorHyperthreadingValue is equal to "") and (setProcessorTotalThreadCount > processorTotalCoreCount)) then set processorHyperthreadingNote to " + HT" -- Don't actually know that Apple Silicon with ever have hyperthreading, but doesn't hurt to check.
				-- Also don't know that Apple Silicon will ever have multiple processors (processorsCountPart), but also doesn't hurt to check and include for future possibilities.
				
				set processorInfo to processorTotalCoreCount & "-Core" & processorHyperthreadingNote & ": " & processorsCountPart & chipType & processorCoreTypesNote
			else
				set rawProcessorBrandString to (do shell script "sysctl -n machdep.cpu.brand_string")
				set AppleScript's text item delimiters to {"Genuine", "Intel", "(R)", "(TM)", "CPU", "GHz", "processor"}
				set processorInfoParts to (every text item of rawProcessorBrandString)
				set AppleScript's text item delimiters to space
				set processorInfoParts to (words of (processorInfoParts as text))
				set processorSpeed to ((last item of processorInfoParts) as text)
				if ((last character of processorSpeed) is equal to "0") then set processorSpeed to (text 1 thru -2 of processorSpeed)
				set processorInfoParts to (text items 1 thru -2 of processorInfoParts)
				set processorModelFrom to {"Core i", "Core 2 Duo"}
				set processorModelTo to {"i", "C2D"}
				set processorModelPart to (processorInfoParts as text)
				repeat with i from 1 to (count of processorModelFrom)
					set AppleScript's text item delimiters to (text item i of processorModelFrom)
					set processorModelCoreParts to (every text item of processorModelPart)
					if ((count of processorModelCoreParts) ≥ 2) then
						set AppleScript's text item delimiters to (text item i of processorModelTo)
						set processorModelPart to (processorModelCoreParts as text)
					end if
				end repeat
				
				if ((processorHyperthreadingValue is equal to "") and (setProcessorTotalThreadCount > processorTotalCoreCount)) then set processorHyperthreadingNote to " + HT"
				
				set processorInfo to processorTotalCoreCount & "-Core" & processorHyperthreadingNote & ": " & processorsCountPart & processorModelPart & " @ " & processorSpeed & " GHz"
				
				try
					if ((do shell script "ioreg -rn 'Apple T2 Controller' -d 1") contains "Apple T2 Controller") then
						set hasT2chip to true
						set processorInfo to (processorInfo & "
	T2 Security Chip")
					end if
				end try
			end if
		on error (processorInfoErrorMessage) number (processorInfoErrorNumber)
			log "Processor Info Error: " & processorInfoErrorMessage
			if (processorInfoErrorNumber is equal to -128) then
				try
					do shell script "killall 'system_profiler'"
				end try
				do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
				quit
				delay 10
			end if
			set showSystemInfoAppButton to true
		end try
		
		
		set didGetBatteryHealthInfo to false
		set batteryRows to ""
		set powerAdapterRows to ""
		if (isLaptop) then
			set progress completed steps to (progress completed steps + 1)
			set progress description to "
🔋	Loading Battery Health Information"
			
			-- BATTERY Health INFORMATION
			
			set batteryHealth to "⚠️	NOT Detected  ⚠️
	‼️	CHECK IF A BATTERY IS INSTALLED	‼️
	‼️	  CHECK BATTERY CONNECTIONS	‼️
	‼️	 REPLACE BATTERY IF NECESSARY	‼️"
			try
				set maxCapacityMhA to 0
				set cycleCount to 0
				set designCapacityMhA to 0
				set designCycleCount to 0
				set rawBatteryInfo to (do shell script "ioreg -rc AppleSmartBattery")
				set rawBatteryInfoParts to (paragraphs of rawBatteryInfo)
				
				repeat with thisRawBatteryInfoPart in rawBatteryInfoParts
					set maxCapacityOffset to (offset of "\"MaxCapacity\" = " in thisRawBatteryInfoPart) -- This is no longer correct and always lists "100" on Apple Silicon, but still check it because I'm not sure when/if "AppleRawMaxCapacity" is unavailable.
					set appleRawMaxCapacityOffset to (offset of "\"AppleRawMaxCapacity\" = " in thisRawBatteryInfoPart) -- This one is correct on Apple Silicon
					
					set cycleCountOffset to (offset of "\"CycleCount\" = " in thisRawBatteryInfoPart)
					set designCapacityOffset to (offset of "\"DesignCapacity\" = " in thisRawBatteryInfoPart)
					set designCycleCountOffset to (offset of "\"DesignCycleCount9C\" = " in thisRawBatteryInfoPart)
					
					if (maxCapacityOffset > 0) then
						set maxCapacityMhA to ((text (maxCapacityOffset + 16) thru -1 of thisRawBatteryInfoPart) as number)
					else if (appleRawMaxCapacityOffset > 0) then
						set appleRawMaxCapacityMhA to ((text (appleRawMaxCapacityOffset + 24) thru -1 of thisRawBatteryInfoPart) as number)
					else if (cycleCountOffset > 0) then
						set cycleCount to ((text (cycleCountOffset + 15) thru -1 of thisRawBatteryInfoPart) as number)
					else if (designCapacityOffset > 0) then
						set designCapacityMhA to ((text (designCapacityOffset + 19) thru -1 of thisRawBatteryInfoPart) as number)
					else if (designCycleCountOffset > 0) then
						set designCycleCount to ((text (designCycleCountOffset + 23) thru -1 of thisRawBatteryInfoPart) as number)
					end if
				end repeat
				
				if (maxCapacityMhA is equal to 100) then set maxCapacityMhA to appleRawMaxCapacityMhA -- To get correct maxCapacityMhA on Apple Silicon
				
				if (designCapacityMhA is equal to 0) then error "No Battery Found"
				set batteryCapacityPercentageLimit to 60
				set batteryCapacityPercentageNumber to (((round (((maxCapacityMhA / designCapacityMhA) * 100) * 10)) / 10) as text)
				if ((text -2 thru -1 of batteryCapacityPercentageNumber) is equal to ".0") then set batteryCapacityPercentageNumber to (text 1 thru -3 of batteryCapacityPercentageNumber)
				set batteryCapacityPercentageNumber to (batteryCapacityPercentageNumber as number)
				if (batteryCapacityPercentageNumber is equal to 0) then error "No Battery Found"
				
				set pluralizeCycles to "Cycle"
				if (cycleCount is not equal to 1) then set pluralizeCycles to "Cycles"
				set batteryHealth to (batteryCapacityPercentageNumber as text) & "% (Remaining of Design Capacity) + " & cycleCount & " " & pluralizeCycles
				if (batteryCapacityPercentageNumber < batteryCapacityPercentageLimit) then
					set batteryHealth to batteryHealth & "
	⚠️	BELOW " & batteryCapacityPercentageLimit & "% DESIGN CAPACITY  ⚠️"
				end if
				
				set cycleCountLimit to designCycleCount
				if (not macBookProPossibleBadGraphics) then set cycleCountLimit to (round (designCycleCount * 0.8))
				if ((designCycleCount > 0) and (cycleCount > (cycleCountLimit + 10))) then -- https://support.apple.com/HT201585
					set batteryHealth to batteryHealth & "
	⚠️	BATTERY OVER " & cycleCountLimit & " MAX CYCLES  ⚠️"
				end if
			on error (batteryCapacityInfoErrorMessage) number (batteryCapacityInfoErrorNumber)
				log "Battery Capacity Info Error: " & batteryCapacityInfoErrorMessage
				if (batteryCapacityInfoErrorNumber is equal to -128) then
					try
						do shell script "killall 'system_profiler'"
					end try
					do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
					quit
					delay 10
				end if
			end try
			
			
			set progress completed steps to (progress completed steps + 1)
			set progress description to "
🔌	Loading Power Adapter Information"
			
			-- LAPTOP POWER ADAPTER INFO (https://support.apple.com/HT201700)
			-- BUT, I wrote a script (https://github.com/freegeek-pdx/macOS-Testing-and-Deployment-Scripts/blob/main/Other%20Scripts/get_power_adapters_from_all_mac_specs_pages.sh) to extract every Power Adapter for each Model ID from every specs URL from the Model pages linked here: https://support.apple.com/HT213325
			
			set powerAdapterType to "⚠️	UNKNOWN Power Adapter  ⚠️"
			
			-- Power Adapter Model IDs Last Updated: 10/27/25
			if ({"MacBookPro1,1", "MacBookPro1,2", "MacBookPro2,1", "MacBookPro2,2", "MacBookPro3,1", "MacBookPro4,1", "MacBookPro5,1", "MacBookPro5,2", "MacBookPro5,3", "MacBookPro6,1", "MacBookPro6,2", "MacBookPro8,2", "MacBookPro8,3", "MacBookPro9,1"} contains modelIdentifier) then
				set powerAdapterType to "85W MagSafe 1"
			else if ({"MacBook1,1", "MacBook2,1", "MacBook3,1", "MacBook4,1", "MacBook5,1", "MacBook5,2", "MacBook6,1", "MacBook7,1", "MacBookPro5,4", "MacBookPro5,5", "MacBookPro7,1", "MacBookPro8,1", "MacBookPro9,2"} contains modelIdentifier) then
				set powerAdapterType to "60W MagSafe 1"
			else if ({"MacBookAir1,1", "MacBookAir2,1", "MacBookAir3,1", "MacBookAir3,2", "MacBookAir4,1", "MacBookAir4,2"} contains modelIdentifier) then
				set powerAdapterType to "45W MagSafe 1"
			else if ({"MacBookPro10,1", "MacBookPro11,2", "MacBookPro11,3", "MacBookPro11,4", "MacBookPro11,5"} contains modelIdentifier) then
				set powerAdapterType to "85W MagSafe 2"
			else if ({"MacBookPro10,2", "MacBookPro11,1", "MacBookPro12,1"} contains modelIdentifier) then
				set powerAdapterType to "60W MagSafe 2"
			else if ({"MacBookAir5,1", "MacBookAir5,2", "MacBookAir6,1", "MacBookAir6,2", "MacBookAir7,1", "MacBookAir7,2"} contains modelIdentifier) then
				set powerAdapterType to "45W MagSafe 2"
			else if ({"MacBookPro16,1", "MacBookPro16,4"} contains modelIdentifier) then
				set powerAdapterType to "96W USB-C"
			else if ({"MacBookPro13,3", "MacBookPro14,3", "MacBookPro15,1", "MacBookPro15,3"} contains modelIdentifier) then
				set powerAdapterType to "87W USB-C"
			else if ({"Mac14,7"} contains modelIdentifier) then
				set powerAdapterType to "67W USB-C"
			else if ({"MacBookPro13,1", "MacBookPro13,2", "MacBookPro14,1", "MacBookPro14,2", "MacBookPro15,2", "MacBookPro15,4", "MacBookPro16,2", "MacBookPro16,3", "MacBookPro17,1"} contains modelIdentifier) then
				set powerAdapterType to "61W USB-C"
			else if ({"MacBook10,1", "MacBookAir8,1", "MacBookAir8,2", "MacBookAir9,1", "MacBookAir10,1"} contains modelIdentifier) then
				set powerAdapterType to "30W USB-C"
			else if ({"MacBook8,1", "MacBook9,1"} contains modelIdentifier) then
				set powerAdapterType to "29W USB-C"
			else if ({"Mac14,6", "Mac14,10", "Mac15,7", "Mac15,9", "Mac15,11", "Mac16,5", "Mac16,7", "MacBookPro18,1", "MacBookPro18,2"} contains modelIdentifier) then
				set powerAdapterType to "140W USB-C/MagSafe 3"
			else if ({"Mac14,5", "Mac14,9", "MacBookPro18,3", "MacBookPro18,4"} contains modelIdentifier) then
				set powerAdapterType to "67W or 96W USB-C/MagSafe 3"
			else if ({"Mac14,2", "Mac15,12", "Mac16,12"} contains modelIdentifier) then
				set powerAdapterType to "30W or 35W Dual Port or 70W USB-C/MagSafe 3"
			else if ({"Mac14,15", "Mac15,13", "Mac16,13"} contains modelIdentifier) then
				set powerAdapterType to "35W Dual Port or 70W USB-C/MagSafe 3"
			else if ({"Mac15,3", "Mac15,6", "Mac15,8", "Mac15,10", "Mac16,1", "Mac16,6", "Mac16,8", "Mac17,2"} contains modelIdentifier) then
				set powerAdapterType to "70W or 96W USB-C/MagSafe 3"
			end if
			
			(* OLD CODE (Last Updated: 8/10/22)
				if (shortModelName is equal to "MacBook") then
					if (modelIdentifierMajorNumber = 10) then
						set powerAdapterType to "30W USB-C"
					else if (modelIdentifierMajorNumber ≥ 8) then
						set powerAdapterType to "29W USB-C"
					else
						set powerAdapterType to "60W MagSafe 1"
					end if
				else if (shortModelName is equal to "MacBook Pro") then
					if (modelIdentifierName is equal to "Mac") then
						-- Starting with the Mac Studio, all Model IDs are now just "MacXX,Y" so if this is a MacBook Pro, the Model IDs start back at "Mac14,7" for the "MacBook Pro (13-inch, M2, 2022)"
						-- which would get detected wrong in the conditions after this point which are all for the older style "MacBookProXX,Y" Model IDs.
						if (modelIdentifierNumber is equal to "14,7") then -- This is the only one that's out yet, and it appers the numbers are shared across all models (not just MacBook Pros) of that Apple Silicon generation, so there will likely be less of a pattern to the numbers ending of the numbers.
							set powerAdapterType to "67W USB-C"
						end if
					else if ((modelIdentifierNumber is equal to "5,4") or (modelIdentifierNumber is equal to "5,5") or (modelIdentifierNumber is equal to "7,1") or (modelIdentifierNumber is equal to "8,1") or (modelIdentifierNumber is equal to "9,2")) then
						-- 5,4 is "MacBook Pro (15-inch, 2.53 GHz, Mid 2009)" which uses 60W for some reason, the rest are all 13 inch Pro's
						set powerAdapterType to "60W MagSafe 1"
					else if ((modelIdentifierNumber is equal to "10,2") or (modelIdentifierNumber is equal to "11,1") or (modelIdentifierNumber is equal to "12,1")) then
						set powerAdapterType to "60W MagSafe 2"
					else if (modelIdentifierMajorNumber = 18) then
						if (modelIdentifierMinorNumber ≤ 2) then
							set powerAdapterType to "140W USB-C/MagSafe 3"
						else
							set powerAdapterType to "67W or 96W USB-C/MagSafe 3"
						end if
					else if (modelIdentifierMajorNumber = 17) then --  There was only a 17,1 model 13" MacBook Pro (the first Apple Silicon MBP)
						set powerAdapterType to "61W USB-C"
					else if (modelIdentifierMajorNumber = 16) then
						if ((modelIdentifierMinorNumber = 2) or (modelIdentifierMinorNumber = 3)) then
							set powerAdapterType to "61W USB-C"
						else
							set powerAdapterType to "96W USB-C"
						end if
					else if (modelIdentifierMajorNumber = 15) then
						if ((modelIdentifierMinorNumber = 2) or (modelIdentifierMinorNumber = 4)) then
							set powerAdapterType to "61W USB-C"
						else
							set powerAdapterType to "87W USB-C"
						end if
					else if (modelIdentifierMajorNumber ≥ 13) then
						if (modelIdentifierMinorNumber ≥ 3) then
							set powerAdapterType to "87W USB-C"
						else
							set powerAdapterType to "61W USB-C"
						end if
					else if (modelIdentifierMajorNumber ≥ 10) then
						set powerAdapterType to "85W MagSafe 2"
					else
						set powerAdapterType to "85W MagSafe 1"
					end if
				else if (shortModelName is equal to "MacBook Air") then
					if (modelIdentifierName is equal to "Mac") then -- See comments above in the MacBook Pro section about the new Model ID naming style
						if (modelIdentifierNumber is equal to "14,2") then
							set powerAdapterType to "30W or 35W Dual Port or 67W USB-C/MagSafe 3"
						end if
					else if (modelIdentifierMajorNumber ≥ 8) then
						set powerAdapterType to "30W USB-C"
					else if (modelIdentifierMajorNumber ≥ 5) then
						set powerAdapterType to "45W MagSafe 2"
					else
						set powerAdapterType to "45W MagSafe 1"
					end if
				end if
			*)
			
			set powerAdapterRows to "

🔌	Power Adapter:
	" & powerAdapterType
		else
			set progress completed steps to (progress completed steps + 2)
		end if
		
		
		-- BLADE SSD COMPATIBILITY (https://beetstech.com/blog/apple-proprietary-ssd-ultimate-guide-to-specs-and-upgrades)
		-- Blade SSD Compatibility Last Updated: 8/5/22
		
		set compatibleBladeSSDs to ""
		if (modelIdentifierName is equal to "MacBookAir") then
			if ((modelIdentifierMajorNumber = 3) or (modelIdentifierMajorNumber = 4)) then
				set compatibleBladeSSDs to "Gen 1 / Model C"
			else if (modelIdentifierMajorNumber = 5) then
				set compatibleBladeSSDs to "Gen 2B / Model E (Narrow)"
			else if (modelIdentifierMajorNumber = 6) then
				set compatibleBladeSSDs to "Gen 3A / Model F (Narrow)"
			else if (modelIdentifierMajorNumber = 7) then
				if (modelIdentifierMinorNumber = 1) then
					set compatibleBladeSSDs to "Gen 4C / Model H"
				else
					set compatibleBladeSSDs to "Gen 4A / Model G (Narrow)"
				end if
			end if
		else if (((modelIdentifierName is equal to "MacBookPro") and (modelIdentifierMajorNumber = 10)) or ((modelIdentifierName is equal to "iMac") and (modelIdentifierMajorNumber = 13))) then
			set compatibleBladeSSDs to "Gen 2A / Model E (Wide)"
		else if (((modelIdentifierName is equal to "MacBookPro") and (modelIdentifierMajorNumber = 11) and (modelIdentifierMinorNumber ≤ 3)) or ((modelIdentifierName is equal to "iMac") and ((modelIdentifierMajorNumber = 14) or (modelIdentifierMajorNumber = 15))) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber = 6)) or ((modelIdentifierName is equal to "Macmini") and (modelIdentifierMajorNumber = 7))) then
			set compatibleBladeSSDs to "Gen 3A or 3B / Model F"
			if ((modelIdentifierName is equal to "iMac") or (modelIdentifierName is equal to "MacPro") or (modelIdentifierName is equal to "Macmini")) then set compatibleBladeSSDs to (compatibleBladeSSDs & " (or Gen 4A or 4B / Model G)") -- iMac14,X built around at least mid 2015 shipped with Gen 4/Model G drives (seen first hand with in situ wiped iMac14,1), and same with Macmini7,1 built in 2016 (also seen first hand with in-situ wiped Macmini7,1). Later MacPro6,1 also shipped with Gen 4/Model G drives since they were sold for so long (seen first hand Gen 4 blades with heatsink which only came in MacPro6,1).
			if (modelIdentifierName is equal to "MacPro") then set compatibleBladeSSDs to (compatibleBladeSSDs & " with Heatsink")
		else if (((modelIdentifierName is equal to "MacBookPro") and ((modelIdentifierMajorNumber = 12) or ((modelIdentifierMajorNumber = 11) and (modelIdentifierMinorNumber ≥ 4)))) or ((modelIdentifierName is equal to "iMac") and ((modelIdentifierMajorNumber = 16) or (modelIdentifierMajorNumber = 17)))) then
			set compatibleBladeSSDs to "Gen 4A or 4B / Model G"
			if ((modelIdentifierName is equal to "iMac") and ((modelIdentifierMajorNumber = 16) or (modelIdentifierMajorNumber = 17))) then set compatibleBladeSSDs to (compatibleBladeSSDs & " (or Gen 4C / Model H)") -- Late 2015 iMacs (iMac16,X & iMac17,X) that shipped with fusion drives or maybe when they shipped around at least mid 2016 started shipping with Gen 4C/Model H NVMe drives (seen first hand with in situ wiped iMac17,1), so those must be allowed as well (there were previously issues with those models getting firmware updates, probably because of these NVMe drive, but I think Apple fixed that). Reference: https://eclecticlight.co/2021/02/06/could-this-fix-firmware-updating-in-the-imac-retina-5k-27-inch-late-2015-imac171/
		else if ((modelIdentifierName is equal to "MacBookPro") and (((modelIdentifierMajorNumber = 13) or (modelIdentifierMajorNumber = 14)) and (modelIdentifierMinorNumber = 1))) then
			set compatibleBladeSSDs to "Gen 5A / Model J"
			if (modelIdentifierMajorNumber = 14) then set compatibleBladeSSDs to (compatibleBladeSSDs & " (or Model L)") -- MacBookPro14,1 could have Model J or L drive (seen them ship with Model L later on at least when manufactured in 2018 and maybe when the SSD was replaced under recall).
		else if ((modelIdentifierName is equal to "iMac") and ((modelIdentifierMajorNumber = 18) or (modelIdentifierMajorNumber = 19))) then
			-- Models with Gen 5B Blade SSD not listed in Beetstech Blog post linked above:
			-- 2017 iMac: https://www.ifixit.com/Guide/iMac+Intel+21.5-Inch+Retina+4K+Display+(2017)+Blade+SSD+Replacement/101104 & https://www.userbenchmark.com/System/Apple-iMac181/60967 & https://discussions.apple.com/thread/251660820?answerId=253197784022#253197784022 & https://www.userbenchmark.com/System/Apple-iMac182/58934 & https://www.userbenchmark.com/System/Apple-iMac183/58155
			-- 2019 iMac: https://www.ifixit.com/Guide/iMac+Intel+27-Inch+Retina+5K+Display+2019+Blade+SSD+Replacement/137596 & https://www.ebay.com/itm/234634547975 & https://www.userbenchmark.com/System/Apple-iMac191/138712 & https://www.userbenchmark.com/System/Apple-iMac192/139386
			set compatibleBladeSSDs to "Gen 5B / Model L"
		end if
		
		
		set progress completed steps to (progress completed steps + 1)
		set progress description to "
" & computerIcon & "	Loading Marketing Model Name"
		
		-- MARKETING MODEL NAME INFORMATION
		
		set modelInfo to ""
		set modelPartNumber to ""
		set marketingModelName to ""
		set possibleMarketingModelNames to ""
		set possibleMarketingModelNamesCount to 0
		set didGetLocalMarketingModelName to false
		
		if (hasT2chip or isAppleSilicon) then -- This "M####LL/A" style Model Part Number is only be accessible in software on T2 and Apple Silicon Macs.
			try
				set modelPartNumber to (do shell script "/usr/libexec/remotectl dumpstate | awk '($1 == \"RegionInfo\") { if ($NF == \"=>\") { region_info = \"LL/A\" } else { region_info = $NF } } ($1 == \"ModelNumber\") { if ($NF ~ /\\//) { print $NF } else { print $NF region_info } exit }'")
			end try
		end if
		
		if (isAppleSilicon) then
			try
				-- This local marketing model name only exists on Apple Silicon Macs.
				set marketingModelName to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :0:product-name' /dev/stdin <<< \"$(ioreg -arc IOPlatformDevice -k product-name)\" | tr -d '[:cntrl:]'"))) -- Remove control characters because this decoded value could end with a NUL char.
				
				if (marketingModelName is not equal to "") then
					set didGetLocalMarketingModelName to true
				end if
			end try
		else
			try
				-- The following list of Marketing Model Names with grouped Model IDs and Serial Config Codes is generated from: https://github.com/freegeek-pdx/macOS-Testing-and-Deployment-Scripts/blob/main/Other%20Scripts/group_every_intel_mac_marketing_model_name_with_model_ids_and_serial_config_codes.sh
				-- And the full output from that script is here: https://github.com/freegeek-pdx/macOS-Testing-and-Deployment-Scripts/blob/main/Other%20Scripts/serial-config-codes-output/every_intel_mac_marketing_model_name_with_grouped_model_ids_and_serial_config_codes.txt
				set everyIntelMacMarketingModelNameWithGroupedModelIDsAndSerialConfigCodes to {"iMac (17-inch, Early 2006):iMac4,1:U2N:U2R:V4M:V4N:V4U:V66:VGB:VGZ:VH1:VHP:VV4:VV6:", ¬
					"iMac (17-inch, Late 2006 CD):iMac5,2:", ¬
					"iMac (17-inch, Late 2006):iMac5,1:AC1:VUX:VUY:WAR:WRR:WRW:WV8:WVR:X1A:X1W:X2W:X6Q:X9F:X9Y:XLF:Y3V:Y3W:Y3X:Y6K:Y94:Y97:YAG:YLJ:", ¬
					"iMac (17-inch, Mid 2006):iMac4,2:", ¬
					"iMac (20-inch, Early 2006):iMac4,1:U2P:U2S:V4P:V4Q:V4R:V67:VGC:VGM:VH0:VH2:VW4:VX0:WXN:X0U:", ¬
					"iMac (20-inch, Early 2008):iMac8,1:28B:2PN:2PR:3FF:3FG:3SZ:5A8:5J0:6F9:8R2:8R3:ZE2:ZE3:ZE5:ZE6:", ¬
					"iMac (20-inch, Early 2009):iMac9,1:0TF:0TH:6X0:8M5:8TS:8TT:9EX:9LN:", ¬
					"iMac (20-inch, Late 2006):iMac5,1:VUV:VUW:WRS:WRX:WSD:X0E:X29:X6S:X9E:X9G:XA4:XCR:XCY:Y3R:Y3U:Y9B:YAE:YDW:", ¬
					"iMac (20-inch, Mid 2007):iMac7,1:02X:09Q:0PQ:0PR:0PT:0U1:1NU:1NV:3PB:X85:X86:X87:X88:Z58:Z9G:ZEG:ZFD:", ¬
					"iMac (20-inch, Mid 2009):iMac9,1:6MH:6MJ:9TH:BAH:DMV:DWY:E86:FUN:FXN:GM9:H1S:HS6:HS7:HT6:HUE:", ¬
					"iMac (21.5-inch, 2017):iMac18,1:", ¬
					"iMac (21.5-inch, Early 2013):iMac13,3:", ¬
					"iMac (21.5-inch, Late 2009):iMac10,1:5PC:5PK:B9S:B9U:CY8:DMW:DMX:DWR:DWU:E8D:E8E:E8F:F0G:F0H:FQH:FU1:H9K:HDF:", ¬
					"iMac (21.5-inch, Late 2011):iMac12,1:DKL9:DKLH:DPNK:DPNW:", ¬
					"iMac (21.5-inch, Late 2012):iMac13,1:", ¬
					"iMac (21.5-inch, Late 2013):iMac14,1:iMac14,3:", ¬
					"iMac (21.5-inch, Late 2015):iMac16,1:iMac16,2:GF1J:GF1K:GF1L:GF1M:GG77:GG79:GG7D:GG7G:H0N6:H0P6:H1DX:H1DY:H1F1:H1F2:H1WR:H25M:H2KW:H8KX:HHMG:HQ9T:HQ9V:HQ9W:HYGQ:J0DG:J0DH:J0DJ:", ¬
					"iMac (21.5-inch, Mid 2010):iMac11,2:", ¬
					"iMac (21.5-inch, Mid 2011):iMac12,1:DHJF:DHJN:DHJR:DHJT:DL8M:DL8N:DMP0:DNWY:DPM0:DPNT:DWTP:DWTQ:F611:", ¬
					"iMac (21.5-inch, Mid 2014):iMac14,4:", ¬
					"iMac (24-inch, Early 2008):iMac8,1:0KM:0N4:1LW:28A:2E4:2NX:2PT:39S:3F9:3FH:3GS:3NX:5J1:5U6:6J3:6J6:6ZC:ZE4:ZE7:", ¬
					"iMac (24-inch, Early 2009):iMac9,1:0TG:0TJ:0TL:0TM:250:259:6X1:6X2:6X3:8M6:8XH:9ET:9F3:9LP:9LQ:9LR:9LS:E1B:", ¬
					"iMac (24-inch, Late 2006):iMac6,1:", ¬
					"iMac (24-inch, Mid 2007):iMac7,1:0PL:0PM:0PN:0PP:0PU:1NW:1SC:2CB:3PA:X89:X8A:Z59:Z9F:ZCR:ZCT:ZCV:ZCW:ZEF:ZGH:ZGP:", ¬
					"iMac (27-inch, Late 2009):iMac10,1:iMac11,1:5PE:5PJ:5PM:5RU:CYB:CYC:D4V:DMY:DMZ:DWZ:E1J:F0J:F0K:GRP:H9L:H9N:H9P:H9R:", ¬
					"iMac (27-inch, Late 2012):iMac13,2:", ¬
					"iMac (27-inch, Late 2013):iMac14,2:", ¬
					"iMac (27-inch, Mid 2010):iMac11,3:", ¬
					"iMac (27-inch, Mid 2011):iMac12,2:", ¬
					"iMac (Retina 4K, 21.5-inch, 2017):iMac18,2:", ¬
					"iMac (Retina 4K, 21.5-inch, 2019):iMac19,2:", ¬
					"iMac (Retina 4K, 21.5-inch, Late 2015):iMac16,2:GG78:GG7C:GG7F:GG7H:H0KF:H0P7:H15R:H1F3:H1F5:H1F7:H1F8:H1F9:H25N:H28H:H3RJ:H8KY:H8L0:H8L1:H8L2:H8L3:HLWV:", ¬
					"iMac (Retina 5K, 27-inch, 2017):iMac18,3:", ¬
					"iMac (Retina 5K, 27-inch, 2019):iMac19,1:", ¬
					"iMac (Retina 5K, 27-inch, 2020):iMac20,1:iMac20,2:", ¬
					"iMac (Retina 5K, 27-inch, Late 2014):iMac15,1:FY11:FY14:FY68:FY6F:GCTM:GDQY:GDR3:GDR4:GDR5:GDR6:GDR7:GDR8:GDR9:GDRC:GFFQ:GJDM:GJDN:GJDP:GJDQ:GPJN:GV7V:H5DN:H682:", ¬
					"iMac (Retina 5K, 27-inch, Late 2015):iMac17,1:", ¬
					"iMac (Retina 5K, 27-inch, Mid 2015):iMac15,1:FY10:FY13:FY67:FY6D:GL1Q:GL1R:GL1T:GL1V:GL1W:", ¬
					"iMac Pro (2017):iMacPro1,1:", ¬
					"Mac mini (2018):Macmini8,1:", ¬
					"Mac mini (Early 2006):Macmini1,1:U35:U36:U38:U39:VJN:VLK:VS5:VS7:VU2:VU4:WBZ:WCU:WEN:", ¬
					"Mac mini (Early 2009):Macmini3,1:19X:19Y:1BU:1BV:8NC:92G:9RR:9RS:AFR:BAV:", ¬
					"Mac mini (Late 2006):Macmini1,1:W0A:W0B:W0C:W0D:WKN:X1X:X1Y:X1Z:X20:XAS:Y9E:", ¬
					"Mac mini (Late 2009):Macmini3,1:306:307:9G5:9G6:9G7:9G8:AFK:B9X:CS6:DMG:DMH:F6J:", ¬
					"Mac mini (Late 2012):Macmini6,1:Macmini6,2:DWYL:DWYM:DY3G:DY3H:F9RK:F9RL:F9RM:F9VV:F9VW:F9W0:F9W1:F9W2:FD9G:FD9H:FD9J:FD9K:FDWK:FGML:FRFP:FW56:FW57:G430:", ¬
					"Mac mini (Late 2014):Macmini7,1:", ¬
					"Mac mini (Mid 2007):Macmini2,1:", ¬
					"Mac mini (Mid 2010):Macmini4,1:DD6H:DD6L:DDQ9:DDVN:DFDK:", ¬
					"Mac mini (Mid 2011):Macmini5,1:Macmini5,2:", ¬
					"Mac mini Server (Late 2012):Macmini6,2:DWYN:DY3J:F9VY:F9W3:FC08:FCCW:FP14:FP39:", ¬
					"Mac mini Server (Mid 2010):Macmini4,1:DD6K:DD6N:DDJF:", ¬
					"Mac mini Server (Mid 2011):Macmini5,3:", ¬
					"Mac Pro (2019):MacPro7,1:K7GD:K7GF:NYGV:P7QJ:P7QK:P7QL:P7QM:P7QN:P7QP:PLXV:PLXW:PLXX:PLXY:", ¬
					"Mac Pro (Early 2008):MacPro3,1:", ¬
					"Mac Pro (Early 2009):MacPro4,1:20G:20H:4PC:4PD:7BF:8MC:8PZ:8Q0:8TR:8TU:8XG:8XL:93H:9EU:9EV:9MC:9MD:9MG:9MJ:9MK:9ML:9QK:ANS:BXD:BXE:BXT:CZ2:CZ3:CZ4:E1C:E1D:E1E:EAA:EYX:EYY:F6H:GYH:", ¬
					"Mac Pro (Late 2013):MacPro6,1:", ¬
					"Mac Pro (Mid 2010):MacPro5,1:EUE:EUF:EUG:EUH:GWR:GY5:GZH:GZJ:GZK:GZL:GZM:H0X:H2N:H2P:H97:H99:HF7:HF8:HF9:HFA:HFC:HFD:HFF:HFG:HFJ:HFK:HFL:HFN:HG1:HG3:HP9:HPA:", ¬
					"Mac Pro (Mid 2012):MacPro5,1:F4MC:F4MD:F4MG:F4MH:F4YY:F500:F648:F649:F64C:F64D:F64F:F6T9:F6TC:F6TD:F6TF:F6TG:", ¬
					"Mac Pro (Rack, 2019):MacPro7,1:N5RH:N5RN:P7QQ:P7QR:P7QT:P7QV:PNTN:PNTP:PNTQ:PP3Y:", ¬
					"Mac Pro Server (Mid 2010):MacPro5,1:HPV:HPW:HPY:", ¬
					"Mac Pro Server (Mid 2012):MacPro5,1:F4MF:F4MJ:F501:", ¬
					"Mac Pro:MacPro1,1:MacPro2,1:", ¬
					"MacBook (13-inch, Aluminum, Late 2008):MacBook5,1:", ¬
					"MacBook (13-inch, Early 2008):MacBook4,1:0P0:0P1:0P2:0P4:0P5:0P6:1LX:1PX:1Q2:1Q7:1QA:1QB:1QE:1ZY:27H:27J:28C:28D:28E:385:3N9:3NA:3ND:3NE:3NF:3X6:47Z:4R7:4R8:", ¬
					"MacBook (13-inch, Early 2009):MacBook5,2:4R1:4R2:4R3:79D:79E:79F:7A2:85D:88J:8CP:8SJ:93K:", ¬
					"MacBook (13-inch, Late 2006):MacBook2,1:WGK:WGL:WGM:WGN:WGP:WGQ:WGS:WGT:WGU:WVN:X6G:X6H:X6J:X6K:X6L:X7X:X97:X98:XAR:XAT:XC5:XDN:XDR:XDS:XDT:XDU:XDV:XDW:XDX:XDY:XDZ:XE0:XE1:XE2:XE3:XHB:XHC:XKT:XMF:Y6L:Y6M:Y9A:YCU:", ¬
					"MacBook (13-inch, Late 2007):MacBook3,1:", ¬
					"MacBook (13-inch, Late 2008):MacBook4,1:3VY:5AQ:5HS:5HU:67C:6ES:6HY:6LL:6LM:6M1:6V9:6YP:7XD:", ¬
					"MacBook (13-inch, Late 2009):MacBook6,1:", ¬
					"MacBook (13-inch, Mid 2007):MacBook2,1:YA2:YA3:YA4:YA5:YA6:YA7:YA8:YA9:YJJ:YJK:YJL:YJM:YJN:YQ7:YQ8:YRG:YRH:YRJ:YRK:YSH:YSJ:YSK:YSL:YSM:YTK:YTL:YV8:YX1:YX2:YX4:YX5:YXZ:YY1:YYW:Z5V:Z5W:Z5X:Z5Y:Z5Z:Z60:Z88:ZA8:ZA9:ZAP:ZAQ:ZAS:ZAU:ZAV:ZAW:ZAX:ZAY:ZAZ:ZB0:ZB1:ZB2:ZB7:ZB8:ZB9:ZBA:ZBB:ZBE:ZBF:ZBG:ZBH:ZBJ:ZBK:ZCN:", ¬
					"MacBook (13-inch, Mid 2009):MacBook5,2:9GU:9GV:A1W:A1X:A1Y:A9P:A9Q:A9Y:ABW:ASC:", ¬
					"MacBook (13-inch, Mid 2010):MacBook7,1:", ¬
					"MacBook (13-inch):MacBook1,1:", ¬
					"MacBook (Retina, 12-inch, 2017):MacBook10,1:", ¬
					"MacBook (Retina, 12-inch, Early 2015):MacBook8,1:", ¬
					"MacBook (Retina, 12-inch, Early 2016):MacBook9,1:", ¬
					"MacBook Air (11-inch, Early 2014):MacBookAir6,1:FM72:G083:G084:G2CF:G2GH:G2GJ:G2PY:G2Q0:G4FY:G4H0:G4H4:G4HK:G4HM:G58J:G5RK:G5RL:G5RM:G6D3:GLK9:GP4N:GP4P:", ¬
					"MacBook Air (11-inch, Early 2015):MacBookAir7,1:", ¬
					"MacBook Air (11-inch, Late 2010):MacBookAir3,1:", ¬
					"MacBook Air (11-inch, Mid 2011):MacBookAir4,1:", ¬
					"MacBook Air (11-inch, Mid 2012):MacBookAir5,1:", ¬
					"MacBook Air (11-inch, Mid 2013):MacBookAir6,1:F5N7:F5N8:F5YV:F5YW:FH51:FH52:FKYN:FKYP:FLCF:FMR5:FMR6:FMR9:FMRC:FMRD:FMRF:FMRG:FMRM:FMRN:FN5M:FN7F:FP2N:FP3C:FQLG:FT30:", ¬
					"MacBook Air (13-inch, 2017):MacBookAir7,2:J1WK:J1WL:J1WM:J1WT:J1WV:J8N7:J8XG:J8XH:J9HX:J9TN:J9TP:J9TQ:JC9H:JCD6:JFLY:JKHD:JKHF:LQ07:LQF1:MFWJ:", ¬
					"MacBook Air (13-inch, Early 2014):MacBookAir6,2:G085:G086:G2CC:G2CD:G2GK:G2GL:G2GM:G2GN:G356:G4H1:G4H2:G4H3:G4HN:G4HP:G58K:G5RN:G5RP:G5RQ:G6D4:G6D5:G829:G8J1:GLK7:GLK8:GP4L:GP4M:", ¬
					"MacBook Air (13-inch, Early 2015):MacBookAir7,2:G940:G941:G942:G943:G944:GKJT:GKJV:GL20:GL21:GL22:GL23:GL24:GL25:GLCN:GLCP:GM14:GM15:GM38:GM6M:GM9G:GMC3:GMD3:GN8C:GNJJ:GNKM:H3QD:H3QF:H3QJ:H3QK:H569:H8VT:H8VV:H8VW:H8VX:HD7X:HD80:HD98:HDV4:HDV5:HDV6:HF4F:HF4H:HF9N:J6VL:", ¬
					"MacBook Air (13-inch, Late 2010):MacBookAir3,2:", ¬
					"MacBook Air (13-inch, Mid 2011):MacBookAir4,2:", ¬
					"MacBook Air (13-inch, Mid 2012):MacBookAir5,2:", ¬
					"MacBook Air (13-inch, Mid 2013):MacBookAir6,2:F5V7:F5V8:F6T5:F6T6:FH53:FKYQ:FKYR:FLCG:FM23:FM3Y:FM74:FMR7:FMR8:FMRH:FMRJ:FMRK:FMRL:FMRV:FMRW:FMRY:FN3Y:FN40:FN7G:FP2P:FQL9:FQLC:FQLD:FQLF:G6PM:", ¬
					"MacBook Air (Late 2008):MacBookAir2,1:22D:22E:5L9:5LA:5TX:5U1:5U7:60R:62W:63V:63W:6JN:", ¬
					"MacBook Air (Mid 2009):MacBookAir2,1:9A5:9A6:9A7:9A8:", ¬
					"MacBook Air (Original):MacBookAir1,1:", ¬
					"MacBook Air (Retina, 13-inch, 2018):MacBookAir8,1:", ¬
					"MacBook Air (Retina, 13-inch, 2019):MacBookAir8,2:", ¬
					"MacBook Air (Retina, 13-inch, 2020):MacBookAir9,1:", ¬
					"MacBook Pro (13-inch, 2016, Four Thunderbolt 3 Ports):MacBookPro13,2:", ¬
					"MacBook Pro (13-inch, 2016, Two Thunderbolt 3 ports):MacBookPro13,1:", ¬
					"MacBook Pro (13-inch, 2017, Four Thunderbolt 3 Ports):MacBookPro14,2:", ¬
					"MacBook Pro (13-inch, 2017, Two Thunderbolt 3 ports):MacBookPro14,1:", ¬
					"MacBook Pro (13-inch, 2018, Four Thunderbolt 3 Ports):MacBookPro15,2:JHC8:JHC9:JHCC:JHCD:JHCF:JHD2:JHD3:JHD4:JHD5:KK98:KK99:KK9C:KQ1X:KQ1Y:KQ20:KQ21:KQ22:KQ23:KQ24:KQ25:KQ26:KQ27:L42X:L4FC:L4FD:L4FF:L4FG:L4FJ:L4JT:L7GD:LK8C:", ¬
					"MacBook Pro (13-inch, 2019, Four Thunderbolt 3 ports):MacBookPro15,2:LVDC:LVDD:LVDF:LVDG:LVDH:LVDL:LVDM:LVDN:LVDP:MV9K:MV9R:N5T5:NCLV:NCLW:NCLX:NCLY:NCM0:NCM1:NCM2:NQM8:P4G1:P4G2:", ¬
					"MacBook Pro (13-inch, 2019, Two Thunderbolt 3 ports):MacBookPro15,4:", ¬
					"MacBook Pro (13-inch, 2020, Four Thunderbolt 3 ports):MacBookPro16,2:", ¬
					"MacBook Pro (13-inch, 2020, Two Thunderbolt 3 ports):MacBookPro16,3:", ¬
					"MacBook Pro (13-inch, Early 2011):MacBookPro8,1:DH2G:DH2H:DH2L:DH2M:DLN5:DLN6:DM75:DMLF:DMLH:DMLJ:DNCM:DNGD:DNKP:DNKQ:DNTK:DNVY:DR7W:DRJ7:DRJ9:DRJJ:DRJK:DRW1:DRW2:DRW7:DT4G:DT4H:DT60:DT61:DT62:DT63:DT64:DT65:DT66:DT67:ST61:", ¬
					"MacBook Pro (13-inch, Late 2011):MacBookPro8,1:DV13:DV14:DV16:DV17:DVHJ:DVHK:DVHP:DVHQ:DW13:DY1J:DY1K:DY5T:DY5V:DY6C:DY77:DYL0:DYL1:DYL2:F298:F299:", ¬
					"MacBook Pro (13-inch, Mid 2009):MacBookPro5,5:", ¬
					"MacBook Pro (13-inch, Mid 2010):MacBookPro7,1:", ¬
					"MacBook Pro (13-inch, Mid 2012):MacBookPro9,2:", ¬
					"MacBook Pro (15-inch, 2.4/2.2GHz):MacBookPro3,1:02V:0LQ:0LZ:0M0:0PA:0S3:0S6:1CY:1CZ:2QU:2QV:X91:X92:XAG:XAH:Y9S:Y9T:YAL:YAM:YKX:YKY:YKZ:YL0:YQ3:YW5:YW9:YWA:YWD:YYV:YYX:YZ0:Z05:Z09:Z0G:", ¬
					"MacBook Pro (15-inch, 2.53GHz, Mid 2009):MacBookPro5,4:", ¬
					"MacBook Pro (15-inch, 2016):MacBookPro13,3:", ¬
					"MacBook Pro (15-inch, 2017):MacBookPro14,3:", ¬
					"MacBook Pro (15-inch, 2018):MacBookPro15,1:MacBookPro15,3:JG5H:JG5J:JG5K:JG5L:JG5M:JGH5:JGH6:JGH7:JGH8:KGYF:KGYG:KGYH:KQ9Q:KQ9R:KQ9T:KQ9V:KQ9W:KQ9X:KQ9Y:KQC0:KQC1:KQC2:KQC3:KQC4:KQC5:KQC6:KQC7:KQC8:KQC9:KQCC:KQCD:KQCF:KQCG:KQCH:KQCJ:KQCK:KQCL:KQCM:KQCN:KQCP:KQCQ:KQCR:KQCT:KQCV:KQCW:KQCX:KWJ2:L4HW:L4HX:L539:L53D:L7GC:LC8J:LC8K:LC8L:LCM6:MJLR:MJLT:", ¬
					"MacBook Pro (15-inch, 2019):MacBookPro15,1:MacBookPro15,3:LVCF:LVCG:LVCH:LVCJ:LVCK:LVCL:LVDQ:LVDR:LVDT:LVDV:MV9T:MVC0:N5T6:N6KF:N6RJ:NCM3:NCM4:NCM5:NCM6:NQM9:NQMC:NQMD:NQMF:", ¬
					"MacBook Pro (15-inch, Core 2 Duo):MacBookPro2,2:", ¬
					"MacBook Pro (15-inch, Early 2008):MacBookPro4,1:1AJ:1EK:1EM:1JZ:1K0:1SH:1XR:1XW:27N:2AZ:2B0:2CE:2DT:2DX:2MF:2PK:33B:3LY:3LZ:48T:4R5:4R6:YJX:YJY:YJZ:YK0:ZLU:", ¬
					"MacBook Pro (15-inch, Early 2011):MacBookPro8,2:DF8V:DF8X:DF8Y:DF91:DLN7:DLN8:DMC8:DMC9:DMDG:DMDH:DMDJ:DMGG:DMMF:DMMH:DMMJ:DMPG:DMPK:DMPL:DMPM:DMPN:DMPP:DMPQ:DMPR:DMQP:DNC3:DNCN:DNGF:DNH5:DNHY:DNKM:DNKY:DNM4:DNMW:DNRD:DNVK:DRJC:DRJD:DRJF:DRJL:DRJM:DRW3:DRW4:DRWD:DT4J:DT54:DT55:DT56:DT57:DT58:DT59:DT5C:DT5D:DT5F:DT5G:DT5H:DT5J:DT5L:DT68:DT69:DT6C:DT6D:DT6F:DT6G:DT6H:DT6J:DT6K:DT6L:DT6M:DT6R:", ¬
					"MacBook Pro (15-inch, Glossy):MacBookPro1,1:VWW:VWX:VWY:VWZ:W3N:W92:W93:W94:W9F:W9Q:WAG:WAW:WB8:WBE:WBF:WBH:WBJ:WD7:WD8:WD9:WDA:WDB:WDC:WDD:WTS:WW0:WW1:WW2:WW3:", ¬
					"MacBook Pro (15-inch, Late 2008):MacBookPro5,1:", ¬
					"MacBook Pro (15-inch, Late 2011):MacBookPro8,2:DV7L:DV7M:DV7N:DV7P:DVHL:DVHM:DVHR:DW3G:DW3H:DW3J:DW47:DY1L:DY1M:DY1N:DY1P:DY1Q:DY1R:DY1T:DY1V:DY1W:DY1Y:DY20:DY21:DY5K:DY5P:DY5Q:DY5R:DY5Y:DY60:DY7G:DYG6:DYG7:DYK9:DYKC:DYR1:F0K6:F0V2:", ¬
					"MacBook Pro (15-inch, Mid 2009):MacBookPro5,3:", ¬
					"MacBook Pro (15-inch, Mid 2010):MacBookPro6,2:", ¬
					"MacBook Pro (15-inch, Mid 2012):MacBookPro9,1:", ¬
					"MacBook Pro (16-inch, 2019):MacBookPro16,1:MacBookPro16,4:", ¬
					"MacBook Pro (17-inch, 2.4GHz):MacBookPro3,1:027:028:02D:09R:09S:0LR:0ND:0NM:0PD:1CW:1CX:1MF:1MG:2QW:X94:XA9:YAA:YAN:YAP:YNQ:YNS:YNW:YQ4:YQ5:YR2:YRD:YRE:YRF:YWB:YWC:YZ1:YZ2:Z5M:", ¬
					"MacBook Pro (17-inch, Core 2 Duo):MacBookPro2,1:", ¬
					"MacBook Pro (17-inch, Early 2008):MacBookPro4,1:1BY:1ED:1EN:1ER:1K2:1K8:1K9:1KA:1Q3:1SG:2CF:2DY:2DZ:2ED:3DC:3DD:3DE:3DF:3M0:3M4:3M5:YP3:YP4:ZLV:", ¬
					"MacBook Pro (17-inch, Early 2009):MacBookPro5,2:2QP:2QT:776:77A:7AP:7AS:7XQ:7XR:7XS:87K:87L:87M:87N:8FK:8FL:8FM:8FY:8FZ:8G0:", ¬
					"MacBook Pro (17-inch, Early 2011):MacBookPro8,3:DF92:DF93:DLN9:DLNC:DMGH:DMQT:DMQW:DMR2:DMR4:DMR5:DMR7:DMR8:DMR9:DMRC:DNGG:DNKN:DRJG:DRJH:DRJN:DRW5:DRW6:DT5M:DT5N:DT5P:DT5Q:DT5R:DT5T:DT5V:DT5W:DT5Y:DT6N:DT6P:", ¬
					"MacBook Pro (17-inch, Late 2008):MacBookPro4,1:3R8:3R9:4RT:4RW:57J:5U0:634:65A:663:664:666:668:6CT:6JK:", ¬
					"MacBook Pro (17-inch, Late 2011):MacBookPro8,3:AY5W:DV10:DV11:DVHN:DVHV:DVHW:DW48:DY22:DY23:DY24:DY25:DY26:DY5W:DYG8:F13Y:F140:", ¬
					"MacBook Pro (17-inch, Mid 2009):MacBookPro5,2:8YA:8YB:91T:A3M:A3N:A5R:A5W:AF3:AKV:AKW:AMV:AMW:AN1:ANC:AND:ANE:ANF:ANJ:AUU:E6L:", ¬
					"MacBook Pro (17-inch, Mid 2010):MacBookPro6,1:", ¬
					"MacBook Pro (17-inch):MacBookPro1,2:", ¬
					"MacBook Pro (Original):MacBookPro1,1:THV:VGW:VGX:VGY:VJ0:VJ1:VJ2:VJ3:VJ5:VJ6:VJ7:VJM:VMU:VSD:VTZ:VU0:VWA:VWB:VXW:VXX:W2Q:", ¬
					"MacBook Pro (Retina, 13-inch, Early 2013):MacBookPro10,2:FFRP:FFRR:FG1F:FG28:FGM8:FGN5:FGN6:FGPJ:FHCH:FHN0:", ¬
					"MacBook Pro (Retina, 13-inch, Early 2015):MacBookPro12,1:", ¬
					"MacBook Pro (Retina, 13-inch, Late 2012):MacBookPro10,2:DR53:DR54:DR55:DR56:F775:F776:F7YF:F897:F8V6:F8V7:F8V8:F9JT:F9V1:F9VQ:FG7Q:FG7R:FL85:FMLJ:", ¬
					"MacBook Pro (Retina, 13-inch, Late 2013):MacBookPro11,1:FGYY:FH00:FH01:FH02:FH03:FH04:FH05:FRF6:FRF7:FRQF:FT4Q:FT4R:FT4T:FT4V:FTC9:FTCD:FTCH:FTCK:FTCL:FTPH:FTPJ:FTPK:FTT4:FVVW:FVWQ:FWKF:G4N6:G4N7:", ¬
					"MacBook Pro (Retina, 13-inch, Mid 2014):MacBookPro11,1:G3QH:G3QJ:G3QK:G3QL:G3QQ:G3QR:G3QT:G7RD:G7RF:G7YQ:G7YR:G8L0:G96R:G96T:G96V:G96W:G96Y:G970:G971:G972:G9FL:G9FM:G9FN:G9FP:G9FQ:G9FR:GDJM:", ¬
					"MacBook Pro (Retina, 15-inch, Early 2013):MacBookPro10,1:FFT0:FFT1:FFT2:FFT3:FFT4:FG1H:FG1J:FGFH:FGFJ:FGFK:FGFL:FGN7:FGWF:FGWG:FGWH:FHCQ:FHCR:FJ47:FJVJ:FL94:FMLK:FR8D:", ¬
					"MacBook Pro (Retina, 15-inch, Late 2013):MacBookPro11,2:MacBookPro11,3:FD56:FD57:FD58:FD59:FR1M:FRDM:FRG2:FRG3:FRQH:FRQJ:FRQK:FRQL:FT4P:FTK0:FTK1:FTPL:FTPM:FTPN:FTPP:FTPQ:FTPR:FTPT:FTPV:FTPW:FTPY:FTTJ:FVN4:FVYN:FWFY:FWHW:FWKK:FWKL:G4JQ:G5HL:", ¬
					"MacBook Pro (Retina, 15-inch, Mid 2014):MacBookPro11,2:MacBookPro11,3:G3QC:G3QD:G3QG:G3QN:G3QP:G85Y:G86P:G86Q:G86R:G8F4:G8J7:G8L1:G96K:G96L:G96M:G96N:G96P:G96Q:G973:G974:G9FT:G9JN:G9L6:G9L7:G9L8:G9L9:GDPP:ZORD:", ¬
					"MacBook Pro (Retina, 15-inch, Mid 2015):MacBookPro11,4:MacBookPro11,5:", ¬
					"MacBook Pro (Retina, Mid 2012):MacBookPro10,1:DKQ1:DKQ2:DKQ4:DKQ5:F51R:F5Y2:F69W:F69Y:F6DN:F6F3:F6L9:F8JY:F96W:F9F1:F9F2:FCQ3:", ¬
					"Xserve (Early 2008):Xserve2,1:", ¬
					"Xserve (Early 2009):Xserve3,1:", ¬
					"Xserve (Late 2006):Xserve1,1:"}
				
				set possibleMarketingModelNamesList to {}
				set AppleScript's text item delimiters to ":"
				repeat with thisIntelMacMarketingModelNameWithGroupedModelIDsAndSerialConfigCodes in everyIntelMacMarketingModelNameWithGroupedModelIDsAndSerialConfigCodes
					if ((serialNumberConfigCode is not equal to "XXXX") and (thisIntelMacMarketingModelNameWithGroupedModelIDsAndSerialConfigCodes contains ":" & serialNumberConfigCode & ":")) then
						set possibleMarketingModelNamesList to {(text item 1 of thisIntelMacMarketingModelNameWithGroupedModelIDsAndSerialConfigCodes)}
						exit repeat
					else if (thisIntelMacMarketingModelNameWithGroupedModelIDsAndSerialConfigCodes contains ":" & modelIdentifier & ":") then
						set (end of possibleMarketingModelNamesList) to (text item 1 of thisIntelMacMarketingModelNameWithGroupedModelIDsAndSerialConfigCodes)
					end if
				end repeat
				
				set possibleMarketingModelNamesCount to (count of possibleMarketingModelNamesList)
				if (possibleMarketingModelNamesCount is equal to 1) then
					set marketingModelName to (text item 1 of possibleMarketingModelNamesList)
					set didGetLocalMarketingModelName to true
				else if (possibleMarketingModelNamesCount is not equal to 0) then
					set AppleScript's text item delimiters to (linefeed & tab & space)
					set possibleMarketingModelNames to (possibleMarketingModelNamesList as text)
				end if
			end try
		end if
		
		if (not didGetLocalMarketingModelName) then
			if ((serialNumber is not equal to "") and (serialNumber is not equal to "UNKNOWNXXXXX")) then
				set marketingModelNameWasCached to false
				set didDownloadMarketingModelName to false
				if (serialNumberConfigCode is not equal to "XXXX") then
					try
						-- If About This Mac has been opened, the Marketing Model Name will be cached in this user preference.
						-- Since "defaults read" has no option to traverse into keys of dictionary values, use the whole "defaults export" output and parse it with "PlistBuddy" to get at the specific key of the "CPU Names" dictionary value that we want.
						-- Using "defaults export" instead of accessing the plist file directly with "PlistBuddy" is important since preferences are not guaranteed to be written to disk if they were just set.
						set cachedMarketingModelName to (do shell script ("bash -c " & (quoted form of ("/usr/libexec/PlistBuddy -c \"Print :'CPU Names':" & serialNumberConfigCode & "-en-US_US\" /dev/stdin <<< \"$(defaults export com.apple.SystemProfiler -)\" | tr -s '[:space:]' ' ' | sed -E 's/^ | $//g'"))))
						if (cachedMarketingModelName starts with shortModelName) then -- Make sure the value starts with the short model name, since technically anything could be set to this value manually.
							set marketingModelName to cachedMarketingModelName
							set marketingModelNameWasCached to true
						end if
					end try
				end if
				if (not marketingModelNameWasCached) then -- With the "everyIntelMacMarketingModelNameWithGroupedModelIDsAndSerialConfigCodes" list being parsed above, this internet-based Marketing Model Name retrieval should no longer get used since that is now a complete and static list as there are no new Intel Macs, but keep this code around just in case and for reference.
					set tryCount to 0
					repeat 30 times
						if (tryCount ≥ 5) then
							if (tryCount mod 2 is 0) then
								set progress description to "
" & computerIcon & "	Loading Marketing Model Name"
							else
								set progress description to "
" & computerIcon & "	Loading Marketing Model Name	⚠️ INTERNET REQUIRED ⚠️"
							end if
						end if
						try
							if ((year of the (current date)) < 2023) then
								try
									do shell script "systemsetup -setusingnetworktime off; systemsetup -setusingnetworktime on" user name adminUsername password adminPassword with administrator privileges
								end try
							end if
							if (serialNumberConfigCode is not equal to "XXXX") then
								try
									-- The following URL API is what "About This Mac" uses to load the Marketing Model Name.
									set marketingModelName to (do shell script ("curl -m 5 -sfL 'https://support-sp.apple.com/sp/product?cc=" & serialNumberConfigCode & "' | xmllint --xpath 'normalize-space(//configCode)' -"))
								end try
							end if
							if ((marketingModelName is equal to "") or (marketingModelName does not start with shortModelName) or (marketingModelName is equal to shortModelName)) then
								--If the "About This Mac" URL API (used above) failed or only returned the Short Model Name (such as how "MacBook Air" will only be returned for *SOME* 2013 "MacBookAir6,1" or "MacBookAir6,2" serials),
								-- fallback on using the "Specs Search" URL API (used below) to retrieve the Marketing Model Name (since it will return "MacBook Air (11-inch, Mid 2013)" for the 2013 "MacBookAir6,1" and "MacBook Air (13-inch, Mid 2013)" for the 2013 "MacBookAir6,2").
								-- For more information about this "Specs Search" URL API, see: https://github.com/freegeek-pdx/macOS-Testing-and-Deployment-Scripts/blob/main/Other%20Scripts/get_specs_url_from_serial.sh
								-- IMPORTANT: On May 15th, 2025, "https://km.support.apple.com/kb/index?page=categorydata" started returning 403 Forbidden! But other active "page" values that are still used on other parts of their site still work, so I think this was intentionally taken down.
								
								set marketingModelName to (do shell script ("osascript -l 'JavaScript' -e 'run = argv => JSON.parse(argv[0]).name.replace(/\\s+/g, \" \").trim()' -- \"$(curl -m 10 -sfL 'https://km.support.apple.com/kb/index?page=categorydata&serialnumber=" & serialNumber & "')\"")) -- I have seen this URL API timeout after 5 seconds when called multiple times rapidly (likely because of rate limiting), so give it a 10 second timeout which seems to always work.
							end if
							if (marketingModelName is not equal to "") then
								set didDownloadMarketingModelName to true
								exit repeat
							end if
						on error (downloadMarketingModelNameErrorMessage) number (downloadMarketingModelNameErrorNumber)
							set tryCount to tryCount + 1
							if (downloadMarketingModelNameErrorNumber is equal to -128) then
								do shell script "killall 'system_profiler'; rm -f " & (quoted form of restOfSystemOverviewInfoPath)
								quit
								delay 10
							end if
							try
								delay 1 -- Wait and try again in case still connecting to internet.
							on error (waitToDownloadMarketingModelNameErrorMessage) number (waitToDownloadMarketingModelNameErrorNumber)
								if (waitToDownloadMarketingModelNameErrorNumber is equal to -128) then
									do shell script "killall 'system_profiler'; rm -f " & (quoted form of restOfSystemOverviewInfoPath)
									quit
									delay 10
								end if
							end try
						end try
					end repeat
				end if
				try
					if (didDownloadMarketingModelName) then
						if ((marketingModelName is equal to "") or (marketingModelName does not start with shortModelName)) then
							error "Unknown Marketing Model Name"
						else if (serialNumberConfigCode is not equal to "XXXX") then
							-- Cache marketing model name into the About This Mac preference key if it had to be downloaded.
							set speciallyQuotedMarketingModelNameToCache to marketingModelName
							if ((marketingModelName contains "(") or (marketingModelName contains ")")) then
								-- If the model contains parentheses, "defaults write" has trouble with it and the value needs to be specially quoted (along with using "quoted form of")
								-- https://apple.stackexchange.com/questions/300845/how-do-i-handle-e-g-correctly-escape-parens-in-a-defaults-write-key-val#answer-300853
								set speciallyQuotedMarketingModelNameToCache to "'" & marketingModelName & "'"
							end if
							try
								do shell script "defaults write com.apple.SystemProfiler 'CPU Names' -dict-add '" & serialNumberConfigCode & "-en-US_US' " & (quoted form of speciallyQuotedMarketingModelNameToCache)
							end try
						end if
					else if (not marketingModelNameWasCached) then
						error "Failed to Download Marketing Model Name"
					end if
				on error (marketingModelNameErrorMessage) number (marketingModelNameErrorNumber)
					log "Marketing Model Name Error: " & marketingModelNameErrorMessage
					if (marketingModelNameErrorNumber is equal to -128) then
						do shell script "killall 'system_profiler'; rm -f " & (quoted form of restOfSystemOverviewInfoPath)
						quit
						delay 10
					end if
					set showInternetRequiredErrorPart to ""
					if (marketingModelNameErrorMessage is not equal to "Unknown Marketing Model Name") then set showInternetRequiredErrorPart to " - Internet REQUIRED"
					set modelInfo to shortModelName & " (⚠️ UNKNOWN Marketing Name" & showInternetRequiredErrorPart & " ⚠️)"
					if (modelPartNumber is not equal to "") then set modelInfo to (modelInfo & " / " & modelPartNumber)
					
					if (possibleMarketingModelNames is equal to "") then
						if (showSystemInfoAppButton) then
							set modelInfo to modelInfo & "
	‼️	CHECK “System Information” FOR HARDWARE  ‼️"
						else
							set modelInfo to modelInfo & "
	‼️	LOOK UP MARKETING MODEL NAME FROM MODEL ID OR EMC  ‼️"
						end if
					else
						set modelInfo to (modelInfo & "

↪️	 " & possibleMarketingModelNamesCount & " Possible Model Names (👉 MANUALLY CONFIRM USING EMC 🔍):
	 " & possibleMarketingModelNames)
					end if
				end try
			else
				set modelInfo to shortModelName & " (⚠️ UNKNOWN Marketing Name - NO SERIAL ⚠️)"
				if (modelPartNumber is not equal to "") then set modelInfo to (modelInfo & " / " & modelPartNumber)
				
				if (possibleMarketingModelNames is equal to "") then
					set modelInfo to modelInfo & "
	‼️	LOOK UP MARKETING MODEL NAME FROM MODEL ID OR EMC  ‼️"
				else
					set modelInfo to (modelInfo & "

↪️	 " & possibleMarketingModelNamesCount & " Possible Model Names (👉 MANUALLY CONFIRM USING EMC 🔍):
	 " & possibleMarketingModelNames)
				end if
			end if
		end if
		
		if (marketingModelName is not equal to "") then
			if (modelInfo is equal to "") then
				set modelInfo to marketingModelName
				if (marketingModelName is equal to shortModelName) then
					set modelInfo to (modelInfo & " (No Marketing Model Name Specified)")
					if (modelPartNumber is not equal to "") then set modelInfo to (modelInfo & " / " & modelPartNumber)
					if (possibleMarketingModelNames is not equal to "") then
						set modelInfo to (modelInfo & "

↪️	 " & possibleMarketingModelNamesCount & " Possible Model Names (👉 MANUALLY CONFIRM USING EMC 🔍):
	 " & possibleMarketingModelNames)
					end if
				else if (modelPartNumber is not equal to "") then
					set modelInfo to (modelInfo & " / " & modelPartNumber)
				end if
			end if
		else
			set marketingModelName to shortModelName
			if (modelInfo is equal to "") then
				set modelInfo to marketingModelName & " (⚠️ UNKNOWN Marketing Name  - UNKNOWN ERROR ⚠️)"
				if (modelPartNumber is not equal to "") then set modelInfo to (modelInfo & " / " & modelPartNumber)
				if (possibleMarketingModelNames is equal to "") then
					set modelInfo to modelInfo & "
	‼️	LOOK UP MARKETING MODEL NAME FROM MODEL ID OR EMC  ‼️"
				else
					set modelInfo to (modelInfo & "

↪️	 " & possibleMarketingModelNamesCount & " Possible Model Names (👉 MANUALLY CONFIRM USING EMC 🔍):
	 " & possibleMarketingModelNames)
				end if
			end if
		end if
		
		if (modelInfo contains "Thunderbolt 3") then
			set AppleScript's text item delimiters to "Thunderbolt 3"
			set modelInfoThunderboltParts to (every text item of modelInfo)
			set AppleScript's text item delimiters to "TB3"
			set modelInfo to (modelInfoThunderboltParts as text)
		end if
		if (modelInfo contains "-inch") then
			set AppleScript's text item delimiters to "-inch"
			set modelInfoInchParts to (every text item of modelInfo)
			set AppleScript's text item delimiters to "”"
			set modelInfo to (modelInfoInchParts as text)
		end if
		if (modelInfo contains " 20") then
			set AppleScript's text item delimiters to " 20"
			set modelInfoYearParts to (every text item of modelInfo)
			set AppleScript's text item delimiters to " ’"
			set modelInfo to (modelInfoYearParts as text)
		end if
		
		set didGetMemoryInfo to false
		set memoryType to "⚠️ UNKNOWN Type"
		set memorySpeed to " @ UNKNOWN Speed ⚠️"
		set memoryNote to ""
		
		set didGetHardDriveInfo to false
		set hardDriveDiskIDs to {}
		set hardDrivesList to {}
		set maxSataRevision to 0
		set storageInfo to "⚠️	NOT Detected  ⚠️
	‼️	CHECK IF A HARD DRIVE IS INSTALLED	‼️
	‼️	  CHECK HARD DRIVE CONNECTIONS	‼️
	‼️	 REPLACE HARD DRIVE IF NECESSARY	‼️"
		
		set didGetGraphicsInfo to false
		set graphicsInfo to "⚠️	UNKNOWN Graphics  ⚠️
	‼️	CHECK “System Information” FOR GRAPHICS  ‼️"
		
		set didGetWiFiInfo to false
		set wiFiInfo to "⚠️	Wi-Fi NOT Detected  ⚠️
	‼️	CHECK “System Information” FOR WI-FI  ‼️"
		
		set didGetBluetoothInfo to false
		set bluetoothInfo to "⚠️	Bluetooth NOT Detected  ⚠️
	‼️	CHECK “System Information” FOR BLUETOOTH  ‼️"
		if ((marketingModelName is equal to "iMac (20-inch, Mid 2009)") or (marketingModelName is equal to "iMac (21.5-inch, Late 2011)")) then -- Special Budget/Education Models
			set bluetoothInfo to "Manufactured Without Bluetooth"
			set didGetBluetoothInfo to true
		end if
		
		set didGetDiscDriveInfo to false
		set discDriveDetected to "⚠️	NOT Detected  ⚠️
	‼️	CHECK “System Information” FOR DISC BURNING	‼️
	‼️	         CHECK IF A DISC DRIVE IS INSTALLED								 ‼️
	‼️	CHECK CONNECTIONS, REPLACE IF NECESSARY		‼️"
		
		if (((modelIdentifierName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 13)) or ((modelIdentifierName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 8)) or ((modelIdentifierName is equal to "MacBookPro") and (modelIdentifierMajorNumber ≥ 10)) or (modelIdentifierName is equal to "MacBookAir") or ((modelIdentifierName is equal to "Macmini") and (((offset of "Server" in marketingModelName) > 0) or (modelIdentifierMajorNumber ≥ 5))) or ((modelIdentifierName is equal to "MacPro") and (modelIdentifierMajorNumber ≥ 6)) or (modelIdentifierName is equal to "iMacPro") or (modelIdentifierName is equal to "Mac")) then
			set discDriveDetected to "N/A (Manufactured Without Disc Drive)"
			set didGetDiscDriveInfo to true
		end if
		
		set progress completed steps to (progress completed steps + 1)
		set systemProfilerIsRunning to ((do shell script ("ps -p " & systemProfilerPID & " > /dev/null 2>&1; echo $?")) as number)
		if (systemProfilerIsRunning is equal to 0) then
			try
				set hourGlass to "⌛️"
				repeat
					if (hourGlass is equal to "⏳") then
						set hourGlass to "⌛️"
					else
						set hourGlass to "⏳"
					end if
					set progress description to "
" & hourGlass & "	Gathering System Information"
					set systemProfilerIsRunning to ((do shell script ("ps -p " & systemProfilerPID & " > /dev/null 2>&1; echo $?")) as number)
					delay 0.5
					if (systemProfilerIsRunning is not equal to 0) then exit repeat
				end repeat
			on error (waitingForSystemProfilerMessage) number (waitingForSystemProfilerNumber)
				log "Waiting for System Profiler Error: " & waitingForSystemProfilerMessage
				do shell script "killall 'system_profiler'; rm -f " & (quoted form of restOfSystemOverviewInfoPath)
				if (waitingForSystemProfilerNumber is equal to -128) then
					quit
					delay 10
				end if
			end try
		end if
		
		
		try
			tell application id "com.apple.systemevents" to tell property list file restOfSystemOverviewInfoPath
				repeat with i from 1 to (number of property list items)
					set thisDataTypeProperties to (item i of property list items)
					set thisDataType to ((value of property list item "_dataType" of thisDataTypeProperties) as text)
					if (thisDataType is equal to "SPMemoryDataType") then -- MEMORY TYPE & SPEED INFORMATION
						try
							tell me
								set progress completed steps to (progress completed steps + 1)
								set progress description to "
📊	Loading Memory Information"
							end tell
							set memoryInfo to (first property list item of property list item "_items" of thisDataTypeProperties)
							if (isAppleSilicon) then
								set memoryNote to "
	🚫	RAM is Integrated With Chip (NOT Upgradeable)"
							else
								try
									set memoryUpgradeable to ((value of property list item "is_memory_upgradeable" of memoryInfo) as text)
									if (memoryUpgradeable is equal to "No") then set memoryNote to "
	🚫	RAM is Soldered Onboard (NOT Upgradeable)"
								end try
							end if
							try
								set memoryType to ((value of property list item "dimm_type" of memoryInfo) as text) -- This top level "Type" (not within any Banks), will only exist when running natively on Apple Silicon.
								set memoryType to (do shell script "echo " & (quoted form of memoryType) & " | tr -dc '[:alnum:]' | tr '[:lower:]' '[:upper:]'")
								set memorySpeed to ""
								set didGetMemoryInfo to true
							on error
								set memoryItems to (property list item "_items" of memoryInfo)
								repeat with j from 1 to (number of property list items in memoryItems)
									set thisMemoryItem to (property list item j of memoryItems)
									set thisMemoryType to ((value of property list item "dimm_type" of thisMemoryItem) as text)
									set thisMemorySlot to "Empty"
									if (thisMemoryType is not equal to "empty") then
										if (memoryType contains "UNKNOWN") then
											try
												set thisMemoryType to (do shell script "echo " & (quoted form of thisMemoryType) & " | sed 's/ SO-DIMM//'") -- Remove " SO-DIMM" suffix that exists on iMacs with DDR4 RAM.
												if (thisMemoryType contains "DDR") then set memoryType to thisMemoryType
											end try
											set memorySpeed to (" @ " & ((value of property list item "dimm_speed" of thisMemoryItem) as text))
										end if
										
										set thisMemorySlot to ((value of property list item "dimm_size" of thisMemoryItem) as text)
									end if
									
									set end of memorySlots to thisMemorySlot
								end repeat
								set didGetMemoryInfo to true
							end try
						on error (memoryInfoErrorMessage) number (memoryInfoErrorNumber)
							log "Memory Info Error: " & memoryInfoErrorMessage
							if (memoryInfoErrorNumber is equal to -128) then
								do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
								quit
								delay 10
							end if
						end try
					else if ((thisDataType is equal to "SPNVMeDataType") or (thisDataType is equal to "SPSerialATADataType")) then -- HARD DRIVE INFORMATION
						try
							tell me
								set progress completed steps to (progress completed steps + 1)
								set progress description to "
📁	Loading Storage Information"
							end tell
							set sataItems to (property list item "_items" of thisDataTypeProperties)
							repeat with j from 1 to (number of property list items in sataItems)
								set thisSataController to (property list item j of sataItems)
								set thisSataControllerName to ((value of property list item "_name" of thisSataController) as text)
								if (thisSataControllerName does not contain "Thunderbolt") then
									set thisSataControllerPortSataRevision to 0
									set thisSataControllerDriveSataRevision to 0
									
									if (thisDataType is equal to "SPSerialATADataType") then
										try
											set thisSataControllerPortSpeed to ((value of property list item "spsata_portspeed" of thisSataController) as text)
											
											if (thisSataControllerPortSpeed is equal to "6 Gigabit") then
												set thisSataControllerPortSataRevision to 3
											else if (thisSataControllerPortSpeed is equal to "3 Gigabit") then
												set thisSataControllerPortSataRevision to 2
											else if (thisSataControllerPortSpeed is equal to "1.5 Gigabit") then
												set thisSataControllerPortSataRevision to 1
											end if
											
											if (thisSataControllerPortSataRevision > maxSataRevision) then set maxSataRevision to thisSataControllerPortSataRevision
										end try
										
										try
											set thisSataControllerNegotiatedLinkSpeed to ((value of property list item "spsata_negotiatedlinkspeed" of thisSataController) as text)
											
											if (thisSataControllerNegotiatedLinkSpeed is equal to "6 Gigabit") then
												set thisSataControllerDriveSataRevision to 3
											else if (thisSataControllerNegotiatedLinkSpeed is equal to "3 Gigabit") then
												set thisSataControllerDriveSataRevision to 2
											else if (thisSataControllerNegotiatedLinkSpeed is equal to "1.5 Gigabit") then
												set thisSataControllerDriveSataRevision to 1
											end if
										end try
									end if
									
									set thisSataControllerItems to (property list item "_items" of thisSataController)
									repeat with k from 1 to (number of property list items in thisSataControllerItems)
										try
											set thisSataControllerItem to (property list item k of thisSataControllerItems)
											set thisDiskModelName to ((value of property list item "_name" of thisSataControllerItem) as text)
											set thisDiskID to ((value of property list item "bsd_name" of thisSataControllerItem) as text)
											set thisSataItemSizeBytes to ((value of property list item "size_in_bytes" of thisSataControllerItem) as number)
											
											if (thisDataType is equal to "SPNVMeDataType") then
												set thisSataItemMediumType to "NVMe SSD" -- NVMe drives are always Solid State
												
												if (macBookPro13inch2017PossibleSSDRecall) then
													set macBookPro13inch2017PossibleSSDRecall to (thisDiskModelName contains "AP0128J") or (thisDiskModelName contains "AP0256J") -- Recall only affects 128 GB and 265 GB drives (https://web.archive.org/web/20221208144358/https://support.apple.com/13-inch-macbook-pro-solid-state-drive-service)
												end if
											else
												set thisSataItemMediumType to ((value of property list item "spsata_medium_type" of thisSataControllerItem) as text)
											end if
											
											try
												set thisSataItemSmartStatus to ((value of property list item "smart_status" of thisSataControllerItem) as text)
											on error
												set thisSataItemSmartStatus to "Verified" -- Don't error if no Smart Status (Apple NVMe drives may not have Smart Status)
											end try
											
											if (thisSataItemSizeBytes is not equal to 0) then
												set ssdOrHdd to "⚠️ UNKNOWN Drive Type ⚠️"
												if (thisSataItemMediumType is equal to "Rotational") then
													set ssdOrHdd to "HDD"
												else if (thisSataItemMediumType is equal to "Solid State") then
													set ssdOrHdd to "SSD"
												else if (thisSataItemMediumType is equal to "NVMe SSD") then
													set ssdOrHdd to thisSataItemMediumType
												end if
												
												set incorrectDriveInstalledNote to ""
												if ((compatibleBladeSSDs is not equal to "") and (thisDiskModelName starts with "APPLE SSD")) then
													-- NOTE:
													--		An Apple 2.5" Laptop SSD also had model "APPLE SSD SM128E" so these models are not exclusive to Blade SSDs,
													--		which is why we're only checking these models if we know the Mac is compatible with a Blade SSD.
													--		Also, the Gen 5B "L" model is also used for the soldered on drives of at least 2016 MBPs.
													--
													-- Gen 1 Examples:
													--	64GB Toshiba: APPLE SSD TS064C
													--	256GB Samsung: APPLE SSD SM256C
													-- Gen 2B Examples:
													--	64GB Toshiba: APPLE SSD TS064E
													--	512GB Samsung: APPLE SSD SM512E
													-- Gen 2A Examples:
													--	128GB Samsung: APPLE SSD SM128E
													--	512GB SanDisk: APPLE SSD SD512E
													--	768GB Samsung: APPLE SSD SM768E
													-- Gen 3 Examples:
													--	128GB SanDisk: APPLE SSD SD0128F
													--	256GB Samsung: APPLE SSD SM0256F
													-- Gen 4A & 4B Examples:
													--	128GB Samsung: APPLE SSD SM0128G
													--	1TB Samsung: APPLE SSD SM1024G
													-- Gen 4C Examples:
													--	128GB: APPLE SSD AP0128H
													-- Gen 5A Examples:
													--	128GB: APPLE SSD AP0128J
													--	256GB: APPLE SSD SM0245L
													-- Gen 5B Examples:
													--	2TB: APPLE SSD SM2048L (https://www.ebay.com/itm/352638228107)
													
													set installedBladeSSD to ""
													if (thisDiskModelName ends with "C") then
														set installedBladeSSD to "1"
													else if (thisDiskModelName ends with "E") then
														if (shortModelName is equal to "MacBook Air") then -- Only MacBook Air's use the B form factor.
															set installedBladeSSD to "2B"
														else
															set installedBladeSSD to "2A"
														end if
													else if (thisDiskModelName ends with "F") then
														if (thisDiskModelName ends with "1024F") then -- Only the 1TB is B form factor
															set installedBladeSSD to "3B"
														else
															set installedBladeSSD to "3A"
														end if
													else if (thisDiskModelName ends with "G") then
														if (thisDiskModelName ends with "1024G") then -- Only the 1TB is B form factor
															set installedBladeSSD to "4B"
														else
															set installedBladeSSD to "4A"
														end if
													else if (thisDiskModelName ends with "H") then
														set installedBladeSSD to "4C"
													else if (thisDiskModelName ends with "J") then
														set installedBladeSSD to "5A"
													else if (thisDiskModelName ends with "L") then
														if ((modelIdentifierName is equal to "MacBookPro") and ((modelIdentifierMajorNumber = 14) and (modelIdentifierMinorNumber = 1))) then -- MacBookPro14,1 could have Model J or L drive (seen them ship with Model L later on).
															set installedBladeSSD to "5A"
														else
															set installedBladeSSD to "5B"
														end if
													end if
													
													if (installedBladeSSD is not equal to "") then
														set ssdOrHdd to ("Gen " & installedBladeSSD & " Blade " & ssdOrHdd)
														if (compatibleBladeSSDs does not contain installedBladeSSD) then set incorrectDriveInstalledNote to "
	⚠️	INCORRECT BLADE SSD INSTALLED  ⚠️"
													end if
												else if (thisSataControllerDriveSataRevision > 0) then
													if (thisSataControllerDriveSataRevision is equal to 3) then
														set ssdOrHdd to ("SATA III " & ssdOrHdd)
													else if (thisSataControllerDriveSataRevision is equal to 2) then
														set ssdOrHdd to ("SATA II " & ssdOrHdd)
													else if (thisSataControllerDriveSataRevision is equal to 1) then
														set ssdOrHdd to ("SATA I " & ssdOrHdd)
													else
														set ssdOrHdd to ("SATA " & thisSataControllerDriveSataRevision & " " & ssdOrHdd)
													end if
													
													if (thisSataControllerDriveSataRevision is not equal to thisSataControllerPortSataRevision) then
														if ((thisSataControllerDriveSataRevision is equal to 2) and (thisSataControllerPortSataRevision is equal to 3) and (thisSataItemMediumType is equal to "Rotational")) then
															set incorrectDriveInstalledNote to "
	👉	HDD NEGOTIATED TO SATA II (3 Gb/s) SPEED, BUT THAT'S OK  👍" -- https://discussions.apple.com/thread/250036019 & https://todo.freegeek.org/Ticket/Display.html?id=86977 & https://todo.freegeek.org/Ticket/Display.html?id=86981
														else
															set incorrectDriveInstalledNote to "
	⚠️	INCORRECT SATA DRIVE SPEED INSTALLED  ⚠️"
														end if
													end if
												end if
												
												set smartStatusWarning to ""
												if (thisSataItemSmartStatus is not equal to "Verified") then
													set smartStatusWarning to "
	⚠️	DRIVE S.M.A.R.T. STATUS IS NOT VERIFIED  ⚠️
	‼️		 S.M.A.R.T. STATUS IS “" & thisSataItemSmartStatus & "”			‼️
	‼️		   DRIVE MUST BE REPLACED			‼️"
												end if
												set (end of hardDriveDiskIDs) to thisDiskID
												set (end of hardDrivesList) to ((round (thisSataItemSizeBytes / 1.0E+9)) as text) & " GB (" & ssdOrHdd & ")" & incorrectDriveInstalledNote & smartStatusWarning
											end if
										on error number (storageInfoPlistErrorNumber)
											if (storageInfoPlistErrorNumber is equal to -128) then
												do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
												quit
												delay 10
											end if
										end try
									end repeat
								end if
							end repeat
							set didGetHardDriveInfo to true
						on error (storageInfoErrorMessage) number (storageInfoErrorNumber)
							set hardDriveDiskIDs to {}
							set hardDrivesList to {}
							log "Storage Info Error: " & storageInfoErrorMessage
							if (storageInfoErrorNumber is equal to -128) then
								do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
								quit
								delay 10
							end if
						end try
					else if (thisDataType is equal to "SPDisplaysDataType") then -- GRAPHICS INFORMATION
						try
							tell me
								set progress completed steps to (progress completed steps + 1)
								set progress description to "
👾	Loading Graphics Information"
							end tell
							set graphicsList to {}
							set graphicsItems to (property list item "_items" of thisDataTypeProperties)
							repeat with j from 1 to (number of property list items in graphicsItems)
								set thisGraphicsItem to (property list item j of graphicsItems)
								set AppleScript's text item delimiters to space
								set thisGraphicsModel to ((words of ((value of property list item "sppci_model" of thisGraphicsItem) as text)) as text)
								if (macProRecalledSerialDatePartsMatched and (macProRecalledGraphicsCards contains thisGraphicsModel)) then set macProPossibleBadGraphics to true
								set thisGraphicsBusRaw to "unknown"
								try
									set AppleScript's text item delimiters to "_"
									set thisGraphicsBusCodeParts to (every text item of ((value of property list item "sppci_bus" of thisGraphicsItem) as text))
									if ((count of thisGraphicsBusCodeParts) ≥ 2) then set thisGraphicsBusRaw to (text item 2 of thisGraphicsBusCodeParts)
								end try
								if (thisGraphicsBusRaw is equal to "builtin") then
									set thisGraphicsBus to "Built-In"
								else if (thisGraphicsBusRaw is equal to "pcie") then
									set thisGraphicsBus to "PCIe"
								else
									set thisGraphicsBus to (do shell script "echo " & (quoted form of thisGraphicsBusRaw) & " | tr '[:lower:]' '[:upper:]'")
								end if
								set thisGraphicsVRAM to "UNKNOWN"
								set thisGraphicsCores to "UNKNOWN"
								set thisGraphicsMemorySharedNote to ""
								try
									set thisGraphicsVRAM to ((value of property list item "spdisplays_vram_shared" of thisGraphicsItem) as text)
									set thisGraphicsMemorySharedNote to " - Shared"
								on error number (graphicsVRAMSharedErrorNumber)
									if (graphicsVRAMSharedErrorNumber is equal to -128) then
										do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
										quit
										delay 10
									end if
								end try
								try
									set thisGraphicsVRAM to ((value of property list item "spdisplays_vram" of thisGraphicsItem) as text)
								on error number (graphicsVRAMErrorNumber)
									if (graphicsVRAMErrorNumber is equal to -128) then
										do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
										quit
										delay 10
									end if
								end try
								try
									set thisGraphicsCores to ((value of property list item "sppci_cores" of thisGraphicsItem) as text)
								on error number (graphicsCoresErrorNumber)
									if (graphicsCoresErrorNumber is equal to -128) then
										do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
										quit
										delay 10
									end if
								end try
								if (thisGraphicsVRAM is not equal to "UNKNOWN") then
									set graphicsMemoryParts to (words of thisGraphicsVRAM)
									if ((((item 2 of graphicsMemoryParts) as text) is equal to "MB") and (((item 1 of graphicsMemoryParts) as number) ≥ 1024)) then
										set graphicsMemoryGB to (((item 1 of graphicsMemoryParts) / 1024) as text)
										if ((text -2 thru -1 of graphicsMemoryGB) is equal to ".0") then set graphicsMemoryGB to (text 1 thru -3 of graphicsMemoryGB)
										set thisGraphicsVRAM to graphicsMemoryGB & " GB"
									end if
								end if
								set thisGraphicsInfo to ""
								if (thisGraphicsBus is not equal to "UNKNOWN") then set thisGraphicsInfo to thisGraphicsBus & ": "
								if (thisGraphicsCores is equal to "UNKNOWN") then -- Apple Silicon GPU will list Cores and NO VRAM
									set thisGraphicsInfo to thisGraphicsInfo & thisGraphicsModel & " (" & thisGraphicsVRAM & thisGraphicsMemorySharedNote & ")"
								else
									set thisGraphicsInfo to thisGraphicsInfo & thisGraphicsModel & " (" & thisGraphicsCores & " Cores)"
								end if
								if (thisGraphicsBus is equal to "Built-In") then
									set (beginning of graphicsList) to thisGraphicsInfo
								else
									set (end of graphicsList) to thisGraphicsInfo
								end if
							end repeat
							if ((count of graphicsList) is equal to 0) then error "No Graphics Found"
							set AppleScript's text item delimiters to (linefeed & tab)
							set graphicsInfo to (graphicsList as text)
							set AppleScript's text item delimiters to {"Intel ", "NVIDIA ", "AMD "}
							set graphicsInfoPartsWithoutBrands to (every text item of graphicsInfo)
							set AppleScript's text item delimiters to ""
							set graphicsInfo to (graphicsInfoPartsWithoutBrands as text)
							set didGetGraphicsInfo to true
						on error (graphicsInfoErrorMessage) number (graphicsInfoErrorNumber)
							log "Graphics Info Error: " & graphicsInfoErrorMessage
							if (graphicsInfoErrorNumber is equal to -128) then
								do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
								quit
								delay 10
							end if
						end try
					else if (thisDataType is equal to "SPAirPortDataType") then -- WI-FI INFORMATION
						try
							tell me
								set progress completed steps to (progress completed steps + 1)
								set progress description to "
📡	Loading Wireless Information"
							end tell
							set wiFiProtocolsList to {}
							set wiFiItems to (first property list item of property list item "_items" of thisDataTypeProperties)
							set wiFiInterfaces to (property list item "spairport_airport_interfaces" of wiFiItems)
							repeat with j from 1 to (number of property list items in wiFiInterfaces)
								set thisWiFiInterface to (property list item j of wiFiInterfaces)
								try -- The spairport_airport_interfaces array has 2 items on Monterey and only one of them contains spairport_status_information etc.
									set wiFiStatus to ((value of property list item "spairport_status_information" of thisWiFiInterface) as text)
									if (wiFiStatus is not equal to "spairport_status_connected") then
										set wiFiInfo to "Wi-Fi Detected (⚠️ UNKNOWN Versions/Protocols - Wi-Fi DISABLED ⚠️)
	‼️	ENABLE WI-FI AND RELOAD  ‼️"
									end if
									set possibleWiFiProtocols to (words of ((value of property list item "spairport_supported_phymodes" of thisWiFiInterface) as text))
									repeat with thisPossibleWiFiProtocol in possibleWiFiProtocols
										set thisWiFiVersionAndProtocol to (thisPossibleWiFiProtocol as text)
										if (thisWiFiVersionAndProtocol is not equal to "802.11") then
											if (thisWiFiVersionAndProtocol is equal to "b") then
												set thisWiFiVersionAndProtocol to ("1/" & thisWiFiVersionAndProtocol)
											else if (thisWiFiVersionAndProtocol is equal to "a") then
												set thisWiFiVersionAndProtocol to ("2/" & thisWiFiVersionAndProtocol)
											else if (thisWiFiVersionAndProtocol is equal to "g") then
												set thisWiFiVersionAndProtocol to ("3/" & thisWiFiVersionAndProtocol)
											else if (thisWiFiVersionAndProtocol is equal to "n") then
												set thisWiFiVersionAndProtocol to ("4/" & thisWiFiVersionAndProtocol)
											else if (thisWiFiVersionAndProtocol is equal to "ac") then
												set thisWiFiVersionAndProtocol to ("5/" & thisWiFiVersionAndProtocol)
											else if (thisWiFiVersionAndProtocol is equal to "ax") then
												set thisWiFiVersionAndProtocol to ("6/" & thisWiFiVersionAndProtocol)
											else if (thisWiFiVersionAndProtocol is equal to "be") then
												set thisWiFiVersionAndProtocol to ("7/" & thisWiFiVersionAndProtocol)
											end if
											if (wiFiProtocolsList does not contain thisWiFiVersionAndProtocol) then
												set (end of wiFiProtocolsList) to thisWiFiVersionAndProtocol
											end if
										end if
									end repeat
								end try
							end repeat
							
							if ((count of wiFiProtocolsList) > 0) then
								set lastWiFiProtocol to ""
								if ((count of wiFiProtocolsList) > 1) then
									set AppleScript's text item delimiters to linefeed
									set wiFiProtocolsList to (paragraphs of (do shell script ("echo " & (quoted form of (wiFiProtocolsList as text)) & " | sort -V")))
									set lastWiFiProtocol to (last item of wiFiProtocolsList)
									set wiFiProtocolsList to (reverse of (rest of (reverse of wiFiProtocolsList)))
								end if
								set AppleScript's text item delimiters to ", "
								set wiFiProtocolsString to (wiFiProtocolsList as text)
								if (lastWiFiProtocol is not equal to "") then
									set commaAndOrJustAnd to ", and "
									if ((count of wiFiProtocolsList) = 1) then set commaAndOrJustAnd to " and "
									set wiFiProtocolsString to wiFiProtocolsString & commaAndOrJustAnd & lastWiFiProtocol
								end if
								
								set wiFiInfo to "Wi-Fi Detected (Supports " & wiFiProtocolsString & ")"
							else
								error "No Wi-Fi Versions/Protocols Detected"
							end if
							set didGetWiFiInfo to true
						on error (wiFiInfoErrorMessage) number (wiFiInfoErrorNumber)
							log "Wi-Fi Info Error: " & wiFiInfoErrorMessage
							if (wiFiInfoErrorNumber is equal to -128) then
								do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
								quit
								delay 10
							end if
						end try
					else if (thisDataType is equal to "SPBluetoothDataType") then -- BLUETOOTH INFORMATION
						try
							tell me
								set progress completed steps to (progress completed steps + 1)
								set progress description to "
📡	Loading Wireless Information"
							end tell
							set bluetoothSupportedFeaturesList to {}
							set bluetoothItems to (first property list item of property list item "_items" of thisDataTypeProperties)
							try
								set bluetoothInfo to (property list item "local_device_title" of bluetoothItems)
								set bluetoothVersion to ((first word of ((value of property list item "general_hci_version" of bluetoothInfo) as text)) as text)
								if (bluetoothVersion starts with "0x") then set bluetoothVersion to ((first word of ((value of property list item "general_lmp_version" of bluetoothInfo) as text)) as text)
								if (bluetoothVersion is equal to "0x9") then set bluetoothVersion to "5.0" -- BT 5.0 will not be detected properly on High Sierra.
								try
									set bluetoothLEsupported to ((value of property list item "general_supports_lowEnergy" of bluetoothInfo) as text)
									if (bluetoothLEsupported is equal to "attrib_Yes") then set (end of bluetoothSupportedFeaturesList) to "BLE"
								end try
								try
									set bluetoothHandoffSupported to ((value of property list item "general_supports_handoff" of bluetoothInfo) as text)
									if (bluetoothHandoffSupported is equal to "attrib_Yes") then set (end of bluetoothSupportedFeaturesList) to "Handoff"
								end try
								set bluetoothInfo to "Bluetooth " & bluetoothVersion & " Detected"
								set didGetBluetoothInfo to true
							on error
								set bluetoothInfo to (property list item "controller_properties" of bluetoothItems)
								set bluetoothChipset to ((value of property list item "controller_chipset" of bluetoothInfo) as text)
								if (bluetoothChipset is not equal to "") then
									-- For some strange reason, detailed Bluetooth information no longer exists in Monterey, can only detect if it is present.
									-- BUT, I wrote a script (https://github.com/freegeek-pdx/macOS-Testing-and-Deployment-Scripts/blob/main/Other%20Scripts/get_bluetooth_from_all_mac_specs_pages.sh) to extract every Bluetooth version from every specs URL to be able to know what version this model has if Bluetooth is detected.
									
									-- Bluetooth Model IDs Last Updated: 10/27/25
									if ({"Mac14,2", "Mac14,3", "Mac14,5", "Mac14,6", "Mac14,8", "Mac14,9", "Mac14,10", "Mac14,12", "Mac14,13", "Mac14,14", "Mac14,15", "Mac15,3", "Mac15,4", "Mac15,5", "Mac15,6", "Mac15,7", "Mac15,8", "Mac15,9", "Mac15,10", "Mac15,11", "Mac15,12", "Mac15,13", "Mac15,14", "Mac16,1", "Mac16,2", "Mac16,3", "Mac16,5", "Mac16,6", "Mac16,7", "Mac16,8", "Mac16,9", "Mac16,10", "Mac16,11", "Mac16,12", "Mac16,13", "Mac17,2"} contains modelIdentifier) then
										set bluetoothInfo to "Bluetooth 5.3 Detected"
										set (end of bluetoothSupportedFeaturesList) to "BLE"
										set (end of bluetoothSupportedFeaturesList) to "Handoff"
									else if ({"Mac13,1", "Mac13,2", "Mac14,7", "MacBookAir9,1", "MacBookAir10,1", "MacBookPro15,1", "MacBookPro15,2", "MacBookPro15,3", "MacBookPro15,4", "MacBookPro16,1", "MacBookPro16,2", "MacBookPro16,3", "MacBookPro16,4", "MacBookPro17,1", "MacBookPro18,1", "MacBookPro18,2", "MacBookPro18,3", "MacBookPro18,4", "MacPro7,1", "Macmini8,1", "Macmini9,1", "iMac20,1", "iMac20,2", "iMac21,1", "iMac21,2", "iMacPro1,1"} contains modelIdentifier) then
										set bluetoothInfo to "Bluetooth 5.0 Detected"
										set (end of bluetoothSupportedFeaturesList) to "BLE"
										set (end of bluetoothSupportedFeaturesList) to "Handoff"
									else if ({"MacBook10,1", "MacBookAir8,1", "MacBookAir8,2", "MacBookPro11,4", "MacBookPro11,5", "MacBookPro13,1", "MacBookPro13,2", "MacBookPro13,3", "MacBookPro14,1", "MacBookPro14,2", "MacBookPro14,3", "iMac18,1", "iMac18,2", "iMac18,3", "iMac19,1", "iMac19,2"} contains modelIdentifier) then
										set bluetoothInfo to "Bluetooth 4.2 Detected"
										set (end of bluetoothSupportedFeaturesList) to "BLE"
										set (end of bluetoothSupportedFeaturesList) to "Handoff" -- All Bluetooth 4.2 and newer models support Handoff
									else if ({"MacBook8,1", "MacBook9,1", "MacBookAir4,1", "MacBookAir4,2", "MacBookAir5,1", "MacBookAir5,2", "MacBookAir6,1", "MacBookAir6,2", "MacBookAir7,1", "MacBookAir7,2", "MacBookPro9,1", "MacBookPro9,2", "MacBookPro10,1", "MacBookPro10,2", "MacBookPro11,1", "MacBookPro11,2", "MacBookPro11,3", "MacBookPro12,1", "MacPro6,1", "Macmini5,1", "Macmini5,2", "Macmini5,3", "Macmini6,1", "Macmini6,2", "Macmini7,1", "iMac13,1", "iMac13,2", "iMac14,1", "iMac14,2", "iMac14,4", "iMac15,1", "iMac16,1", "iMac16,2", "iMac17,1"} contains modelIdentifier) then
										-- SOME of these models with Bluetooth 4.0 DON'T support Monterey, but it would be more effor to not include them.
										set bluetoothInfo to "Bluetooth 4.0 Detected"
										set (end of bluetoothSupportedFeaturesList) to "BLE" -- All Bluetooth 4.0 and above is BLE
										if ({"MacBookAir4,1", "MacBookAir4,2", "Macmini5,1", "Macmini5,2", "Macmini5,3"} does not contain modelIdentifier) then
											set bluetoothHandoff to true -- Most Bluetooth 4.0 models support Handoff, but some early models don't, so show support for all EXCEPT those models: https://support.apple.com/en-us/HT204689
										end if
									else if ({"MacBook5,2", "MacBook6,1", "MacBook7,1", "MacBookAir2,1", "MacBookAir3,1", "MacBookAir3,2", "MacBookPro4,1", "MacBookPro5,1", "MacBookPro5,2", "MacBookPro5,3", "MacBookPro5,5", "MacBookPro6,1", "MacBookPro6,2", "MacBookPro7,1", "MacBookPro8,1", "MacBookPro8,2", "MacBookPro8,3", "MacPro4,1", "MacPro5,1", "Macmini3,1", "Macmini4,1", "iMac9,1", "iMac10,1", "iMac11,2", "iMac11,3", "iMac12,1", "iMac12,2"} contains modelIdentifier) then
										-- NONE of these models with Bluetooth 2.1 (plus EDR) support Monterey, but it's no extra effort to include them anyways.
										set bluetoothInfo to "Bluetooth 2.1 Detected"
									else
										set bluetoothInfo to "Bluetooth Detected"
									end if
									
									set didGetBluetoothInfo to true
								end if
							end try
							
							if (didGetBluetoothInfo) then
								set bluetoothSupportedFeatures to ""
								if ((count of bluetoothSupportedFeaturesList) > 0) then
									set AppleScript's text item delimiters to ", "
									set bluetoothSupportedFeatures to " (Supports " & (bluetoothSupportedFeaturesList as text) & ")"
								end if
								set bluetoothInfo to (bluetoothInfo & bluetoothSupportedFeatures)
							end if
						on error (bluetoothInfoErrorMessage) number (bluetoothInfoErrorNumber)
							log "Bluetooth Info Error: " & bluetoothInfoErrorMessage
							if (bluetoothInfoErrorNumber is equal to -128) then
								do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
								quit
								delay 10
							end if
						end try
					else if (thisDataType is equal to "SPDiscBurningDataType") then -- DISC DRIVE INFORMATION
						try
							tell me
								set progress completed steps to (progress completed steps + 1)
								set progress description to "
📀	Loading Disc Drive Information"
							end tell
							set discWriteTypesList to {}
							set discDriveItems to (first property list item of property list item "_items" of thisDataTypeProperties)
							try
								if (((value of property list item "device_cdwrite" of discDriveItems) as text) is not equal to "") then set (end of discWriteTypesList) to "CDs"
							on error number (checkForCDErrorNumber)
								if (checkForCDErrorNumber is equal to -128) then
									do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
									quit
									delay 10
								end if
							end try
							try
								if (((value of property list item "device_dvdwrite" of discDriveItems) as text) is not equal to "") then set (end of discWriteTypesList) to "DVDs"
							on error number (checkForDVDErrorNumber)
								if (checkForDVDErrorNumber is equal to -128) then
									do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
									quit
									delay 10
								end if
							end try
							try
								if (((value of property list item "device_bdwrite" of discDriveItems) as text) is not equal to "") then set (end of discWriteTypesList) to "Blu-rays"
							on error number (checkForBluRayErrorNumber)
								if (checkForBluRayErrorNumber is equal to -128) then
									do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
									quit
									delay 10
								end if
							end try
							if ((count of discWriteTypesList) > 0) then
								set AppleScript's text item delimiters to ", "
								set discDriveDetected to "Detected (Supports Reading & Writing " & (discWriteTypesList as text) & ")"
								
								if ((discWriteTypesList does not contain "CDs") or (discWriteTypesList does not contain "DVDs")) then
									set discDriveDetected to discDriveDetected & "
	⚠️	Writing CDs & DVDs is NOT SUPPORTED  ⚠️
	‼️	DISC DRIVE MUST BE REPLACED  ‼️"
								end if
							end if
							set didGetDiscDriveInfo to true
						on error (discDriveInfoErrorMessage) number (discDriveInfoErrorNumber)
							log "Disc Drive Info Error: " & discDriveInfoErrorMessage
							if (discDriveInfoErrorNumber is equal to -128) then
								do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
								quit
								delay 10
							end if
						end try
					else if (thisDataType is equal to "SPPowerDataType") then -- BATTERY HEALTH INFORMATION
						try
							set powerItems to (property list item "_items" of thisDataTypeProperties)
							repeat with j from 1 to (number of property list items in powerItems)
								set thisPowerItem to (property list item j of powerItems)
								try
									set batteryCondition to ((value of property list item "sppower_battery_health" of property list item "sppower_battery_health_info" of thisPowerItem) as text)
									if (batteryCondition is not equal to "Good") then -- https://support.apple.com/HT204054#battery
										set batteryHealth to batteryHealth & "
	⚠️	BATTERY CONDITION IS NOT NORMAL  ⚠️
	‼️	CONDITION IS “" & batteryCondition & "”  ‼️"
									end if
									set didGetBatteryHealthInfo to true
									exit repeat
								end try
							end repeat
						on error (batteryHealthInfoErrorMessage) number (batteryHealthInfoErrorNumber)
							log "Battery Health Info Error: " & batteryHealthInfoErrorMessage
							if (batteryHealthInfoErrorNumber is equal to -128) then
								do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
								quit
								delay 10
							end if
						end try
					end if
				end repeat
			end tell
		on error (restOfSystemOverviewInfoErrorMessage) number (restOfSystemOverviewInfoErrorNumber)
			log "Rest of System Overview Info Error: " & restOfSystemOverviewInfoErrorMessage
			do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
			if (restOfSystemOverviewInfoErrorNumber is equal to -128) then
				quit
				delay 10
			end if
		end try
		do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
		
		if ((count of hardDrivesList) > 0) then
			set AppleScript's text item delimiters to (linefeed & tab)
			set storageInfo to (hardDrivesList as text)
		end if
		
		if (not didGetMemoryInfo) then
			set memoryNote to "
	‼️	CHECK “System Information” FOR MEMORY  ‼️"
			set showSystemInfoAppButton to true
		end if
		
		
		-- ADD DRIVE COMPATIBILITY & SSD RECALL NOTES
		
		set sataCompatibilityNote to ""
		if (maxSataRevision > 0) then
			set sataCompatibilityNote to "
	👉	Drive Compatibility: SATA "
			
			if (maxSataRevision is equal to 3) then
				set sataCompatibilityNote to (sataCompatibilityNote & "III (6 Gb/s)")
			else if (maxSataRevision is equal to 2) then
				set sataCompatibilityNote to (sataCompatibilityNote & "II (3 Gb/s)")
			else if (maxSataRevision is equal to 1) then
				set sataCompatibilityNote to (sataCompatibilityNote & "I (1.5 Gb/s)")
			else
				set sataCompatibilityNote to (sataCompatibilityNote & maxSataRevision & " (❓ Gb/s)")
			end if
		end if
		
		if (compatibleBladeSSDs is not equal to "") then
			set bladeSSDnote to ""
			if ((shortModelName is equal to "iMac") and ((offset of "21.5" in marketingModelName) > 0)) then
				set bladeSSDnote to "
	☝️	Blade SSD connection will only exist if
		this 21.5” iMac was originally configured
		with a Fusion Drive or standalone SSD."
			else if (shortModelName is equal to "Mac mini") then
				set bladeSSDnote to "
	☝️	Required Flex Cable for Blade SSD connection will
		only exist if this Mac mini was originally configured 
		with a Fusion Drive or standalone SSD. Although,
		this “Mac mini PCIe SSD Cable” can be purchased."
			end if
			
			if ((not isLaptop) and (sataCompatibilityNote is not equal to "")) then -- iMac's and latest Mac Pro's could have both Blades and SATA drives.
				set storageInfo to storageInfo & sataCompatibilityNote
			end if
			
			set storageInfo to storageInfo & "
	👉	Blade SSD Compatibility: " & compatibleBladeSSDs & bladeSSDnote
		else if (sataCompatibilityNote is not equal to "") then
			set storageInfo to storageInfo & sataCompatibilityNote
		end if
		
		if (macBookPro13inch2017PossibleSSDRecall) then
			set storageInfo to storageInfo & "
	⚠️	SSD MAY BE RECALLED FOR REPAIR  ⚠️
	‼️	CHECK SERIAL NUMBER ON APPLE'S SSD RECALL PAGE  ‼️"
		end if
		
		
		if (not didGetGraphicsInfo) then
			set showSystemInfoAppButton to true
		end if
		
		if (macBookProPossibleBadGraphics or iMacPossibleBadGraphics or macProPossibleBadGraphics) then
			set graphicsInfo to graphicsInfo & "
	⚠️	GPU RECALLED FOR REPAIR  ⚠️
	‼️	A LONGER GPU STRESS TEST WILL RUN  ‼️"
		end if
		
		
		if (not didGetWiFiInfo or ((offset of "System Information" in wiFiInfo) > 0)) then
			set showSystemInfoAppButton to true
		end if
		
		set progress completed steps to (progress completed steps + 1)
		if (not didGetBluetoothInfo) then
			set progress description to "
📡	Loading Wireless Information"
			
			-- BLUETOOTH INFORMATION AGAIN SINCE IT SEEMS TO NOT LOAD EVERYTIME WHEN LAUNCHED AT LOGIN
			
			try
				do shell script "system_profiler -xml SPBluetoothDataType > " & (quoted form of bluetoothInfoPath)
				tell application id "com.apple.systemevents" to tell property list file bluetoothInfoPath
					set bluetoothSupportedFeaturesList to {}
					set bluetoothItems to (first property list item of property list item "_items" of first property list item)
					try
						set bluetoothInfo to (property list item "local_device_title" of bluetoothItems)
						set bluetoothVersion to ((first word of ((value of property list item "general_hci_version" of bluetoothInfo) as text)) as text)
						if (bluetoothVersion starts with "0x") then set bluetoothVersion to ((first word of ((value of property list item "general_lmp_version" of bluetoothInfo) as text)) as text)
						if (bluetoothVersion is equal to "0x9") then set bluetoothVersion to "5.0" -- BT 5.0 will not be detected properly on High Sierra.
						try
							set bluetoothLEsupported to ((value of property list item "general_supports_lowEnergy" of bluetoothInfo) as text)
							if (bluetoothLEsupported is equal to "attrib_Yes") then set (end of bluetoothSupportedFeaturesList) to "BLE"
						end try
						try
							set bluetoothHandoffSupported to ((value of property list item "general_supports_handoff" of bluetoothInfo) as text)
							if (bluetoothHandoffSupported is equal to "attrib_Yes") then set (end of bluetoothSupportedFeaturesList) to "Handoff"
						end try
						set bluetoothInfo to "Bluetooth " & bluetoothVersion & " Detected"
					on error -- For some strange reason, detailed Bluetooth information no longer exists in Monterey, can only detect if it is present.
						set bluetoothInfo to (property list item "controller_properties" of bluetoothItems)
						set bluetoothChipset to ((value of property list item "controller_chipset" of bluetoothInfo) as text)
						if (bluetoothChipset is not equal to "") then
							-- For some strange reason, detailed Bluetooth information no longer exists in Monterey, can only detect if it is present.
							-- BUT, I wrote a script (https://github.com/freegeek-pdx/macOS-Testing-and-Deployment-Scripts/blob/main/Other%20Scripts/get_bluetooth_from_all_mac_specs_pages.sh) to extract every Bluetooth version from every specs URL to be able to know what version this model has if Bluetooth is detected.
							
							-- Bluetooth Model IDs Last Updated: 10/27/25
							if ({"Mac14,2", "Mac14,3", "Mac14,5", "Mac14,6", "Mac14,8", "Mac14,9", "Mac14,10", "Mac14,12", "Mac14,13", "Mac14,14", "Mac14,15", "Mac15,3", "Mac15,4", "Mac15,5", "Mac15,6", "Mac15,7", "Mac15,8", "Mac15,9", "Mac15,10", "Mac15,11", "Mac15,12", "Mac15,13", "Mac15,14", "Mac16,1", "Mac16,2", "Mac16,3", "Mac16,5", "Mac16,6", "Mac16,7", "Mac16,8", "Mac16,9", "Mac16,10", "Mac16,11", "Mac16,12", "Mac16,13", "Mac17,2"} contains modelIdentifier) then
								set bluetoothInfo to "Bluetooth 5.3 Detected"
								set (end of bluetoothSupportedFeaturesList) to "BLE"
								set (end of bluetoothSupportedFeaturesList) to "Handoff"
							else if ({"Mac13,1", "Mac13,2", "Mac14,7", "MacBookAir9,1", "MacBookAir10,1", "MacBookPro15,1", "MacBookPro15,2", "MacBookPro15,3", "MacBookPro15,4", "MacBookPro16,1", "MacBookPro16,2", "MacBookPro16,3", "MacBookPro16,4", "MacBookPro17,1", "MacBookPro18,1", "MacBookPro18,2", "MacBookPro18,3", "MacBookPro18,4", "MacPro7,1", "Macmini8,1", "Macmini9,1", "iMac20,1", "iMac20,2", "iMac21,1", "iMac21,2", "iMacPro1,1"} contains modelIdentifier) then
								set bluetoothInfo to "Bluetooth 5.0 Detected"
								set (end of bluetoothSupportedFeaturesList) to "BLE"
								set (end of bluetoothSupportedFeaturesList) to "Handoff"
							else if ({"MacBook10,1", "MacBookAir8,1", "MacBookAir8,2", "MacBookPro11,4", "MacBookPro11,5", "MacBookPro13,1", "MacBookPro13,2", "MacBookPro13,3", "MacBookPro14,1", "MacBookPro14,2", "MacBookPro14,3", "iMac18,1", "iMac18,2", "iMac18,3", "iMac19,1", "iMac19,2"} contains modelIdentifier) then
								set bluetoothInfo to "Bluetooth 4.2 Detected"
								set (end of bluetoothSupportedFeaturesList) to "BLE"
								set (end of bluetoothSupportedFeaturesList) to "Handoff" -- All Bluetooth 4.2 and newer models support Handoff
							else if ({"MacBook8,1", "MacBook9,1", "MacBookAir4,1", "MacBookAir4,2", "MacBookAir5,1", "MacBookAir5,2", "MacBookAir6,1", "MacBookAir6,2", "MacBookAir7,1", "MacBookAir7,2", "MacBookPro9,1", "MacBookPro9,2", "MacBookPro10,1", "MacBookPro10,2", "MacBookPro11,1", "MacBookPro11,2", "MacBookPro11,3", "MacBookPro12,1", "MacPro6,1", "Macmini5,1", "Macmini5,2", "Macmini5,3", "Macmini6,1", "Macmini6,2", "Macmini7,1", "iMac13,1", "iMac13,2", "iMac14,1", "iMac14,2", "iMac14,4", "iMac15,1", "iMac16,1", "iMac16,2", "iMac17,1"} contains modelIdentifier) then
								-- SOME of these models with Bluetooth 4.0 DON'T support Monterey, but it would be more effor to not include them.
								set bluetoothInfo to "Bluetooth 4.0 Detected"
								set (end of bluetoothSupportedFeaturesList) to "BLE" -- All Bluetooth 4.0 and above is BLE
								if ({"MacBookAir4,1", "MacBookAir4,2", "Macmini5,1", "Macmini5,2", "Macmini5,3"} does not contain modelIdentifier) then
									set bluetoothHandoff to true -- Most Bluetooth 4.0 models support Handoff, but some early models don't, so show support for all EXCEPT those models: https://support.apple.com/en-us/HT204689
								end if
							else if ({"MacBook5,2", "MacBook6,1", "MacBook7,1", "MacBookAir2,1", "MacBookAir3,1", "MacBookAir3,2", "MacBookPro4,1", "MacBookPro5,1", "MacBookPro5,2", "MacBookPro5,3", "MacBookPro5,5", "MacBookPro6,1", "MacBookPro6,2", "MacBookPro7,1", "MacBookPro8,1", "MacBookPro8,2", "MacBookPro8,3", "MacPro4,1", "MacPro5,1", "Macmini3,1", "Macmini4,1", "iMac9,1", "iMac10,1", "iMac11,2", "iMac11,3", "iMac12,1", "iMac12,2"} contains modelIdentifier) then
								-- NONE of these models with Bluetooth 2.1 (plus EDR) support Monterey, but it's no extra effort to include them anyways.
								set bluetoothInfo to "Bluetooth 2.1 Detected"
							else
								set bluetoothInfo to "Bluetooth Detected"
							end if
							
							set didGetBluetoothInfo to true
						end if
					end try
					
					if (didGetBluetoothInfo) then
						set bluetoothSupportedFeatures to ""
						if ((count of bluetoothSupportedFeaturesList) > 0) then
							set AppleScript's text item delimiters to ", "
							set bluetoothSupportedFeatures to " (Supports " & (bluetoothSupportedFeaturesList as text) & ")"
						end if
						set bluetoothInfo to (bluetoothInfo & bluetoothSupportedFeatures)
					end if
				end tell
			on error (bluetoothInfoErrorMessage) number (bluetoothInfoErrorNumber)
				log "Bluetooth Info Error: " & bluetoothInfoErrorMessage
				do shell script "rm -f " & (quoted form of bluetoothInfoPath)
				if (bluetoothInfoErrorNumber is equal to -128) then
					quit
					delay 10
				end if
				set showSystemInfoAppButton to true
			end try
			do shell script "rm -f " & (quoted form of bluetoothInfoPath)
		end if
		
		
		if (not didGetDiscDriveInfo) then
			set showSystemInfoAppButton to true
		end if
		
		
		if (isLaptop and (not didGetBatteryHealthInfo) and ((offset of "⚠️" in batteryHealth) = 0)) then
			set batteryHealth to batteryHealth & "
	⚠️	UNKNOWN Battery Health Condition  ⚠️
	‼️	CHECK “System Information” FOR BATTERY HEALTH  ‼️"
			set showSystemInfoAppButton to true
		end if
		
		if (didGetHardwareInfo and didGetMemoryInfo and didGetGraphicsInfo) then
			exit repeat
		else
			delay 1 -- Wait and try again if these critical things didn't load
		end if
	end repeat
	
	if (not isBigSurOrNewer) then set progress total steps to -1 -- There is a bug in Big Sur where setting indeterminate progress AFTER determinate progress has been shown just displays 0 progress, so leave it full instead.
	
	if ((serialNumber is not equal to "") and (serialNumber is not equal to "UNKNOWNXXXXX")) then
		try
			((infoPlistPath as POSIX file) as alias) -- Only check DEP status when exported as an app to make debugging faster.
			
			do shell script "ping -t 5 -c 1 www.apple.com" -- Only try to get DEP status if we have internet.
			
			repeat
				set progress description to "
🔒	Checking for Remote Management"
				delay 0.5
				
				set checkRemoteManagedMacsLogCommand to ("curl --connect-timeout 5 -sfL " & (quoted form of "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED CHECK REMOTE MANAGED MACS LOG URL]") & " --data-urlencode " & (quoted form of ("serial=" & serialNumber)))
				set remoteManagedMacIsAlreadyLogged to false
				try
					set remoteManagedMacIsAlreadyLogged to ((do shell script checkRemoteManagedMacsLogCommand) is equal to "ALREADY LOGGED")
				end try
				
				set remoteManagementOutput to ""
				try
					try
						set remoteManagementOutput to (do shell script "profiles renew -type enrollment; profiles show -type enrollment 2>&1; exit 0" user name adminUsername password adminPassword with administrator privileges)
					on error profilesShowDefaultUserErrorMessage number profilesShowDefaultUserErrorNumber
						if (profilesShowDefaultUserErrorNumber is not equal to -60007) then error profilesShowDefaultUserErrorMessage number profilesShowDefaultUserErrorNumber
						try
							activate
						end try
						display alert "Would you like to check for
Remote Management (ADE/DEP/MDM)?" message "Remote Management check will be skipped in 10 seconds." buttons {"No", "Yes"} cancel button 1 default button 2 giving up after 10
						if (gave up of result) then error number -128
						set remoteManagementOutput to (do shell script "profiles renew -type enrollment; profiles show -type enrollment 2>&1; exit 0" with prompt "Administrator Permission is required
to check for Remote Management (ADE/DEP/MDM)." with administrator privileges)
					end try
				end try
				
				if (remoteManagementOutput contains " - Request too soon.") then -- macOS 12.3 adds client side "profiles show" rate limiting of once every 23 hours: https://derflounder.wordpress.com/2022/03/22/profiles-command-includes-client-side-rate-limitation-for-certain-functions-on-macos-12-3/
					try
						set remoteManagementOutput to (do shell script ("cat " & (quoted form of (buildInfoPath & ".fgLastRemoteManagementCheckOutput"))))
					end try
				else if (remoteManagementOutput is not equal to "") then -- So always cache the last "profiles show" output so we can show the last valid results in case it's checked again within 23 hours.
					try
						do shell script ("mkdir " & (quoted form of buildInfoPath))
					end try
					try
						do shell script ("echo " & (quoted form of remoteManagementOutput) & " > " & (quoted form of (buildInfoPath & ".fgLastRemoteManagementCheckOutput"))) with administrator privileges -- DO NOT specify username and password in case it was prompted for. This will still work within 5 minutes of the last authenticated admin permissions run though.
					end try
				end if
				
				if (remoteManagementOutput contains " - Request too soon.") then -- Don't show success if rate limited and there was no previous cached output to use.
					set progress description to "
❌	UNABLE to Check for Remote Management"
					try
						activate
					end try
					try
						do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
					end try
					set nextAllowedProfilesShowTime to "23 hours after last successful check"
					try
						set nextAllowedProfilesShowTime to ("at " & (do shell script "date -jv +23H -f '%FT%TZ %z' \"$(plutil -extract lastProfilesShowFetchTime raw /private/var/db/ConfigurationProfiles/Settings/.profilesFetchTimerCheck) +0000\" '+%-I:%M:%S %p on %D'"))
					end try
					display alert ("Unable to Check Remote Management Because of Once Every 23 Hours Rate Limiting

Next check will be allowed " & nextAllowedProfilesShowTime & ".") message "This should not have happened, please inform Free Geek I.T." as critical
					
					exit repeat
				else if (remoteManagementOutput is not equal to "") then
					try
						set remoteManagementOutputParts to (paragraphs of remoteManagementOutput)
						
						if ((count of remoteManagementOutputParts) > 3) then
							set progress description to "
⚠️	Remote Management IS Enabled"
							set remoteManagementOrganizationName to "Unknown Organization"
							set remoteManagementOrganizationContactInfo to {}
							
							set logRemoteManagedMacCommand to ("curl --connect-timeout 5 -sfL " & (quoted form of "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED LOG REMOTE MANAGED MAC URL]") & " --data-urlencode " & (quoted form of ("source=" & (name of me))) & " --data-urlencode " & (quoted form of ("model=" & shortModelName & " (" & modelIdentifier & ")")) & " --data-urlencode " & (quoted form of ("serial=" & serialNumber)))
							
							repeat with thisRemoteManagementOutputPart in remoteManagementOutputParts
								set organizationNameOffset to (offset of "OrganizationName = " in thisRemoteManagementOutputPart)
								set organizationDepartmentOffset to (offset of "OrganizationDepartment = " in thisRemoteManagementOutputPart)
								set organizationEmailOffset to (offset of "OrganizationEmail = " in thisRemoteManagementOutputPart)
								set organizationSupportEmailOffset to (offset of "OrganizationSupportEmail = " in thisRemoteManagementOutputPart)
								set organizationPhoneOffset to (offset of "OrganizationPhone = " in thisRemoteManagementOutputPart)
								set organizationSupportPhoneOffset to (offset of "OrganizationSupportPhone = " in thisRemoteManagementOutputPart)
								
								if (organizationNameOffset > 0) then
									set remoteManagementOrganizationName to (text (organizationNameOffset + 19) thru -2 of thisRemoteManagementOutputPart)
									if ((remoteManagementOrganizationName starts with "\"") and (remoteManagementOrganizationName ends with "\"")) then set remoteManagementOrganizationName to (text 2 thru -2 of remoteManagementOrganizationName) -- Remove quotes if they exist, which they always should since this should always be a string value.
									set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("organization=" & remoteManagementOrganizationName)))
								else if (organizationDepartmentOffset > 0) then
									set remoteManagementOrganizationDepartment to (text (organizationDepartmentOffset + 25) thru -2 of thisRemoteManagementOutputPart)
									if ((remoteManagementOrganizationDepartment starts with "\"") and (remoteManagementOrganizationDepartment ends with "\"")) then set remoteManagementOrganizationDepartment to (text 2 thru -2 of remoteManagementOrganizationDepartment) -- Quotes may or may not exist around this value depending on its type (such as string vs int), so remove them if they exist.
									if ((remoteManagementOrganizationDepartment is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationDepartment)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationDepartment
									set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("department=" & remoteManagementOrganizationDepartment)))
								else if (organizationEmailOffset > 0) then
									set remoteManagementOrganizationEmail to (text (organizationEmailOffset + 20) thru -2 of thisRemoteManagementOutputPart)
									if ((remoteManagementOrganizationEmail starts with "\"") and (remoteManagementOrganizationEmail ends with "\"")) then set remoteManagementOrganizationEmail to (text 2 thru -2 of remoteManagementOrganizationEmail) -- Quotes may or may not exist around this value depending on its type (such as string vs int), so remove them if they exist.
									if ((remoteManagementOrganizationEmail is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationEmail)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationEmail
									set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("email=" & remoteManagementOrganizationEmail)))
								else if (organizationSupportEmailOffset > 0) then
									set remoteManagementOrganizationSupportEmail to (text (organizationSupportEmailOffset + 27) thru -2 of thisRemoteManagementOutputPart)
									if ((remoteManagementOrganizationSupportEmail starts with "\"") and (remoteManagementOrganizationSupportEmail ends with "\"")) then set remoteManagementOrganizationSupportEmail to (text 2 thru -2 of remoteManagementOrganizationSupportEmail) -- Quotes may or may not exist around this value depending on its type (such as string vs int), so remove them if they exist.
									if ((remoteManagementOrganizationSupportEmail is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationSupportEmail)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationSupportEmail
									set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("support_email=" & remoteManagementOrganizationSupportEmail)))
								else if (organizationPhoneOffset > 0) then
									set remoteManagementOrganizationPhone to (text (organizationPhoneOffset + 20) thru -2 of thisRemoteManagementOutputPart)
									if ((remoteManagementOrganizationPhone starts with "\"") and (remoteManagementOrganizationPhone ends with "\"")) then set remoteManagementOrganizationPhone to (text 2 thru -2 of remoteManagementOrganizationPhone) -- Quotes may or may not exist around this value depending on its type (such as string vs int), so remove them if they exist.
									if ((remoteManagementOrganizationPhone is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationPhone)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationPhone
									set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("phone=" & remoteManagementOrganizationPhone)))
								else if (organizationSupportPhoneOffset > 0) then
									set remoteManagementOrganizationSupportPhone to (text (organizationSupportPhoneOffset + 27) thru -2 of thisRemoteManagementOutputPart)
									if ((remoteManagementOrganizationSupportPhone starts with "\"") and (remoteManagementOrganizationSupportPhone ends with "\"")) then set remoteManagementOrganizationSupportPhone to (text 2 thru -2 of remoteManagementOrganizationSupportPhone) -- Quotes may or may not exist around this value depending on its type (such as string vs int), so remove them if they exist.
									if ((remoteManagementOrganizationSupportPhone is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationSupportPhone)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationSupportPhone
									set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("support_phone=" & remoteManagementOrganizationSupportPhone)))
								end if
							end repeat
							
							if (not remoteManagedMacIsAlreadyLogged) then
								set remoteManagedMacID to ""
								repeat
									try
										activate
									end try
									try
										do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
									end try
									
									set invalidIDnote to ""
									
									if (remoteManagedMacID is not equal to "") then
										set invalidIDnote to "
❌	“" & remoteManagedMacID & "” IS NOT A VALID ID - TRY AGAIN
"
									end if
									
									set remoteManagedMacIDreply to (display dialog "🔒	This Mac is Remote Managed by “" & remoteManagementOrganizationName & "”
" & invalidIDnote & "
Enter the ID of this Mac below to log this Mac with the contact info for “" & remoteManagementOrganizationName & "” so that they can be contacted to remove Remote Management:" default answer remoteManagedMacID buttons {"Log Remote Managed Mac Without ID", "Log Remote Managed Mac"} default button 2)
									
									set remoteManagedMacID to (text returned of remoteManagedMacIDreply)
									
									if ((button returned of remoteManagedMacIDreply) ends with "Without ID") then
										set remoteManagedMacID to "N/A"
									end if
									
									if ((remoteManagedMacID is equal to "N/A") or ((do shell script "bash -c " & (quoted form of ("[[ " & (quoted form of remoteManagedMacID) & " =~ ^[[:alpha:]]*[[:digit:]]+\\-[[:digit:]]+$ ]]; echo $?"))) is equal to "0")) then
										set remoteManagedMacID to (do shell script "echo " & (quoted form of remoteManagedMacID) & " | tr '[:lower:]' '[:upper:]'")
										set logRemoteManagedMacCommand to (logRemoteManagedMacCommand & " --data-urlencode " & (quoted form of ("pid=" & remoteManagedMacID)))
										exit repeat
									end if
								end repeat
								
								repeat
									set logRemoteManagedMacResult to "UNKNOWN ERROR"
									try
										set logRemoteManagedMacResult to (do shell script logRemoteManagedMacCommand)
										if (logRemoteManagedMacResult ends with "LOGGED") then exit repeat
									end try
									
									try
										activate
									end try
									try
										do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
									end try
									display alert "Failed to Log Remote Managed Mac

ERROR: " & logRemoteManagedMacResult & "

You must be connected to the internet to be able to log this Remote Managed Mac." message "Make sure you're connected to either the “FG Staff” (or “Free Geek”) Wi-Fi network or plugged in with an Ethernet cable.

If this Mac does not have an Ethernet port, use a Thunderbolt or USB to Ethernet adapter.

Once you're connected to Wi-Fi or Ethernet, it may take a few moments for the internet connection to be established.

If it takes more than a few minutes, consult an instructor or inform Free Geek I.T." buttons {"Try Again"} default button 1 as critical giving up after 10
								end repeat
							else
								try
									do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
								end try
							end if
							
							set remoteManagementOrganizationContactInfoDisplay to "NO CONTACT INFORMATION"
							if ((count of remoteManagementOrganizationContactInfo) > 0) then
								set AppleScript's text item delimiters to (linefeed & tab & tab)
								set remoteManagementOrganizationContactInfoDisplay to (remoteManagementOrganizationContactInfo as text)
							end if
							
							set remoteManagementDialogButton to "                                                      Understood                                                      "
							-- On macOS 10.15 Catalina and newer, space padded text in DIALOG buttons (but not ALERT buttons) doesn't work as expected,
							-- and the spaces that you want to pad with on each side must be DOUBLED at the END of the text rather than equally on both sides.
							-- (On macOS 26 Tahoe and newer ALERT buttons now ALSO need the same workaround for space padded text in buttons.)
							if (isCatalinaOrNewer) then set remoteManagementDialogButton to "Understood                                                                                                            "
							
							try
								activate
							end try
							display dialog "	     ⚠️     REMOTE MANAGEMENT IS ENABLED ON THIS MAC     ⚠️

❌     MACS WITH REMOTE MANAGEMENT ENABLED CANNOT BE SOLD     ❌



🔒	THIS MAC IS MANAGED BY “" & remoteManagementOrganizationName & "”

🔑	ONLY “" & remoteManagementOrganizationName & "” CAN DISABLE REMOTE MANAGEMENT

☎️	“" & remoteManagementOrganizationName & "” MUST BE CONTACTED BY A MANAGER:
		" & remoteManagementOrganizationContactInfoDisplay & "

🆔	THE SERIAL NUMBER FOR THIS MAC IS “" & serialNumber & "”



	     📝     THIS MAC AND CONTACT INFO HAS BEEN LOGGED     ✅" buttons {remoteManagementDialogButton} with title "Remote Management Enabled"
							
							exit repeat
						else if ((remoteManagementOutput does not contain "Error fetching Device Enrollment configuration") or (remoteManagementOutput contains "Client is not DEP enabled.") or (remoteManagementOutput contains "Bad response from apsd: Connection interrupted")) then -- NOTE: This "Bad response from apsd" error will often be returned when the device IS NOT Remote Managed, so don't show it as an error so that technicians don't get confused.
							if (remoteManagedMacIsAlreadyLogged) then
								set markPreviouslyRemoteManagedMacAsRemovedCommand to ("curl --connect-timeout 5 -sfL " & (quoted form of "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED MARK PREVIOUSLY REMOTE MANAGED MAC AS REMOVED URL]") & " --data-urlencode " & (quoted form of ("serial=" & serialNumber)))
								
								repeat
									set markPreviouslyRemoteManagedMacAsRemovedResult to "UNKNOWN ERROR"
									try
										set markPreviouslyRemoteManagedMacAsRemovedResult to (do shell script markPreviouslyRemoteManagedMacAsRemovedCommand)
										if (markPreviouslyRemoteManagedMacAsRemovedResult ends with "REMOVED") then exit repeat
									end try
									
									try
										activate
									end try
									try
										do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
									end try
									display alert "Failed to Mark Previously Remote Managed Mac As Removed

ERROR: " & markPreviouslyRemoteManagedMacAsRemovedResult & "

You must be connected to the internet to be able to mark this previously Remote Managed Mac as removed." message "Make sure you're connected to either the “FG Staff” (or “Free Geek”) Wi-Fi network or plugged in with an Ethernet cable.

If this Mac does not have an Ethernet port, use a Thunderbolt or USB to Ethernet adapter.

Once you're connected to Wi-Fi or Ethernet, it may take a few moments for the internet connection to be established.

If it takes more than a few minutes, consult an instructor or inform Free Geek I.T." buttons {"Try Again"} default button 1 as critical giving up after 10
								end repeat
							end if
							
							set progress description to "
👍	Remote Management IS NOT Enabled"
							delay 2
							
							exit repeat
						else
							set progress description to "
❌	FAILED to Check for Remote Management"
							try
								activate
							end try
							try
								do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
							end try
							try
								display alert "Failed to Check Remote Management" message (remoteManagementOutput & "

This should not have happened, please inform Free Geek I.T.") buttons {"Continue", "Try Again"} cancel button 1 default button 2 as critical
							on error
								exit repeat
							end try
						end if
					end try
				else
					set progress description to "
❌	FAILED to Check for Remote Management"
					try
						activate
					end try
					try
						do shell script "afplay /System/Library/Sounds/Basso.aiff > /dev/null 2>&1 &"
					end try
					try
						display alert "Failed to Check Remote Management" message "An UNKNOWN ERROR occurred.

This should not have happened, please inform Free Geek I.T." buttons {"Continue", "Try Again"} cancel button 1 default button 2 as critical
					on error
						exit repeat
					end try
				end if
			end repeat
		end try
	end if
	
	set progress description to "
✅	Finished Loading " & (name of me) & ""
	
	if (isLaptop) then
		set batteryRows to "

🔋	Battery Health:
	" & batteryHealth
		
		if (macBookPro2016and2017RecalledBatteryRecall) then
			set batteryRows to batteryRows & "
	⚠️	BATTERY MAY BE RECALLED FOR REPLACEMENT  ⚠️
	‼️	IF WON'T CHARGE OR CONDITION NOT NORMAL  ‼️"
		else if (macBookPro13inch2016PossibleBatteryRecall or macBookPro15inch2015PossibleBatteryRecall) then
			set batteryRows to batteryRows & "
	⚠️	BATTERY MAY BE RECALLED FOR REPLACEMENT  ⚠️
	‼️	CHECK SERIAL NUMBER ON APPLE'S BATTERY RECALL PAGE  ‼️
	‼️	DON'T LEAVE ON & UNATTENDED UNTIL SERIAL IS CHECKED  ‼️"
		end if
	end if
	
	set showMojaveOnOldMacProButton to false
	
	set supportedOS to "
	OS X 10.11 El Capitan"
	
	if (supportsTahoe) then
		set supportedOS to "
	macOS 26 Tahoe"
	else if (supportsSequoia) then
		set supportedOS to "
	macOS 15 Sequoia
	⚠️	WILL NOT SUPPORT macOS 26 Tahoe or Newer"
	else if (supportsSonoma) then
		set supportedOS to "
	macOS 14 Sonoma
	⚠️	WILL NOT SUPPORT macOS 15 Sequoia or Newer"
	else if (supportsVentura) then
		set supportedOS to "
	macOS 13 Ventura
	⚠️	DOES NOT SUPPORT macOS 14 Sonoma or Newer"
	else if (supportsMonterey) then
		set supportedOS to "
	macOS 12 Monterey
	⚠️	DOES NOT SUPPORT macOS 13 Ventura or Newer"
	else if (supportsBigSur) then
		set supportedOS to "
	macOS 11 Big Sur
	⚠️	DOES NOT SUPPORT macOS 12 Monterey or Newer"
	else if (supportsCatalina) then
		set supportedOS to "
	macOS 10.15 Catalina
	⚠️	DOES NOT SUPPORT macOS 11 Big Sur or Newer"
	else if (supportsHighSierra) then
		set supportedOS to "
	macOS 10.13 High Sierra"
		if (supportsMojaveWithMetalCapableGPU) then
			set supportedOS to (supportedOS & "
	✅	CAN SUPPORT macOS 10.14 Mojave
		👉	With Recommended Metal-Capable GPU
			(Including MSI Gaming Radeon RX 560
			  and Sapphire Radeon PULSE RX 580)")
			set showMojaveOnOldMacProButton to true
		end if
	end if
	
	
	-- DISPLAY SYSTEM OVERVIEW
	try
		set modelInfo to (do shell script "echo " & (quoted form of modelInfo) & " | sed 's/" & shortModelName & "/" & shortModelName & " " & modelIdentifierNumber & "/'")
	end try
	if (modelInfo does not contain modelIdentifierNumber) then set modelInfo to (modelIdentifier & " / " & modelInfo)
	
	set displayMemorySlots to ""
	if ((count of memorySlots) > 0) then
		set AppleScript's text item delimiters to " + "
		set displayMemorySlots to " (" & (memorySlots as text) & ")"
	end if
	
	try
		set systemOverviewModel to " " & computerIcon & "	 Model:
	 " & modelInfo
		
		if (macBookProButterflyKeyboardRecall) then
			set systemOverviewModel to systemOverviewModel & "

⚠️	IF KEYBOARD HAS ISSUES, APPLE MAY REPAIR IT FOR FREE  ⚠️"
		end if
		
		if (macBookPro13inch2016PossibleBacklightRecall) then
			set systemOverviewModel to systemOverviewModel & "

⚠️	IF BACKLIGHT HAS ISSUES, APPLE MAY REPAIR IT FOR FREE  ⚠️"
		end if
		
		if (macBookProOtherFlexgate) then
			set systemOverviewModel to systemOverviewModel & "

⚠️	BACKLIGHT MAY HAVE ISSUES, BUT APPLE HAS NOT RECALLED IT  ⚠️"
		end if
		
		if (macBookProScreenDelaminationRecall) then
			set systemOverviewModel to systemOverviewModel & "

⚠️	IF SCREEN HAS DELAMINATION, APPLE MAY REPAIR IT FOR FREE  ⚠️"
		end if
		
		if (iMacHingeRecall) then
			set systemOverviewModel to systemOverviewModel & "

⚠️	IF HINGE IS WEAK OR BROKEN, APPLE MAY REPAIR IT FOR FREE  ⚠️"
		end if
		
		set spacesForDefaultWidth to ""
		repeat 135 times
			-- Big Sur seems to have a bug where it calculates the "choose from list" window width just slightly less that what is needed, causing the longest line to get a bit truncated.
			-- Including a line of spaces that is slightly longer than the longest possible line (which are the battery recall info lines) allows the window to always be wide enough without anything getting truncated.
			set spacesForDefaultWidth to spacesForDefaultWidth & " "
		end repeat
		
		set restOfSystemOverview to "🧠	CPU (Processor):
	" & processorInfo & "
" & spacesForDefaultWidth & "
📊	RAM (Memory):
	" & memorySize & " " & memoryType & memorySpeed & displayMemorySlots & memoryNote & "

📁	Storage (Hard Drive):
	" & storageInfo & "

👾	GPU (Graphics):
	" & graphicsInfo & "

📡	Wireless:
	" & wiFiInfo & "
	" & bluetoothInfo & "

📀	Disc Drive:
	" & discDriveDetected & batteryRows & powerAdapterRows & "

🍏	Supported OS:" & supportedOS
		
		set reloadButton to "Reload"
		if (macBookPro13inch2016PossibleBatteryRecall or macBookPro15inch2015PossibleBatteryRecall or macBookPro2016and2017RecalledBatteryRecall) then
			set reloadButton to "Open Battery Recall Info & Reload"
		else if (macBookPro13inch2017PossibleSSDRecall) then
			set reloadButton to "Open SSD Recall Info & Reload"
		else if (macBookProPossibleBadGraphics or iMacPossibleBadGraphics or macProPossibleBadGraphics) then
			set reloadButton to "Open Graphics Recall Info & Reload"
		else if (macBookPro13inch2016PossibleBacklightRecall) then
			set reloadButton to "Open Backlight Recall Info & Reload"
		else if (macBookProButterflyKeyboardRecall) then
			set reloadButton to "Open Keyboard Recall Info & Reload"
		else if (macBookProScreenDelaminationRecall) then
			set reloadButton to "Open Screen Delamination Info & Reload"
		else if (iMacHingeRecall) then
			set reloadButton to "Open Hinge Repair Info & Reload"
		else if (showSystemInfoAppButton) then
			set reloadButton to "Open “System Information” & Reload"
		else if (showMojaveOnOldMacProButton) then
			set reloadButton to "Open Mojave on Mac Pro Info & Reload"
		end if
		
		try
			activate
		end try
		set systemOverviewReply to choose from list (paragraphs of restOfSystemOverview) with prompt systemOverviewModel & "
" cancel button name reloadButton OK button name "Done" with title (name of me) with empty selection allowed without multiple selections allowed
		
		if (systemOverviewReply is false) then
			set progress description to "
🔄	Reloading " & (name of me) & ""
			try
				if (macBookPro2016and2017RecalledBatteryRecall) then
					open location "https://web.archive.org/web/20220620162055/https://support.apple.com/en-us/HT212163"
				else if (macBookPro13inch2016PossibleBatteryRecall or macBookPro15inch2015PossibleBatteryRecall or macBookPro13inch2017PossibleSSDRecall) then
					set the clipboard to serialNumber
					if (macBookPro13inch2016PossibleBatteryRecall) then
						open location "https://web.archive.org/web/20221209124713/https://support.apple.com/13inch-macbookpro-battery-replacement"
					else if (macBookPro13inch2017PossibleSSDRecall) then
						open location "https://web.archive.org/web/20221208144358/https://support.apple.com/13-inch-macbook-pro-solid-state-drive-service"
					else
						open location "https://support.apple.com/15-inch-macbook-pro-battery-recall"
					end if
					try
						activate
					end try
					display alert "\"" & serialNumber & "\" Copied to Clipboard" message "This computers serial number has been copied to the clipboard to search on Apple's recall page."
				else if (macBookProPossibleBadGraphics) then
					open location "https://www.macrumors.com/2017/05/20/apple-ends-2011-macbook-pro-repair-program/"
				else if (iMacPossibleBadGraphics) then
					open location "https://www.macrumors.com/2013/08/16/apple-initiates-graphic-card-replacement-program-for-mid-2011-27-inch-imac/"
				else if (macProPossibleBadGraphics) then
					open location "https://www.macrumors.com/2016/02/06/late-2013-mac-pro-video-issues-repair-program/"
				else if (macBookPro13inch2016PossibleBacklightRecall) then
					open location "https://support.apple.com/13-inch-macbook-pro-display-backlight-service"
				else if (macBookProButterflyKeyboardRecall) then
					open location "https://support.apple.com/keyboard-service-program-for-mac-notebooks"
				else if (macBookProScreenDelaminationRecall) then
					open location "https://www.macrumors.com/2017/11/17/apple-extends-free-staingate-repairs/"
				else if (iMacHingeRecall) then
					open location "https://www.macrumors.com/2016/11/29/imac-broken-hinge-refunds-repair-program/"
				else if (showSystemInfoAppButton) then
					try
						do shell script "open -b com.apple.SystemProfiler"
					end try
				else if (showMojaveOnOldMacProButton) then
					open location "https://support.apple.com/HT208898"
				else
					try
						activate
					end try
				end if
			on error (openAfterDialogErrorMessage)
				try
					activate
				end try
				display alert openAfterDialogErrorMessage
				exit repeat
			end try
		else
			exit repeat
		end if
	on error (systemOverviewDialogErrorMessage) number (systemOverviewDialogErrorNumber)
		if (systemOverviewDialogErrorNumber is not equal to -128) then
			try
				activate
			end try
			display alert systemOverviewDialogErrorMessage
		end if
		exit repeat
	end try
end repeat

set progress description to "
✅	Finished Viewing " & (name of me) & ""

try
	((infoPlistPath as POSIX file) as alias) -- Only list next tests when exported as an app to make debugging faster.
	
	set listOfAvailableTests to {}
	
	try
		(("/Applications/Internet Test.app" as POSIX file) as alias)
		set (end of listOfAvailableTests) to "📡	Internet Test"
	end try
	try
		(("/Applications/Audio Test.app" as POSIX file) as alias)
		set (end of listOfAvailableTests) to "📢	Audio Test"
	end try
	if ((shortModelName is not equal to "Mac Pro") and (shortModelName is not equal to "Mac mini") and (shortModelName is not equal to "Mac Studio")) then
		try
			(("/Applications/Microphone Test.app" as POSIX file) as alias)
			set (end of listOfAvailableTests) to "🎙	Microphone Test"
		end try
		try
			(("/Applications/Camera Test.app" as POSIX file) as alias)
			set (end of listOfAvailableTests) to "🎥	Camera Test"
		end try
		try
			(("/Applications/Screen Test.app" as POSIX file) as alias)
			set (end of listOfAvailableTests) to "🇲🇺	Screen Test"
		end try
		if (isLaptop) then
			try
				(("/Applications/Trackpad Test.app" as POSIX file) as alias)
				set (end of listOfAvailableTests) to "✌️	Trackpad Test"
			end try
			try
				(("/Applications/Keyboard Test.app" as POSIX file) as alias)
				set (end of listOfAvailableTests) to "⌨️	Keyboard Test"
			end try
		end if
	end if
	try
		(("/Applications/CPU Stress Test.app" as POSIX file) as alias)
		set (end of listOfAvailableTests) to "🧠	CPU Stress Test"
	end try
	try
		(("/Applications/GPU Stress Test.app" as POSIX file) as alias)
		set (end of listOfAvailableTests) to "🍩	GPU Stress Test"
	end try
	try
		(("/Applications/DriveDx.app" as POSIX file) as alias)
		set (end of listOfAvailableTests) to "🏥	Hard Drive Test (DriveDx)"
	end try
	try
		(("/Applications/Startup Picker.app" as POSIX file) as alias)
		set (end of listOfAvailableTests) to "🍏	Startup Picker"
	end try
	if ((count of hardDriveDiskIDs) > 0) then
		try
			(("/Applications/DriveDx.app" as POSIX file) as alias)
		on error
			try
				(("/usr/local/sbin/smartctl" as POSIX file) as alias)
				set (end of listOfAvailableTests) to "🏥	Show Raw Hard Drive SMART Data in Terminal"
			end try
		end try
	end if
	
	if ((count of listOfAvailableTests) > 0) then
		set progress description to "
⏭	Select Next Test"
		
		try
			activate
		end try
		set launchTestReply to choose from list listOfAvailableTests with title "Select Next Test" with prompt "Which test would you like to launch next?
" default items (item 1 of listOfAvailableTests) cancel button name "None" OK button name "Launch Selected Test" without empty selection allowed and multiple selections allowed
		
		if (launchTestReply is not false) then
			try
				set selectedLaunchTest to (item 1 of launchTestReply)
				if (selectedLaunchTest is equal to "📡	Internet Test") then
					do shell script "open -na '/Applications/Internet Test.app'"
				else if (selectedLaunchTest is equal to "📢	Audio Test") then
					do shell script "open -na '/Applications/Audio Test.app'"
				else if (selectedLaunchTest is equal to "🎙	Microphone Test") then
					do shell script "open -na '/Applications/Microphone Test.app'"
				else if (selectedLaunchTest is equal to "🎥	Camera Test") then
					do shell script "open -na '/Applications/Camera Test.app'"
				else if (selectedLaunchTest is equal to "🇲🇺	Screen Test") then
					do shell script "open -na '/Applications/Screen Test.app'"
				else if (selectedLaunchTest is equal to "✌️	Trackpad Test") then
					do shell script "open -na '/Applications/Trackpad Test.app'"
				else if (selectedLaunchTest is equal to "⌨️	Keyboard Test") then
					do shell script "open -na '/Applications/Keyboard Test.app'"
				else if (selectedLaunchTest is equal to "🧠	CPU Stress Test") then
					do shell script "open -na '/Applications/CPU Stress Test.app'"
				else if (selectedLaunchTest is equal to "🍩	GPU Stress Test") then
					do shell script "open -na '/Applications/GPU Stress Test.app'"
				else if (selectedLaunchTest is equal to "🏥	Hard Drive Test (DriveDx)") then
					do shell script "open -na '/Applications/DriveDx.app'"
				else if (selectedLaunchTest is equal to "🍏	Startup Picker") then
					do shell script "open -na '/Applications/Startup Picker.app'"
				else if (selectedLaunchTest is equal to "🏥	Show Raw Hard Drive SMART Data in Terminal") then
					if ((count of hardDriveDiskIDs) > 0) then
						repeat with thisDiskID in hardDriveDiskIDs
							try
								tell application id "com.apple.Terminal"
									try
										close every window without saving
									end try
									do script "/usr/local/sbin/smartctl -a " & (quoted form of thisDiskID)
									try
										activate
									end try
								end tell
							end try
						end repeat
					end if
				else
					beep
				end if
			on error
				beep
			end try
		end if
	end if
end try
