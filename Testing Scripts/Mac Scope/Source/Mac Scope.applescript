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

-- Version: 2022.5.19-1

-- App Icon is “Microscope” from Twemoji (https://twemoji.twitter.com/) by Twitter (https://twitter.com)
-- Licensed under CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/)

use AppleScript version "2.7"
use scripting additions

repeat -- dialogs timeout when screen is asleep or locked (just in case)
	set isAwake to true
	try
		set isAwake to ((do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :0:IOPowerManagement:CurrentPowerState' /dev/stdin <<< \"$(ioreg -arc IODisplayWrangler -k IOPowerManagement -d 1)\""))) is equal to "4")
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
		try
			activate
		end try
		display alert checkReadOnlyErrorMessage buttons {"Quit"} default button 1 as critical
		quit
		delay 10
	end if
end try


set dialogIconName to "applet"
try
	((((POSIX path of (path to me)) & "Contents/Resources/" & (name of me) & ".icns") as POSIX file) as alias)
	set dialogIconName to (name of me)
end try

set systemVersion to (system version of (system info))
considering numeric strings
	set isMojaveOrNewer to (systemVersion ≥ "10.14")
	set isCatalinaOrNewer to (systemVersion ≥ "10.15")
	set isBigSurOrNewer to (systemVersion ≥ "11.0")
end considering

if (isMojaveOrNewer) then
	try
		tell application "System Events" to every window -- To prompt for Automation access on Mojave
	on error automationAccessErrorMessage number automationAccessErrorNumber
		if (automationAccessErrorNumber is equal to -1743) then
			try
				tell application "System Preferences"
					try
						activate
					end try
					reveal ((anchor "Privacy") of (pane id "com.apple.preference.security"))
				end tell
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

• Relaunch “" & (name of me) & "” (using the button below)." buttons {"Quit", "Relaunch “" & (name of me) & "”"} cancel button 1 default button 2 with title (name of me) with icon dialogIconName
				try
					do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -n -a \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
				end try
			end try
			quit
			delay 10
		end if
	end try
end if

set aboutThisMacAppPath to "/System/Library/CoreServices/Applications/About This Mac.app"
try
	((aboutThisMacAppPath as POSIX file) as alias)
on error
	try
		tell application "System Events" to tell application process "Finder" to (get windows)
	on error (assistiveAccessTestErrorMessage)
		if ((offset of "not allowed assistive" in assistiveAccessTestErrorMessage) > 0) then
			try
				tell application "Finder" to reveal (path to me)
			end try
			try
				tell application "System Preferences"
					try
						activate
					end try
					reveal ((anchor "Privacy_Accessibility") of (pane id "com.apple.preference.security"))
				end tell
			end try
			try
				activate
			end try
			try
				display dialog "“" & (name of me) & "” must be allowed to control this computer using Accessibility Features to be able to function.


USE THE FOLLOWING STEPS TO FIX THIS ISSUE:

• Open the “System Preferences” application.

• Click the “Security & Privacy” preference pane.

• Select the “Privacy” tab.

• Select “Accessibility” in the source list on the left.

• Click the Lock icon at the bottom left of the window, enter the administrator username and password, and then click Unlock.

• Find “" & (name of me) & "” in the list on the right and turn on the checkbox next to it. If “" & (name of me) & "” IS NOT in the list, drag-and-drop the app icon from Finder into the list.

• Relaunch “" & (name of me) & "” (using the button below)." buttons {"Quit", "Relaunch “" & (name of me) & "”"} cancel button 1 default button 2 with title (name of me) with icon dialogIconName
				try
					do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -n -a \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
				end try
			end try
			quit
			delay 10
		end if
	end try
end try


set adminUsername to "Staff"
if (isCatalinaOrNewer) then set adminUsername to "staff"
set adminPassword to "[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]"

set buildInfoPath to ((POSIX path of (path to shared documents folder)) & "Build Info/")
try
	(((buildInfoPath & ".fgSetupSkipped") as POSIX file) as alias)
	
	try
		do shell script ("mkdir " & (quoted form of buildInfoPath))
	end try
	try
		set AppleScript's text item delimiters to "-"
		do shell script ("touch " & (quoted form of (buildInfoPath & ".fgLaunchAfterSetup-org.freegeek." & ((words of (name of me)) as string)))) user name adminUsername password adminPassword with administrator privileges
	end try
	
	try
		-- For some reason, on Big Sur, apps are not opening unless we specify "-n" to "Open a new instance of the application(s) even if one is already running." All scripts have LSMultipleInstancesProhibited to this will not actually ever open a new instance.
		do shell script "open -n -a '/Applications/Test Boot Setup.app'"
	end try
	
	quit
	delay 10
end try


repeat
	repeat 3 times -- Will exit early if got Hardware, Memory, and Graphics info. But try 3 times in case these critical things didn't load.
		try
			tell application "System Events" to tell current location of network preferences
				repeat with thisActiveNetworkService in (every service whose active is true)
					if (((name of interface of thisActiveNetworkService) as string) is equal to "Wi-Fi") then
						try
							do shell script ("networksetup -setairportpower " & ((id of interface of thisActiveNetworkService) as string) & " on")
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
		set showAboutMacWindowButton to false
		
		set AppleScript's text item delimiters to ""
		set tmpPath to ((POSIX path of (((path to temporary items) as text) & "::")) & "fg" & ((words of (name of me)) as string) & "-") -- On Catalina, writing to trailing folder "/TemporaryItems/" often fails with "Operation not permitted" for some reason. Also, prefix all files with "fg" and name of script.
		
		set hardwareInfoPath to tmpPath & "hardwareInfo.plist"
		set restOfSystemOverviewInfoPath to tmpPath & "restOfSystemOverviewInfo.plist"
		set marketingModelNameXMLpath to tmpPath & "marketingModelName.xml"
		set bluetoothInfoPath to tmpPath & "bluetoothInfo.plist"
		
		do shell script "rm -f " & (quoted form of hardwareInfoPath) & " " & (quoted form of restOfSystemOverviewInfoPath) & " " & (quoted form of marketingModelNameXMLpath) & " " & (quoted form of bluetoothInfoPath)
		
		-- SYSTEM MODEL INFORMATION
		
		set didGetHardwareInfo to false
		set isLaptop to false
		set supportsHighSierra to false
		set supportsMojaveWithMetalCapableGPU to false
		set supportsCatalina to false
		set supportsBigSur to false
		set supportsMonterey to false
		set shortModelName to "UNKNOWN Model Name  ⚠️"
		set modelIdentifier to "UNKNOWN Model Identifier"
		set memorySize to "⚠️	UNKNOWN Size"
		set memorySlots to {}
		set chipType to "UNKNOWN Chip" -- For Apple Silicon
		set processorTotalCoreCount to "❓"
		set processorHyperthreadingValue to ""
		set processorsCount to "❓"
		set serialNumber to "UNKNOWNXXXXX"
		set serialNumberDatePart to "AA"
		set serialNumberModelPart to "XXXX"
		set modelIdentifierNumber to "⚠️	UNKNOWN Model ID"
		set modelIdentifierMajorNumber to 0
		set modelIdentifierMinorNumber to 0
		repeat 30 times -- system_profiler seems to fail sometimes when run on login.
			set showSystemInfoAppButton to false
			try
				do shell script "system_profiler -xml SPHardwareDataType > " & (quoted form of hardwareInfoPath)
				tell application "System Events" to tell property list file hardwareInfoPath
					set hardwareItems to (first property list item of property list item "_items" of first property list item)
					
					try
						set serialNumber to ((value of property list item "serial_number" of hardwareItems) as string) -- https://www.macrumors.com/2010/04/16/apple-tweaks-serial-number-format-with-new-macbook-pro/
						if (((length of serialNumber) ≥ 11) and (serialNumber is not equal to "Not Available")) then
							set serialNumberDatePart to (text 3 thru 5 of serialNumber)
							if ((count of serialNumber) is equal to 12) then set serialNumberDatePart to (text 2 thru -1 of serialNumberDatePart)
							set serialNumberModelPart to (text 9 thru -1 of serialNumber) -- The model part of the serial is the last 4 characters for 12 character serials and the last 3 characters for 11 character serials (which are very old and shouldn't actually be encountered).
						else
							set serialNumber to "UNKNOWNXXXXX"
						end if
					on error
						set serialNumber to "UNKNOWNXXXXX"
					end try
					
					set shortModelName to ((value of property list item "machine_name" of hardwareItems) as string)
					if ((words of shortModelName) contains "MacBook") then
						set computerIcon to "💻"
						set isLaptop to true
					end if
					set modelIdentifier to ((value of property list item "machine_model" of hardwareItems) as string)
					set modelIdentifierNumber to (do shell script "echo " & (quoted form of modelIdentifier) & " | tr -dc '[:digit:],'")
					set AppleScript's text item delimiters to ","
					set modelNumberParts to (every text item of modelIdentifierNumber)
					set modelIdentifierMajorNumber to ((item 1 of modelNumberParts) as number)
					set modelIdentifierMinorNumber to ((last item of modelNumberParts) as number)
					
					if (((shortModelName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 10)) or ((shortModelName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 6)) or ((shortModelName is equal to "MacBook Pro") and (modelIdentifierMajorNumber ≥ 6)) or ((shortModelName is equal to "MacBook Air") and (modelIdentifierMajorNumber ≥ 3)) or ((shortModelName is equal to "Mac mini") and (modelIdentifierMajorNumber ≥ 4)) or ((shortModelName is equal to "Mac Pro") and (modelIdentifierMajorNumber ≥ 5)) or (shortModelName is equal to "iMac Pro")) then set supportsHighSierra to true
					
					if ((shortModelName is equal to "Mac Pro") and (modelIdentifierMajorNumber = 5)) then set supportsMojaveWithMetalCapableGPU to true
					
					if (((shortModelName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 13)) or ((shortModelName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 8)) or ((shortModelName is equal to "MacBook Pro") and (modelIdentifierMajorNumber ≥ 9)) or ((shortModelName is equal to "MacBook Air") and (modelIdentifierMajorNumber ≥ 5)) or ((shortModelName is equal to "Mac mini") and (modelIdentifierMajorNumber ≥ 6)) or ((shortModelName is equal to "Mac Pro") and (modelIdentifierMajorNumber ≥ 6)) or (shortModelName is equal to "iMac Pro")) then set supportsCatalina to true
					
					if (((shortModelName is equal to "iMac") and ((modelIdentifierNumber is equal to "14,4") or (modelIdentifierMajorNumber ≥ 15))) or ((shortModelName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 8)) or ((shortModelName is equal to "MacBook Pro") and (modelIdentifierMajorNumber ≥ 11)) or ((shortModelName is equal to "MacBook Air") and (modelIdentifierMajorNumber ≥ 6)) or ((shortModelName is equal to "Mac mini") and (modelIdentifierMajorNumber ≥ 7)) or ((shortModelName is equal to "Mac Pro") and (modelIdentifierMajorNumber ≥ 6)) or (shortModelName is equal to "iMac Pro")) then set supportsBigSur to true
					
					if (((shortModelName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 16)) or ((shortModelName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 9)) or ((shortModelName is equal to "MacBook Pro") and ((modelIdentifierNumber is equal to "11,4") or (modelIdentifierNumber is equal to "11,5") or (modelIdentifierMajorNumber ≥ 12))) or ((shortModelName is equal to "MacBook Air") and (modelIdentifierMajorNumber ≥ 7)) or ((shortModelName is equal to "Mac mini") and (modelIdentifierMajorNumber ≥ 7)) or ((shortModelName is equal to "Mac Pro") and (modelIdentifierMajorNumber ≥ 6)) or (shortModelName is equal to "iMac Pro") or (shortModelName is equal to "Mac Studio")) then set supportsMonterey to true
					
					set memorySize to ((value of property list item "physical_memory" of hardwareItems) as string)
					
					try
						set chipType to ((value of property list item "chip_type" of hardwareItems) as string) -- This will only exist when running natively on Apple Silicon
					end try
					
					try
						set processorsCount to ((value of property list item "packages" of hardwareItems) as string) -- This will only exist on Intel or Apple Silicon under Rosetta
					end try
					
					set processorTotalCoreCount to ((value of property list item "number_processors" of hardwareItems) as string)
					
					try
						set processorHyperthreadingValue to ((value of property list item "platform_cpu_htt" of hardwareItems) as string) -- This will only exist on Mojave and newer
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
		
		-- https://support.apple.com/15-inch-macbook-pro-battery-recall
		set macBookPro15inch2015RecalledBatteryModels to {"MacBookPro11,4", "MacBookPro11,5"}
		set macBookPro15inch2015PossibleBatteryRecall to (macBookPro15inch2015RecalledBatteryModels contains modelIdentifier)
		-- https://support.apple.com/keyboard-service-program-for-mac-notebooks
		set macBookProButterflyKeyboardRecallModels to {"MacBook8,1", "MacBook9,1", "MacBook10,1", "MacBookAir8,1", "MacBookAir8,2", "MacBookPro13,1", "MacBookPro13,2", "MacBookPro13,3", "MacBookPro14,1", "MacBookPro14,2", "MacBookPro14,3", "MacBookPro15,1", "MacBookPro15,2", "MacBookPro15,3", "MacBookPro15,4"}
		set macBookProButterflyKeyboardRecall to (macBookProButterflyKeyboardRecallModels contains modelIdentifier)
		-- https://support.apple.com/13-inch-macbook-pro-display-backlight-service
		set macBookPro13inch2016RecalledBacklightModels to {"MacBookPro13,1", "MacBookPro13,2"}
		set macBookPro13inch2016PossibleBacklightRecall to (macBookPro13inch2016RecalledBacklightModels contains modelIdentifier)
		-- Only the 2016 13-inch is covered by Apple for the FLEXGATE issue, but the 15-inch and 2017 models may also have the same issue
		set macBookProOtherFlexgateModels to {"MacBookPro13,3", "MacBookPro14,1", "MacBookPro14,2", "MacBookPro14,3"}
		set macBookProOtherFlexgate to (macBookProOtherFlexgateModels contains modelIdentifier)
		-- https://support.apple.com/13-inch-macbook-pro-solid-state-drive-service
		set macBookPro13inch2017RecalledSSDModels to {"MacBookPro14,1"}
		set macBookPro13inch2017PossibleSSDRecall to (macBookPro13inch2017RecalledSSDModels contains modelIdentifier)
		-- https://support.apple.com/13inch-macbookpro-battery-replacement
		set macBookPro13inch2016RecalledBatteryModels to {"MacBookPro13,1", "MacBookPro14,1"}
		set macBookPro13inch2016PossibleBatteryRecall to (macBookPro13inch2016RecalledBatteryModels contains modelIdentifier)
		-- https://www.macrumors.com/2017/11/17/apple-extends-free-staingate-repairs/
		set macBookProScreenDelaminationModels to {"MacBook8,1", "MacBook9,1", "MacBook10,1", "MacBookPro11,4", "MacBookPro11,5", "MacBookPro12,1", "MacBookPro13,1", "MacBookPro13,2", "MacBookPro13,3", "MacBookPro14,1", "MacBookPro14,2", "MacBookPro14,3"}
		set macBookProScreenDelaminationRecall to (macBookProScreenDelaminationModels contains modelIdentifier)
		-- https://www.apple.com/support/macbookpro-videoissues/
		set macBookProRecalledGraphicsModels to {"MacBookPro8,2", "MacBookPro8,3", "MacBookPro10,1"}
		set macBookProPossibleBadGraphics to (macBookProRecalledGraphicsModels contains modelIdentifier)
		-- https://www.macrumors.com/2016/11/29/imac-broken-hinge-refunds-repair-program/
		set iMacHingeRecallModels to {"iMac14,2"}
		set iMacHingeRecall to (iMacHingeRecallModels contains modelIdentifier)
		-- https://www.macrumors.com/2013/08/16/apple-initiates-graphic-card-replacement-program-for-mid-2011-27-inch-imac/
		set iMacRecalledGraphicsSerialModelParts to {"DHJQ", "DHJW", "DL8Q", "DNGH", "DNJ9", "DMW8", "DPM1", "DPM2", "DPNV", "DNY0", "DRVP", "DY6F", "F610"}
		set iMacPossibleBadGraphics to ((shortModelName is equal to "iMac") and (iMacRecalledGraphicsSerialModelParts contains serialNumberModelPart))
		-- https://www.macrumors.com/2016/02/06/late-2013-mac-pro-video-issues-repair-program/
		set macProRecalledSerialDateParts to {"P5", "P6", "P7", "P8", "P9", "PC", "PD", "PF", "PG", "PH"}
		set macProRecalledSerialDatePartsMatched to ((shortModelName is equal to "Mac Pro") and (macProRecalledSerialDateParts contains serialNumberDatePart))
		set macProRecalledGraphicsCards to {"AMD FirePro D500", "AMD FirePro D700"}
		set macProPossibleBadGraphics to false
		
		set restOfSystemOverviewInfoToLoad to {"SPMemoryDataType", "SPSerialATADataType", "SPNVMeDataType", "SPDisplaysDataType", "SPAirPortDataType", "SPBluetoothDataType", "SPDiscBurningDataType"}
		if (isLaptop) then set (end of restOfSystemOverviewInfoToLoad) to "SPPowerDataType"
		set AppleScript's text item delimiters to space
		set systemProfilerPID to (do shell script "system_profiler -xml " & (restOfSystemOverviewInfoToLoad as string) & " > " & (quoted form of restOfSystemOverviewInfoPath) & " 2> /dev/null & echo $!")
		
		
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
			
			if (chipType is not equal to "UNKNOWN Chip") then
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
				set processorInfoParts to (words of (processorInfoParts as string))
				set processorSpeed to ((last item of processorInfoParts) as string)
				if ((last character of processorSpeed) is equal to "0") then set processorSpeed to (text 1 thru -2 of processorSpeed)
				set processorInfoParts to (text items 1 thru -2 of processorInfoParts)
				set processorModelFrom to {"Core i", "Core 2 Duo"}
				set processorModelTo to {"i", "C2D"}
				set processorModelPart to (processorInfoParts as string)
				repeat with i from 1 to (count of processorModelFrom)
					set AppleScript's text item delimiters to (text item i of processorModelFrom)
					set processorModelCoreParts to (every text item of processorModelPart)
					if ((count of processorModelCoreParts) ≥ 2) then
						set AppleScript's text item delimiters to (text item i of processorModelTo)
						set processorModelPart to (processorModelCoreParts as string)
					end if
				end repeat
				
				if ((processorHyperthreadingValue is equal to "") and (setProcessorTotalThreadCount > processorTotalCoreCount)) then set processorHyperthreadingNote to " + HT"
				
				set processorInfo to processorTotalCoreCount & "-Core" & processorHyperthreadingNote & ": " & processorsCountPart & processorModelPart & " @ " & processorSpeed & " GHz"
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
🔋	Loading Battery Information"
			
			-- BATTERY INFORMATION
			
			set batteryCapacityPercentage to "⚠️	NOT Detected  ⚠️
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
				set batteryCapacityPercentageLimit to 75
				set batteryCapacityPercentageNumber to (((round (((maxCapacityMhA / designCapacityMhA) * 100) * 10)) / 10) as string)
				if ((text -2 thru -1 of batteryCapacityPercentageNumber) is equal to ".0") then set batteryCapacityPercentageNumber to (text 1 thru -3 of batteryCapacityPercentageNumber)
				set batteryCapacityPercentageNumber to (batteryCapacityPercentageNumber as number)
				if (batteryCapacityPercentageNumber is equal to 0) then error "No Battery Found"
				
				set pluralizeCycles to "Cycle"
				if (cycleCount is not equal to 1) then set pluralizeCycles to "Cycles"
				set batteryCapacityPercentage to (batteryCapacityPercentageNumber as string) & "% (Remaining of Design Capacity) + " & cycleCount & " " & pluralizeCycles
				if (batteryCapacityPercentageNumber < batteryCapacityPercentageLimit) then
					set batteryCapacityPercentage to batteryCapacityPercentage & "
	⚠️	BELOW " & batteryCapacityPercentageLimit & "% DESIGN CAPACITY  ⚠️"
				end if
				
				set cycleCountLimit to designCycleCount
				if (not macBookProPossibleBadGraphics) then set cycleCountLimit to (round (designCycleCount * 0.8))
				if ((designCycleCount > 0) and (cycleCount > (cycleCountLimit + 10))) then -- https://support.apple.com/en-us/HT201585
					set batteryCapacityPercentage to batteryCapacityPercentage & "
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
			
			set powerAdapterType to "⚠️	UNKNOWN Power Adapter  ⚠️"
			if (shortModelName is equal to "MacBook") then
				if (modelIdentifierMajorNumber ≥ 8) then
					set powerAdapterType to "29W USB-C"
				else
					set powerAdapterType to "60W MagSafe 1"
				end if
			else if (shortModelName is equal to "MacBook Pro") then
				-- 5,4 is "MacBook Pro (15-inch, 2.53 GHz, Mid 2009)" which uses 60W for some reason, the rest are all 13 inch Pro's
				if ((modelIdentifierNumber is equal to "5,4") or (modelIdentifierNumber is equal to "5,5") or (modelIdentifierNumber is equal to "7,1") or (modelIdentifierNumber is equal to "8,1") or (modelIdentifierNumber is equal to "9,2")) then
					set powerAdapterType to "60W MagSafe 1"
				else if ((modelIdentifierNumber is equal to "10,2") or (modelIdentifierNumber is equal to "11,1") or (modelIdentifierNumber is equal to "12,1")) then
					set powerAdapterType to "60W MagSafe 2"
				else if (modelIdentifierMajorNumber ≥ 17) then
					-- CONTINUOUS TODO: Check future MacBook Pro's to make sure Model ID pattern continues
					if (modelIdentifierMinorNumber = 1) then
						powerAdapterType = "61W USB-C"
					else
						powerAdapterType = "96W USB-C"
					end if
				else if (modelIdentifierMajorNumber ≥ 16) then
					if ((modelIdentifierMinorNumber = 2) or (modelIdentifierMinorNumber = 3)) then
						set powerAdapterType to "61W USB-C"
					else
						set powerAdapterType to "96W USB-C"
					end if
				else if (modelIdentifierMajorNumber ≥ 15) then
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
				if (modelIdentifierMajorNumber ≥ 8) then
					set powerAdapterType to "30W USB-C"
				else if (modelIdentifierMajorNumber ≥ 5) then
					set powerAdapterType to "45W MagSafe 2"
				else
					set powerAdapterType to "45W MagSafe 1"
				end if
			end if
			set powerAdapterRows to "

🔌	Power Adapter:
	" & powerAdapterType
		else
			set progress completed steps to (progress completed steps + 2)
		end if
		
		
		-- BLADE SSD COMPATIBILITY (https://beetstech.com/blog/apple-proprietary-ssd-ultimate-guide-to-specs-and-upgrades)
		
		set compatibleBladeSSDs to ""
		if (shortModelName is equal to "MacBook Air") then
			if ((modelIdentifierMajorNumber = 3) or (modelIdentifierMajorNumber = 4)) then
				set compatibleBladeSSDs to "Gen 1"
			else if (modelIdentifierMajorNumber = 5) then
				set compatibleBladeSSDs to "Gen 2B"
			else if (modelIdentifierMajorNumber = 6) then
				set compatibleBladeSSDs to "Gen 3A"
			else if (modelIdentifierMajorNumber = 7) then
				if (modelIdentifierMinorNumber = 1) then
					set compatibleBladeSSDs to "Gen 4C"
				else
					set compatibleBladeSSDs to "Gen 4A"
				end if
			end if
		else if (((shortModelName is equal to "MacBook Pro") and (modelIdentifierMajorNumber = 10)) or ((shortModelName is equal to "iMac") and (modelIdentifierMajorNumber = 13))) then
			set compatibleBladeSSDs to "Gen 2A"
		else if (((shortModelName is equal to "MacBook Pro") and (modelIdentifierMajorNumber = 11) and (modelIdentifierMinorNumber ≤ 3)) or ((shortModelName is equal to "iMac") and ((modelIdentifierMajorNumber = 14) or (modelIdentifierMajorNumber = 15))) or ((shortModelName is equal to "Mac Pro") and (modelIdentifierMajorNumber = 6)) or ((shortModelName is equal to "Mac mini") and (modelIdentifierMajorNumber = 7))) then
			set compatibleBladeSSDs to "Gen 3A or 3B"
		else if (((shortModelName is equal to "MacBook Pro") and ((modelIdentifierMajorNumber = 12) or ((modelIdentifierMajorNumber = 11) and (modelIdentifierMinorNumber ≥ 4)))) or ((shortModelName is equal to "iMac") and ((modelIdentifierMajorNumber = 16) or (modelIdentifierMajorNumber = 17)))) then
			set compatibleBladeSSDs to "Gen 4A or 4B"
		else if ((shortModelName is equal to "MacBook Pro") and (((modelIdentifierMajorNumber = 13) or (modelIdentifierMajorNumber = 14)) and (modelIdentifierMinorNumber = 1))) then
			set compatibleBladeSSDs to "Gen 5A"
		else if ((shortModelName is equal to "iMac") and ((modelIdentifierMajorNumber = 18) and ((modelIdentifierMinorNumber = 2) and (modelIdentifierMinorNumber = 3)))) then
			set compatibleBladeSSDs to "Gen 5B"
		end if
		
		
		set progress completed steps to (progress completed steps + 1)
		set progress description to "
" & computerIcon & "	Loading Marketing Model Name"
		
		-- MARKETING MODEL NAME INFORMATION
		
		set modelInfo to ""
		set marketingModelName to ""
		set rawMarketingModelName to shortModelName
		set didGetLocalMarketingModelName to false
		
		if (chipType is not equal to "UNKNOWN Chip") then
			try
				-- This local marketing model name only exists on Apple Silicon Macs.
				set marketingModelName to (do shell script ("bash -c " & (quoted form of "/usr/libexec/PlistBuddy -c 'Print :0:product-name' /dev/stdin <<< \"$(ioreg -arc IOPlatformDevice -k product-name)\" | tr -dc '[:print:]'"))) -- Remove non-printable characters because this decoded value could end with a null char.
				
				if (marketingModelName is not equal to "") then
					set didGetLocalMarketingModelName to true
				end if
			end try
		end if
		
		if (not didGetLocalMarketingModelName) then
			if (serialNumberModelPart is not equal to "XXXX") then
				set marketingModelNameWasCached to false
				set didDownloadMarketingModelName to false
				try
					-- If About This Mac has been opened, the Marketing Model Name will be cached in this user preference.
					-- Since "defaults read" has no option to traverse into keys of dictionary values, use the whole "defaults export" output and parse it with "PlistBuddy" to get at the specific key of the "CPU Names" dictionary value that we want.
					-- Using "defaults export" instead of accessing the plist file directly with "PlistBuddy" is important since preferences are not guaranteed to be written to disk if they were just set.
					set cachedMarketingModelName to (do shell script ("bash -c " & (quoted form of ("/usr/libexec/PlistBuddy -c \"Print :'CPU Names':" & serialNumberModelPart & "-en-US_US\" /dev/stdin <<< \"$(defaults export com.apple.SystemProfiler -)\""))))
					if (cachedMarketingModelName starts with shortModelName) then -- Make sure the value starts with the short model name, since technically anything could be set to this value manually.
						set marketingModelName to cachedMarketingModelName
						set marketingModelNameWasCached to true
					end if
				end try
				if (not marketingModelNameWasCached) then
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
							if ((year of the (current date)) < 2022) then
								try
									do shell script "systemsetup -setusingnetworktime off; systemsetup -setusingnetworktime on" user name adminUsername password adminPassword with administrator privileges
								end try
							end if
							do shell script "curl -m 5 -sL https://support-sp.apple.com/sp/product?cc=" & serialNumberModelPart & " -o " & (quoted form of marketingModelNameXMLpath)
							set didDownloadMarketingModelName to true
							exit repeat
						on error (downloadMarketingModelNameErrorMessage) number (downloadMarketingModelNameErrorNumber)
							set tryCount to tryCount + 1
							do shell script "rm -f " & (quoted form of marketingModelNameXMLpath)
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
						tell application "System Events" to tell first XML element of contents of XML file marketingModelNameXMLpath
							set marketingModelName to ((value of XML elements whose name is "configCode") as string)
						end tell
						
						if ((marketingModelName is equal to "") or (marketingModelName does not start with shortModelName)) then
							error "Unknown Marketing Model Name"
						else
							-- Cache marketing model name into the About This Mac preference key if it had to be downloaded.
							set speciallyQuotedMarketingModelNameToCache to marketingModelName
							if ((marketingModelName contains "(") or (marketingModelName contains ")")) then
								-- If the model contains parentheses, "defaults write" has trouble with it and the value needs to be specially quoted (along with using "quoted form of")
								-- https://apple.stackexchange.com/questions/300845/how-do-i-handle-e-g-correctly-escape-parens-in-a-defaults-write-key-val#answer-300853
								set speciallyQuotedMarketingModelNameToCache to "'" & marketingModelName & "'"
							end if
							try
								do shell script "defaults write com.apple.SystemProfiler 'CPU Names' -dict-add '" & serialNumberModelPart & "-en-US_US' " & (quoted form of speciallyQuotedMarketingModelNameToCache)
							end try
						end if
					else if (not marketingModelNameWasCached) then
						error "Failed to Download Marketing Model Name"
					end if
				on error (marketingModelNameErrorMessage) number (marketingModelNameErrorNumber)
					log "Marketing Model Name Error: " & marketingModelNameErrorMessage
					do shell script "rm -f " & (quoted form of marketingModelNameXMLpath)
					if (marketingModelNameErrorNumber is equal to -128) then
						do shell script "killall 'system_profiler'; rm -f " & (quoted form of restOfSystemOverviewInfoPath)
						quit
						delay 10
					end if
					set showInternetRequiredErrorPart to ""
					if (marketingModelNameErrorMessage is not equal to "Unknown Marketing Model Name") then set showInternetRequiredErrorPart to " - Internet REQUIRED"
					set modelInfo to shortModelName & " (⚠️ UNKNOWN Marketing Name" & showInternetRequiredErrorPart & " ⚠️)"
					
					if (showSystemInfoAppButton) then
						set modelInfo to modelInfo & "
	‼️	CHECK “System Information” FOR HARDWARE  ‼️"
					else
						set modelInfo to modelInfo & "
	‼️	CHECK “About This Mac” FOR MARKETING MODEL NAME  ‼️"
						set showAboutMacWindowButton to true
					end if
				end try
				do shell script "rm -f " & (quoted form of marketingModelNameXMLpath)
			else
				set modelInfo to shortModelName & " (⚠️ UNKNOWN Marketing Name - NO SERIAL ⚠️)
	‼️	LOOK UP MARKETING MODEL NAME FROM MODEL ID OR EMC  ‼️"
			end if
		end if
		
		if ((modelInfo is equal to "") and (marketingModelName is not equal to "")) then
			if (marketingModelName is equal to shortModelName) then
				set modelInfo to shortModelName & " (No Marketing Model Name Specified)"
			else
				set rawMarketingModelName to marketingModelName
				if (marketingModelName contains "Thunderbolt 3") then
					set AppleScript's text item delimiters to "Thunderbolt 3"
					set marketingModelNameThunderboltParts to (every text item of marketingModelName)
					set AppleScript's text item delimiters to "TB3"
					set marketingModelName to (marketingModelNameThunderboltParts as string)
				end if
				set AppleScript's text item delimiters to "-Inch"
				set marketingModelNameParts to (every text item of marketingModelName)
				if ((count of marketingModelNameParts) ≥ 2) then
					set AppleScript's text item delimiters to " 20"
					set marketingModelNameYearParts to (every text item of (text item 2 of marketingModelNameParts))
					set AppleScript's text item delimiters to " ’"
					set text item 2 of marketingModelNameParts to (marketingModelNameYearParts as string)
				end if
				set AppleScript's text item delimiters to "”"
				set modelInfo to (marketingModelNameParts as string)
			end if
		else if (modelInfo is equal to "") then
			set modelInfo to shortModelName & " (⚠️ UNKNOWN Marketing Name  - UNKNOWN ERROR ⚠️)
	‼️	CHECK “About This Mac” FOR MARKETING MODEL NAME  ‼️"
			set showAboutMacWindowButton to true
		end if
		
		set didGetMemoryInfo to false
		set memoryType to "⚠️ UNKNOWN Type"
		set memorySpeed to " @ UNKNOWN Speed ⚠️"
		set memoryNote to ""
		
		set didGetHardDriveInfo to false
		set hardDriveDiskIDs to {}
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
		if ((modelInfo is equal to "iMac (20”, Mid ’09)") or (modelInfo is equal to "iMac (21.5”, Late ’11)")) then -- Special Budget/Education Models
			set bluetoothInfo to "Manufactured Without Bluetooth"
			set didGetBluetoothInfo to true
		end if
		
		set didGetDiscDriveInfo to false
		set discDriveDetected to "⚠️	NOT Detected  ⚠️
	‼️	CHECK “System Information” FOR DISC BURNING	‼️
	‼️	         CHECK IF A DISC DRIVE IS INSTALLED								 ‼️
	‼️	CHECK CONNECTIONS, REPLACE IF NECESSARY		‼️"
		
		if (((shortModelName is equal to "iMac") and (modelIdentifierMajorNumber ≥ 13)) or ((shortModelName is equal to "MacBook") and (modelIdentifierMajorNumber ≥ 8)) or ((shortModelName is equal to "MacBook Pro") and (modelIdentifierMajorNumber ≥ 10)) or (shortModelName is equal to "MacBook Air") or ((shortModelName is equal to "Mac mini") and (((offset of "Server" in rawMarketingModelName) > 0) or (modelIdentifierMajorNumber ≥ 5))) or ((shortModelName is equal to "Mac Pro") and (modelIdentifierMajorNumber ≥ 6)) or (shortModelName is equal to "iMac Pro") or (shortModelName is equal to "Mac Studio")) then
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
			tell application "System Events" to tell property list file restOfSystemOverviewInfoPath
				repeat with i from 1 to (number of property list items)
					set thisDataTypeProperties to (item i of property list items)
					set thisDataType to ((value of property list item "_dataType" of thisDataTypeProperties) as string)
					if (thisDataType is equal to "SPMemoryDataType") then -- MEMORY TYPE & SPEED INFORMATION
						try
							tell me
								set progress completed steps to (progress completed steps + 1)
								set progress description to "
📊	Loading Memory Information"
							end tell
							set memoryInfo to (first property list item of property list item "_items" of thisDataTypeProperties)
							try
								set memoryUpgradeable to ((value of property list item "is_memory_upgradeable" of memoryInfo) as string)
								if (memoryUpgradeable is equal to "No") then set memoryNote to "
	🚫	RAM is Soldered Onboard (NOT Upgradeable)"
							end try
							try
								set memoryType to ((value of property list item "dimm_type" of memoryInfo) as string) -- This top level "Type" (not within any Banks), will only exist when running natively on Apple Silicon.
								set memoryType to (do shell script "echo " & (quoted form of memoryType) & " | tr -dc '[:alnum:]' | tr '[:lower:]' '[:upper:]'")
								set memorySpeed to ""
								set didGetMemoryInfo to true
							on error
								set memoryItems to (property list item "_items" of memoryInfo)
								repeat with j from 1 to (number of property list items in memoryItems)
									set thisMemoryItem to (property list item j of memoryItems)
									set thisMemoryType to ((value of property list item "dimm_type" of thisMemoryItem) as string)
									set thisMemorySlot to "Empty"
									if (thisMemoryType is not equal to "empty") then
										if (memoryType contains "UNKNOWN") then
											set memoryType to ((first word of thisMemoryType) as string)
											set memorySpeed to (" @ " & ((value of property list item "dimm_speed" of thisMemoryItem) as string))
										end if
										
										set thisMemorySlot to ((value of property list item "dimm_size" of thisMemoryItem) as string)
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
					else if ((thisDataType is equal to "SPSerialATADataType") or (thisDataType is equal to "SPNVMeDataType")) then -- HARD DRIVE INFORMATION
						try
							tell me
								set progress completed steps to (progress completed steps + 1)
								set progress description to "
📁	Loading Storage Information"
							end tell
							set hardDrivesList to {}
							set sataItems to (property list item "_items" of thisDataTypeProperties)
							repeat with j from 1 to (number of property list items in sataItems)
								set thisSataController to (property list item j of sataItems)
								set thisSataControllerName to ((value of property list item "_name" of thisSataController) as string)
								if (thisSataControllerName does not contain "Thunderbolt") then
									set thisSataControllerPortSataRevision to 0
									set thisSataControllerDriveSataRevision to 0
									
									if (thisDataType is equal to "SPSerialATADataType") then
										try
											set thisSataControllerPortSpeed to ((value of property list item "spsata_portspeed" of thisSataController) as string)
											
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
											set thisSataControllerNegotiatedLinkSpeed to ((value of property list item "spsata_negotiatedlinkspeed" of thisSataController) as string)
											
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
											set thisDiskModelName to ((value of property list item "_name" of thisSataControllerItem) as string)
											set thisDiskID to ((value of property list item "bsd_name" of thisSataControllerItem) as string)
											set thisSataItemSizeBytes to ((value of property list item "size_in_bytes" of thisSataControllerItem) as number)
											
											if (thisDataType is equal to "SPNVMeDataType") then
												set thisSataItemMediumType to "NVMe SSD" -- NVMe drives are always Solid State
											else
												set thisSataItemMediumType to ((value of property list item "spsata_medium_type" of thisSataControllerItem) as string)
											end if
											
											try
												set thisSataItemSmartStatus to ((value of property list item "smart_status" of thisSataControllerItem) as string)
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
													--	65GB Toshiba: APPLE SSD TS064E
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
													-- Gen 5B Examples:
													--	2TB: APPLE SSD AP2048L (https://www.ebay.com/itm/352638228107)
													
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
														set installedBladeSSD to "5B"
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
	👉	HDD NEGOTIATED TO SATA II (3 Gb/s) SPEED, BUT THATS OK  👍" -- https://discussions.apple.com/thread/250036019 & https://todo.freegeek.org/Ticket/Display.html?id=86977 & https://todo.freegeek.org/Ticket/Display.html?id=86981
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
												set (end of hardDrivesList) to ((round (thisSataItemSizeBytes / 1.0E+9)) as string) & " GB (" & ssdOrHdd & ")" & incorrectDriveInstalledNote & smartStatusWarning
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
							if ((count of hardDrivesList) > 0) then
								set AppleScript's text item delimiters to (linefeed & tab)
								set storageInfo to (hardDrivesList as string)
							end if
							set didGetHardDriveInfo to true
						on error (storageInfoErrorMessage) number (storageInfoErrorNumber)
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
								set thisGraphicsModel to ((words of ((value of property list item "sppci_model" of thisGraphicsItem) as string)) as string)
								if (macProRecalledSerialDatePartsMatched and (macProRecalledGraphicsCards contains thisGraphicsModel)) then set macProPossibleBadGraphics to true
								set thisGraphicsBusRaw to "unknown"
								try
									set AppleScript's text item delimiters to "_"
									set thisGraphicsBusCodeParts to (every text item of ((value of property list item "sppci_bus" of thisGraphicsItem) as string))
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
									set thisGraphicsVRAM to ((value of property list item "spdisplays_vram_shared" of thisGraphicsItem) as string)
									set thisGraphicsMemorySharedNote to " - Shared"
								on error number (graphicsVRAMSharedErrorNumber)
									if (graphicsVRAMSharedErrorNumber is equal to -128) then
										do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
										quit
										delay 10
									end if
								end try
								try
									set thisGraphicsVRAM to ((value of property list item "spdisplays_vram" of thisGraphicsItem) as string)
								on error number (graphicsVRAMErrorNumber)
									if (graphicsVRAMErrorNumber is equal to -128) then
										do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
										quit
										delay 10
									end if
								end try
								try
									set thisGraphicsCores to ((value of property list item "sppci_cores" of thisGraphicsItem) as string)
								on error number (graphicsCoresErrorNumber)
									if (graphicsCoresErrorNumber is equal to -128) then
										do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
										quit
										delay 10
									end if
								end try
								if (thisGraphicsVRAM is not equal to "UNKNOWN") then
									set graphicsMemoryParts to (words of thisGraphicsVRAM)
									if ((((item 2 of graphicsMemoryParts) as string) is equal to "MB") and (((item 1 of graphicsMemoryParts) as number) ≥ 1024)) then
										set graphicsMemoryGB to (((item 1 of graphicsMemoryParts) / 1024) as string)
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
							set graphicsInfo to (graphicsList as string)
							set AppleScript's text item delimiters to {"Intel ", "NVIDIA ", "AMD "}
							set graphicsInfoPartsWithoutBrands to (every text item of graphicsInfo)
							set AppleScript's text item delimiters to ""
							set graphicsInfo to (graphicsInfoPartsWithoutBrands as string)
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
									set wiFiStatus to ((value of property list item "spairport_status_information" of thisWiFiInterface) as string)
									if (wiFiStatus is not equal to "spairport_status_connected") then
										set wiFiInfo to "Wi-Fi Detected (⚠️ UNKNOWN Protocols - Wi-Fi DISABLED ⚠️)
	‼️	ENABLE WI-FI AND RELOAD  ‼️"
									end if
									set possibleWiFiProtocols to (words of ((value of property list item "spairport_supported_phymodes" of thisWiFiInterface) as string))
									repeat with thisPossibleWiFiProtocol in possibleWiFiProtocols
										set uppercasePossibleWiFiProtocol to (do shell script "echo " & (quoted form of (thisPossibleWiFiProtocol as string)) & " | tr '[:lower:]' '[:upper:]'")
										if ((uppercasePossibleWiFiProtocol is not equal to "802.11") and (wiFiProtocolsList does not contain uppercasePossibleWiFiProtocol)) then
											set (end of wiFiProtocolsList) to uppercasePossibleWiFiProtocol
										end if
									end repeat
								end try
							end repeat
							
							if ((count of wiFiProtocolsList) > 0) then
								set lastWiFiProtocol to ""
								if ((count of wiFiProtocolsList) > 1) then
									set lastWiFiProtocol to (last item of wiFiProtocolsList)
									set wiFiProtocolsList to (reverse of (rest of (reverse of wiFiProtocolsList)))
								end if
								set AppleScript's text item delimiters to ", "
								set wiFiProtocolsString to (wiFiProtocolsList as string)
								set singularOrPluralProtocols to " Protocols"
								if (lastWiFiProtocol is not equal to "") then
									set commaAndOrJustAnd to ", and "
									if ((count of wiFiProtocolsList) = 1) then set commaAndOrJustAnd to " and "
									set wiFiProtocolsString to wiFiProtocolsString & commaAndOrJustAnd & lastWiFiProtocol
								else
									set singularOrPluralProtocols to " Protocol"
								end if
								
								set wiFiInfo to "Wi-Fi Detected (Supports " & wiFiProtocolsString & singularOrPluralProtocols & ")"
							else
								error "No Wi-Fi Protocols Detected"
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
							set bluetoothItems to (first property list item of property list item "_items" of thisDataTypeProperties)
							try
								set bluetoothInfo to (property list item "local_device_title" of bluetoothItems)
								set bluetoothVersion to ((first word of ((value of property list item "general_hci_version" of bluetoothInfo) as string)) as string)
								if (bluetoothVersion starts with "0x") then set bluetoothVersion to ((first word of ((value of property list item "general_lmp_version" of bluetoothInfo) as string)) as string)
								if (bluetoothVersion is equal to "0x9") then set bluetoothVersion to "5.0" -- BT 5.0 will not be detected properly on High Sierra.
								set bluetoothSupportedFeaturesList to {}
								try
									set bluetoothLEsupported to ((value of property list item "general_supports_lowEnergy" of bluetoothInfo) as string)
									if (bluetoothLEsupported is equal to "attrib_Yes") then set (end of bluetoothSupportedFeaturesList) to "BLE"
								end try
								try
									set bluetoothHandoffSupported to ((value of property list item "general_supports_handoff" of bluetoothInfo) as string)
									if (bluetoothHandoffSupported is equal to "attrib_Yes") then set (end of bluetoothSupportedFeaturesList) to "Handoff"
								end try
								set bluetoothSupportedFeatures to ""
								if ((count of bluetoothSupportedFeaturesList) > 0) then
									set AppleScript's text item delimiters to ", "
									set bluetoothSupportedFeatures to " (Supports " & (bluetoothSupportedFeaturesList as string) & ")"
								end if
								set bluetoothInfo to "Bluetooth " & bluetoothVersion & " Detected" & bluetoothSupportedFeatures
								set didGetBluetoothInfo to true
							on error -- For some strange reason, detailed Bluetooth information no longer exists in Monterey, can only detect if it is present.
								set bluetoothInfo to (property list item "controller_properties" of bluetoothItems)
								set bluetoothChipset to ((value of property list item "controller_chipset" of bluetoothInfo) as string)
								if (bluetoothChipset is not equal to "") then
									set bluetoothInfo to "Bluetooth Detected"
									set didGetBluetoothInfo to true
								end if
							end try
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
								if (((value of property list item "device_cdwrite" of discDriveItems) as string) is not equal to "") then set (end of discWriteTypesList) to "CDs"
							on error number (checkForCDErrorNumber)
								if (checkForCDErrorNumber is equal to -128) then
									do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
									quit
									delay 10
								end if
							end try
							try
								if (((value of property list item "device_dvdwrite" of discDriveItems) as string) is not equal to "") then set (end of discWriteTypesList) to "DVDs"
							on error number (checkForDVDErrorNumber)
								if (checkForDVDErrorNumber is equal to -128) then
									do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
									quit
									delay 10
								end if
							end try
							try
								if (((value of property list item "device_bdwrite" of discDriveItems) as string) is not equal to "") then set (end of discWriteTypesList) to "Blu-rays"
							on error number (checkForBluRayErrorNumber)
								if (checkForBluRayErrorNumber is equal to -128) then
									do shell script "rm -f " & (quoted form of restOfSystemOverviewInfoPath)
									quit
									delay 10
								end if
							end try
							if ((count of discWriteTypesList) > 0) then
								set AppleScript's text item delimiters to ", "
								set discDriveDetected to "Detected (Supports Reading & Writing " & (discWriteTypesList as string) & ")"
								
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
									set batteryCondition to ((value of property list item "sppower_battery_health" of property list item "sppower_battery_health_info" of thisPowerItem) as string)
									if (batteryCondition is not equal to "Good") then -- https://support.apple.com/en-us/HT204054#battery
										set batteryCapacityPercentage to batteryCapacityPercentage & "
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
			if ((shortModelName is equal to "iMac") and ((offset of "21.5" in rawMarketingModelName) > 0)) then
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
				tell application "System Events" to tell property list file bluetoothInfoPath
					set bluetoothItems to (first property list item of property list item "_items" of first property list item)
					try
						set bluetoothInfo to (property list item "local_device_title" of bluetoothItems)
						set bluetoothVersion to ((first word of ((value of property list item "general_hci_version" of bluetoothInfo) as string)) as string)
						if (bluetoothVersion starts with "0x") then set bluetoothVersion to ((first word of ((value of property list item "general_lmp_version" of bluetoothInfo) as string)) as string)
						if (bluetoothVersion is equal to "0x9") then set bluetoothVersion to "5.0" -- BT 5.0 will not be detected properly on High Sierra.
						set bluetoothSupportedFeaturesList to {}
						try
							set bluetoothLEsupported to ((value of property list item "general_supports_lowEnergy" of bluetoothInfo) as string)
							if (bluetoothLEsupported is equal to "attrib_Yes") then set (end of bluetoothSupportedFeaturesList) to "BLE"
						end try
						try
							set bluetoothHandoffSupported to ((value of property list item "general_supports_handoff" of bluetoothInfo) as string)
							if (bluetoothHandoffSupported is equal to "attrib_Yes") then set (end of bluetoothSupportedFeaturesList) to "Handoff"
						end try
						set bluetoothSupportedFeatures to ""
						if ((count of bluetoothSupportedFeaturesList) > 0) then
							set AppleScript's text item delimiters to ", "
							set bluetoothSupportedFeatures to " (Supports " & (bluetoothSupportedFeaturesList as string) & ")"
						end if
						set bluetoothInfo to "Bluetooth " & bluetoothVersion & " Detected" & bluetoothSupportedFeatures
					on error -- For some strange reason, detailed Bluetooth information no longer exists in Monterey, can only detect if it is present.
						set bluetoothInfo to (property list item "controller_properties" of bluetoothItems)
						set bluetoothChipset to ((value of property list item "controller_chipset" of bluetoothInfo) as string)
						if (bluetoothChipset is not equal to "") then
							set bluetoothInfo to "Bluetooth Detected"
						end if
					end try
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
		
		
		if (isLaptop and (not didGetBatteryHealthInfo) and ((offset of "⚠️" in batteryCapacityPercentage) = 0)) then
			set batteryCapacityPercentage to batteryCapacityPercentage & "
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
			
			set progress description to "
🔒	Checking for Remote Management"
			delay 0.5
			
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
Remote Management (DEP/MDM)?" message "Remote Management check will be skipped in 10 seconds." buttons {"No", "Yes"} cancel button 1 default button 2 giving up after 10
					if (gave up of result) then error number -128
					set remoteManagementOutput to (do shell script "profiles renew -type enrollment; profiles show -type enrollment 2>&1; exit 0" with prompt "Administrator Permission is required
to check for Remote Management (DEP/MDM)." with administrator privileges)
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
					do shell script "afplay /System/Library/Sounds/Basso.aiff"
				end try
				set nextAllowedProfilesShowTime to "23 hours after last successful check"
				try
					set nextAllowedProfilesShowTime to ("at " & (do shell script "date -jv +23H -f '%FT%TZ %z' \"$(plutil -extract lastProfilesShowFetchTime raw /private/var/db/ConfigurationProfiles/Settings/.profilesFetchTimerCheck) +0000\" '+%-I:%M:%S %p on %D'"))
				end try
				display alert ("Unable to Check Remote Management Because of Once Every 23 Hours Rate Limiting

Next check will be allowed " & nextAllowedProfilesShowTime & ".") message "This should not have happened, please inform Free Geek I.T." as critical
			else if (remoteManagementOutput is not equal to "") then
				try
					set remoteManagementOutputParts to (paragraphs of remoteManagementOutput)
					
					if ((count of remoteManagementOutputParts) > 3) then
						set progress description to "
⚠️	Remote Management IS Enabled"
						set remoteManagementOrganizationName to "\"Unknown Organization\""
						set remoteManagementOrganizationContactInfo to {}
						
						repeat with thisRemoteManagementOutputPart in remoteManagementOutputParts
							set organizationNameOffset to (offset of "OrganizationName = \"" in thisRemoteManagementOutputPart)
							set organizationDepartmentOffset to (offset of "OrganizationDepartment = \"" in thisRemoteManagementOutputPart)
							set organizationEmailOffset to (offset of "OrganizationEmail = \"" in thisRemoteManagementOutputPart)
							set organizationPhoneOffset to (offset of "OrganizationPhone = \"" in thisRemoteManagementOutputPart)
							set organizationSupportPhoneOffset to (offset of "OrganizationSupportPhone = \"" in thisRemoteManagementOutputPart)
							
							if (organizationNameOffset > 0) then
								set remoteManagementOrganizationName to (text (organizationNameOffset + 19) thru -2 of thisRemoteManagementOutputPart)
							else if (organizationDepartmentOffset > 0) then
								set remoteManagementOrganizationDepartment to (text (organizationDepartmentOffset + 26) thru -3 of thisRemoteManagementOutputPart)
								if ((remoteManagementOrganizationDepartment is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationDepartment)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationDepartment
							else if (organizationEmailOffset > 0) then
								set remoteManagementOrganizationEmail to (text (organizationEmailOffset + 21) thru -3 of thisRemoteManagementOutputPart)
								if ((remoteManagementOrganizationEmail is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationEmail)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationEmail
							else if (organizationPhoneOffset > 0) then
								set remoteManagementOrganizationPhone to (text (organizationPhoneOffset + 21) thru -3 of thisRemoteManagementOutputPart)
								if ((remoteManagementOrganizationPhone is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationPhone)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationPhone
							else if (organizationSupportPhoneOffset > 0) then
								set remoteManagementOrganizationSupportPhone to (text (organizationSupportPhoneOffset + 28) thru -3 of thisRemoteManagementOutputPart)
								if ((remoteManagementOrganizationSupportPhone is not equal to "") and (remoteManagementOrganizationContactInfo does not contain remoteManagementOrganizationSupportPhone)) then set (end of remoteManagementOrganizationContactInfo) to remoteManagementOrganizationSupportPhone
							end if
						end repeat
						
						set remoteManagementOrganizationContactInfoDisplay to "NO CONTACT INFORMATION"
						if ((count of remoteManagementOrganizationContactInfo) > 0) then
							set AppleScript's text item delimiters to (linefeed & tab & tab)
							set remoteManagementOrganizationContactInfoDisplay to (remoteManagementOrganizationContactInfo as string)
						end if
						
						try
							activate
						end try
						try
							do shell script "afplay /System/Library/Sounds/Basso.aiff"
						end try
						set remoteManagementDialogButton to "                                                      Understood                                                      "
						-- For some reason centered text with padding in a dialog button like this doesn't work as expected on Catalina
						if (isCatalinaOrNewer) then set remoteManagementDialogButton to "Understood                                                                                                            "
						display dialog "	     ⚠️     REMOTE MANAGEMENT IS ENABLED ON THIS MAC     ⚠️

❌     MACS WITH REMOTE MANAGEMENT ENABLED CANNOT BE SOLD     ❌



🔒	THIS MAC IS MANAGED BY " & remoteManagementOrganizationName & "

🔑	ONLY " & remoteManagementOrganizationName & " CAN DISABLE REMOTE MANAGEMENT

☎️	" & remoteManagementOrganizationName & " MUST BE CONTACTED BY A MANAGER:
		" & remoteManagementOrganizationContactInfoDisplay & "

🆔	THE SERIAL NUMBER FOR THIS MAC IS \"" & serialNumber & "\"



👉 ‼️ INFORM AN INSTRUCTOR OR MANAGER BEFORE CONTINUING ‼️ 👈" buttons {remoteManagementDialogButton} with title "Remote Management Enabled"
					else
						set progress description to "
👍	Remote Management IS NOT Enabled"
						delay 2
					end if
				end try
			else
				set progress description to "
❌	FAILED to Check for Remote Management"
				delay 2
			end if
		end try
	end if
	
	set progress description to "
✅	Finished Loading " & (name of me) & ""
	
	if (isLaptop) then
		set batteryRows to "

🔋	Battery:
	" & batteryCapacityPercentage
		
		if (macBookPro13inch2016PossibleBatteryRecall or macBookPro15inch2015PossibleBatteryRecall) then
			set batteryRows to batteryRows & "
	⚠️	BATTERY MAY BE RECALLED FOR REPLACEMENT  ⚠️
	‼️	CHECK SERIAL NUMBER ON APPLE'S BATTERY RECALL PAGE  ‼️
	‼️	DON'T LEAVE ON & UNATTENDED UNTIL SERIAL IS CHECKED  ‼️"
		end if
	end if
	
	set showMojaveOnOldMacProButton to false
	
	set supportedOS to "
	OS X 10.11 “El Capitan”"
	if (supportsMonterey) then
		set supportedOS to "
 	macOS 12 “Monterey”"
	else if (supportsBigSur) then
		set supportedOS to "
	macOS 11 “Big Sur”
	⚠️	WILL NOT SUPPORT macOS 12 “Monterey”"
	else if (supportsCatalina) then
		set supportedOS to "
	macOS 10.15 “Catalina”
	⚠️	DOES NOT SUPPORT macOS 11 “Big Sur”"
	else if (supportsHighSierra) then
		set supportedOS to "
	macOS 10.13 “High Sierra”"
		if (supportsMojaveWithMetalCapableGPU) then
			set supportedOS to (supportedOS & "
	✅	CAN SUPPORT macOS 10.14 “Mojave”
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
	if (modelInfo does not contain modelIdentifierNumber) then set modelInfo to (modelIdentifierNumber & ": " & modelInfo)
	
	set displayMemorySlots to ""
	if ((count of memorySlots) > 0) then
		set AppleScript's text item delimiters to " + "
		set displayMemorySlots to " (" & (memorySlots as string) & ")"
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

💎	Supported OS:" & supportedOS
		
		set reloadButton to "Reload"
		if (macBookPro13inch2016PossibleBatteryRecall or macBookPro15inch2015PossibleBatteryRecall) then
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
		else if (showAboutMacWindowButton) then
			set reloadButton to "Open “About This Mac” & Reload"
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
				if (macBookPro13inch2016PossibleBatteryRecall or macBookPro15inch2015PossibleBatteryRecall or macBookPro13inch2017PossibleSSDRecall) then
					set the clipboard to serialNumber
					if (macBookPro13inch2016PossibleBatteryRecall) then
						do shell script "open 'https://support.apple.com/13inch-macbookpro-battery-replacement'"
					else if (macBookPro13inch2017PossibleSSDRecall) then
						do shell script "open 'https://support.apple.com/13-inch-macbook-pro-solid-state-drive-service'"
					else
						do shell script "open 'https://support.apple.com/15-inch-macbook-pro-battery-recall'"
					end if
					try
						activate
					end try
					display alert "\"" & serialNumber & "\" Copied to Clipboard" message "This computers serial number has been copied to the clipboard to search on Apple's recall page."
				else if (macBookProPossibleBadGraphics) then
					do shell script "open 'https://www.macrumors.com/2017/05/20/apple-ends-2011-macbook-pro-repair-program/'"
				else if (iMacPossibleBadGraphics) then
					do shell script "open 'https://www.macrumors.com/2013/08/16/apple-initiates-graphic-card-replacement-program-for-mid-2011-27-inch-imac/'"
				else if (macProPossibleBadGraphics) then
					do shell script "open 'https://www.macrumors.com/2016/02/06/late-2013-mac-pro-video-issues-repair-program/'"
				else if (macBookPro13inch2016PossibleBacklightRecall) then
					do shell script "open 'https://support.apple.com/13-inch-macbook-pro-display-backlight-service'"
				else if (macBookProButterflyKeyboardRecall) then
					do shell script "open 'https://support.apple.com/keyboard-service-program-for-mac-notebooks'"
				else if (macBookProScreenDelaminationRecall) then
					do shell script "open 'https://www.macrumors.com/2017/11/17/apple-extends-free-staingate-repairs/'"
				else if (iMacHingeRecall) then
					do shell script "open 'https://www.macrumors.com/2016/11/29/imac-broken-hinge-refunds-repair-program/'"
				else if (showSystemInfoAppButton) then
					try
						do shell script "open -b com.apple.SystemProfiler"
					end try
				else if (showAboutMacWindowButton) then
					try
						try
							((aboutThisMacAppPath as POSIX file) as alias)
							do shell script "open -n -a " & (quoted form of aboutThisMacAppPath)
						on error
							tell application "System Events" to tell application process "Finder" to click menu item "About This Mac" of menu 1 of menu bar item "Apple" of menu bar 1
						end try
					on error (openAboutThisMacErrorMessage)
						try
							activate
						end try
						display alert "Could Not Open “About This Mac”

" & openAboutThisMacErrorMessage message "
To open the “About This Mac” window, click the Apple logo in left of the menubar along the top of the screen and select “About This Mac” from the menu." as critical
					end try
				else if (showMojaveOnOldMacProButton) then
					do shell script "open 'https://support.apple.com/HT208898'"
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
		(("/Applications/Firmware Checker.app" as POSIX file) as alias)
		set (end of listOfAvailableTests) to "🎛	Firmware Checker"
	end try
	try
		(("/Applications/Restore OS.app" as POSIX file) as alias)
		(("/Users/Shared/Restore OS Images/" as POSIX file) as alias)
		set (end of listOfAvailableTests) to "💾	Restore OS"
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
					do shell script "open -n -a '/Applications/Internet Test.app'"
				else if (selectedLaunchTest is equal to "📢	Audio Test") then
					do shell script "open -n -a '/Applications/Audio Test.app'"
				else if (selectedLaunchTest is equal to "🎙	Microphone Test") then
					do shell script "open -n -a '/Applications/Microphone Test.app'"
				else if (selectedLaunchTest is equal to "🎥	Camera Test") then
					do shell script "open -n -a '/Applications/Camera Test.app'"
				else if (selectedLaunchTest is equal to "🇲🇺	Screen Test") then
					do shell script "open -n -a '/Applications/Screen Test.app'"
				else if (selectedLaunchTest is equal to "✌️	Trackpad Test") then
					do shell script "open -n -a '/Applications/Trackpad Test.app'"
				else if (selectedLaunchTest is equal to "⌨️	Keyboard Test") then
					do shell script "open -n -a '/Applications/Keyboard Test.app'"
				else if (selectedLaunchTest is equal to "🧠	CPU Stress Test") then
					do shell script "open -n -a '/Applications/CPU Stress Test.app'"
				else if (selectedLaunchTest is equal to "🍩	GPU Stress Test") then
					do shell script "open -n -a '/Applications/GPU Stress Test.app'"
				else if (selectedLaunchTest is equal to "🏥	Hard Drive Test (DriveDx)") then
					do shell script "open -n -a '/Applications/DriveDx.app'"
				else if (selectedLaunchTest is equal to "🎛	Firmware Checker") then
					do shell script "open -n -a '/Applications/Firmware Checker.app'"
				else if (selectedLaunchTest is equal to "💾	Restore OS") then
					do shell script "open -n -a '/Applications/Restore OS.app'"
				else if (selectedLaunchTest is equal to "🍏	Startup Picker") then
					do shell script "open -n -a '/Applications/Startup Picker.app'"
				else if (selectedLaunchTest is equal to "🏥	Show Raw Hard Drive SMART Data in Terminal") then
					if ((count of hardDriveDiskIDs) > 0) then
						repeat with thisDiskID in hardDriveDiskIDs
							try
								tell application "Terminal"
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
