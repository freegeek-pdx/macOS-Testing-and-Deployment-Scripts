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

-- App Icon is “Donut” from Twemoji (https://twemoji.twitter.com/) by Twitter (https://twitter.com)
-- Licensed under CC-BY 4.0 (https://creativecommons.org/licenses/by/4.0/)

use AppleScript version "2.7"
use scripting additions
use framework "AppKit"

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
	
	set intendedAppName to "GPU Stress Test" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
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
		do shell script ("touch " & (quoted form of (buildInfoPath & ".fgLaunchAfterSetup-org.freegeek." & ((words of (name of me)) as string)))) user name adminUsername password adminPassword with administrator privileges
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


try
	(("/Applications/GpuTest_OSX_x64_0.7.0/GpuTest.app" as POSIX file) as alias)
on error
	try
		activate
	end try
	display alert "“" & (name of me) & "” requires “GpuTest”" message "“GpuTest_OSX_x64_0.7.0” folder must be installed in the “Applications” folder." buttons {"Quit", "Download “GpuTest”"} cancel button 1 default button 2 as critical
	do shell script "open 'https://www.geeks3d.com/gputest/'"
	quit
	delay 10
end try

try
	(("/Applications/XRG.app" as POSIX file) as alias)
on error
	try
		activate
	end try
	display alert "“" & (name of me) & "” requires “XRG”" message "“XRG” must be installed in the “Applications” folder." buttons {"Quit", "Download “XRG”"} cancel button 1 default button 2 as critical
	do shell script "open 'https://gauchosoft.com/Products/XRG/'"
	quit
	delay 10
end try


set systemVersion to (system version of (system info))
considering numeric strings
	set isMojaveOrNewer to (systemVersion ≥ "10.14")
	set isCatalinaOrNewer to (systemVersion ≥ "10.15")
end considering

if (isMojaveOrNewer) then
	try
		tell application "System Events" to every window -- To prompt for Automation access on Mojave
	on error automationAccessErrorMessage number automationAccessErrorNumber
		if (automationAccessErrorNumber is equal to -1743) then
			try
				tell application "System Preferences" to activate
			end try
			try
				do shell script "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Automation'" -- The "Privacy_Automation" anchor is not exposed/accessible via AppleScript, but can be accessed via URL Scheme.
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

try
	tell application "System Events" to tell application process "Finder" to (get windows)
on error (assistiveAccessTestErrorMessage)
	if ((offset of "not allowed assistive" in assistiveAccessTestErrorMessage) > 0) then
		if (isMojaveOrNewer) then
			try
				tell application ("Text" & "Edit") to every window -- To prompt for Automation access on Mojave
			on error automationAccessErrorMessage number automationAccessErrorNumber
				if (automationAccessErrorNumber is equal to -1743) then
					try
						tell application "System Preferences" to activate
					end try
					try
						do shell script "open 'x-apple.systempreferences:com.apple.preference.security?Privacy_Automation'" -- The "Privacy_Automation" anchor is not exposed/accessible via AppleScript, but can be accessed via URL Scheme.
					end try
					try
						activate
					end try
					try
						display dialog "“" & (name of me) & "” must be allowed to control and perform actions in “TextEdit” to be able to function.


USE THE FOLLOWING STEPS TO FIX THIS ISSUE:

• Open the “System Preferences” application.

• Click the “Security & Privacy” preference pane.

• Select the “Privacy” tab.

• Select “Automation” in the source list on the left.

• Find “" & (name of me) & "” in the list on the right and turn on the “TextEdit” checkbox underneath it.

• Relaunch “" & (name of me) & "” (using the button below)." buttons {"Quit", "Relaunch “" & (name of me) & "”"} cancel button 1 default button 2 with title (name of me) with icon caution
						try
							do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -na \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
						end try
					end try
					quit
					delay 10
				end if
			end try
			try
				with timeout of 1 second
					tell application ("Text" & "Edit") to quit
				end timeout
			end try
		end if
		
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

• Relaunch “" & (name of me) & "” (using the button below)." buttons {"Quit", "Relaunch “" & (name of me) & "”"} cancel button 1 default button 2 with title (name of me) with icon caution
			try
				do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'do shell script \"open -na \\\"" & (POSIX path of (path to me)) & "\\\"\"' > /dev/null 2>&1 &"
			end try
		end try
		quit
		delay 10
	end if
end try


set AppleScript's text item delimiters to ""
set tmpPath to ((POSIX path of (((path to temporary items) as text) & "::")) & "fg" & ((words of (name of me)) as string) & "-") -- On Catalina, writing to trailing folder "/TemporaryItems/" often fails with "Operation not permitted" for some reason. Also, prefix all files with "fg" and name of script.

set isLaptop to false
set modelIdentifier to "UNKNOWN Model Identifier"
set serialNumberDatePart to "AA"
set serialNumberModelPart to "XXXX"

set graphicsCardModels to {}
set hasBuiltInGraphics to false

set modelAndGraphicsInfoPath to tmpPath & "modelAndGraphicsInfo.plist"
repeat 5 times
	try
		do shell script "system_profiler -xml SPHardwareDataType SPDisplaysDataType > " & (quoted form of modelAndGraphicsInfoPath)
		tell application "System Events" to tell property list file modelAndGraphicsInfoPath
			repeat with i from 1 to (number of property list items)
				set thisDataTypeProperties to (item i of property list items)
				set thisDataType to ((value of property list item "_dataType" of thisDataTypeProperties) as string)
				if (thisDataType is equal to "SPHardwareDataType") then
					set hardwareItems to (first property list item of property list item "_items" of thisDataTypeProperties)
					
					set shortModelName to ((value of property list item "machine_name" of hardwareItems) as string)
					if ((words of shortModelName) contains "MacBook") then set isLaptop to true
					set modelIdentifier to ((value of property list item "machine_model" of hardwareItems) as string)
					
					try
						set serialNumber to ((value of property list item "serial_number" of hardwareItems) as string) -- https://www.macrumors.com/2010/04/16/apple-tweaks-serial-number-format-with-new-macbook-pro/
						if (((length of serialNumber) ≥ 11) and (serialNumber is not equal to "Not Available")) then
							set serialNumberDatePart to (text 3 thru 5 of serialNumber)
							if ((count of serialNumber) is equal to 12) then set serialNumberDatePart to (text 2 thru -1 of serialNumberDatePart)
							set serialNumberModelPart to (text 9 thru -1 of serialNumber) -- The model part of the serial is the last 4 characters for 12 character serials and the last 3 characters for 11 character serials (which are very old and shouldn't actually be encountered).
						end if
					end try
				else if (thisDataType is equal to "SPDisplaysDataType") then
					set graphicsItems to (property list item "_items" of thisDataTypeProperties)
					
					repeat with j from 1 to (number of property list items in graphicsItems)
						set thisGraphicsItem to (property list item j of graphicsItems)
						set (end of graphicsCardModels) to ((value of property list item "sppci_model" of thisGraphicsItem) as string)
						
						set thisGraphicsBusRaw to "unknown"
						try
							set AppleScript's text item delimiters to "_"
							set thisGraphicsBusCodeParts to (every text item of ((value of property list item "sppci_bus" of thisGraphicsItem) as string))
							if ((count of thisGraphicsBusCodeParts) ≥ 2) then set thisGraphicsBusRaw to (text item 2 of thisGraphicsBusCodeParts)
						end try
						if (thisGraphicsBusRaw is equal to "builtin") then
							set hasBuiltInGraphics to true
						end if
					end repeat
				end if
			end repeat
		end tell
		exit repeat
	on error (modelAndGraphicsInfoErrorMessage)
		log "Model & Graphics Info Error: " & modelAndGraphicsInfoErrorMessage
		do shell script "rm -f " & (quoted form of modelAndGraphicsInfoPath) -- Delete incase User Canceled
		delay 1 -- Wait and try again because it seems to fail sometimes when run on login.
	end try
end repeat
do shell script "rm -f " & (quoted form of modelAndGraphicsInfoPath)

set shouldRunGPUStressTest to true
if (hasBuiltInGraphics and ((count of graphicsCardModels) is equal to 1)) then
	try
		try
			activate
		end try
		display alert "Running “" & (name of me) & "” is not required for Macs which only have integrated (built-in) graphics." message "Since this Mac does not have a discrete (PCI/PCIe) GPU, running “" & (name of me) & "” is not required." buttons {"Run “" & (name of me) & "” Anyway", "Don't Run “" & (name of me) & "”"} cancel button 1 default button 2
		set shouldRunGPUStressTest to false
	end try
end if

set gpuStressTestCompleted to false

if (shouldRunGPUStressTest) then
	set listOfRunningApps to {}
	try
		tell application "System Events"
			tell dock preferences to set autohide to false
			set listOfRunningApps to (short name of every application process where ((background only is false) and (short name is not "Finder") and (short name is not "Mac Scope") and (short name is not (name of me))))
		end tell
	end try
	if ((count of listOfRunningApps) > 0) then
		set pluralizedApplicationIsAre to "application is"
		if ((count of listOfRunningApps) > 1) then set pluralizedApplicationIsAre to "applications are"
		try
			activate
		end try
		set AppleScript's text item delimiters to ", "
		display alert "All Other Apps Must be Quit Before Running “" & (name of me) & "”" message "The following " & pluralizedApplicationIsAre & " currently running:
" & (listOfRunningApps as string) buttons {"Don't Run “" & (name of me) & "”", "Quit All Other Applications"} cancel button 1 default button 2 as critical
		try
			tell application "System Events" to set listOfRunningApps to (short name of every application process where ((background only is false) and (short name is not "Finder") and (short name is not "Mac Scope") and (short name is not (name of me))))
			if ((count of listOfRunningApps) > 0) then
				try
					repeat with thisAppName in listOfRunningApps
						try
							if (application thisAppName is running) then
								with timeout of 1 second
									tell application thisAppName to quit
								end timeout
							end if
						end try
					end repeat
				end try
				delay 3
				try
					tell application "System Events" to set listOfRunningApps to (short name of every application process where ((background only is false) and (short name is not "Finder") and (short name is not "Mac Scope") and (short name is not (name of me))))
					repeat with thisAppName in listOfRunningApps
						repeat 2 times
							try
								do shell script "pkill -f " & (quoted form of thisAppName)
							end try
						end repeat
					end repeat
				end try
			end if
		end try
	end if
	
	-- https://www.apple.com/support/macbookpro-videoissues/
	set macBookProRecalledGraphicsModels to {"MacBookPro8,2", "MacBookPro8,3", "MacBookPro10,1"}
	set macBookProPossibleBadGraphics to (macBookProRecalledGraphicsModels contains modelIdentifier)
	-- https://www.macrumors.com/2013/08/16/apple-initiates-graphic-card-replacement-program-for-mid-2011-27-inch-imac/
	set iMacRecalledGraphicsSerialModelParts to {"DHJQ", "DHJW", "DL8Q", "DNGH", "DNJ9", "DMW8", "DPM1", "DPM2", "DPNV", "DNY0", "DRVP", "DY6F", "F610"}
	set iMacPossibleBadGraphics to (iMacRecalledGraphicsSerialModelParts contains serialNumberModelPart)
	-- https://www.macrumors.com/2016/02/06/late-2013-mac-pro-video-issues-repair-program/
	set macProRecalledSerialDateParts to {"P5", "P6", "P7", "P8", "P9", "PC", "PD", "PF", "PG", "PH"}
	set macProPossibleBadGraphics to ((macProRecalledSerialDateParts contains serialNumberDatePart) and ((graphicsCardModels contains "AMD FirePro D500") or (graphicsCardModels contains "AMD FirePro D700")))
	
	set isBootedToSourceDrive to false
	set startupDiskCapacity to 0
	try
		tell application "System Events" to set startupDiskCapacity to ((capacity of startup disk) as number)
	end try
	if ((startupDiskCapacity ≤ 3.3E+10) and (serialNumber is equal to "C02R49Y5G8WP")) then
		set isBootedToSourceDrive to true
	end if
	
	set mustRunLongerStressTest to false
	set gpuRecallNote to ""
	set gpuRecallAlert to ""
	if (macBookProPossibleBadGraphics or iMacPossibleBadGraphics or macProPossibleBadGraphics) then
		set mustRunLongerStressTest to true
		set gpuRecallNote to " (GPU Recalled)"
		set gpuRecallAlert to "   ⚠️  GPU RECALLED  —  WILL RUN LONGER STRESS TEST  ⚠️
"
	end if
	
	set plugInLaptopAlert to ""
	if (isLaptop) then set plugInLaptopAlert to "

    🔌 MAKE SURE LAPTOP PLUGGED IN BEFORE STARTING ‼️"
	
	set defaultDurationTitle to "	⏲  GPU STRESS TEST WILL RUN FOR 30 MINUTES  ⏲"
	if (isBootedToSourceDrive) then
		set defaultDurationTitle to "	⏲  GPU STRESS TEST WILL RUN FOR 1 MINUTE  ⏲"
	else if (mustRunLongerStressTest) then
		set defaultDurationTitle to "     ‼️⏲ GPU STRESS TEST WILL RUN FOR 1.5 HOURS ⏲‼️"
	end if
	
	set testDurationSeconds to 0
	
	try
		activate
	end try
	display dialog gpuRecallAlert & defaultDurationTitle & plugInLaptopAlert & "

   👀 You don't need to watch the animation the whole time, but
   you should check back every 5-10 minutes to see if you notice
   any artifacts in the animation or if the “GpuTest” app crashed.

✅	GPU STRESS TEST PASSED IF:
	⁃ The “GpuTest” app runs without crashing.
	⁃ No artifacts are ever seen in the animation.
	⁃ The animation doesn't freeze for extended periods.
	⁃ The machine does not shut down at any point.
	⁃ If the Temperature Graph in the “XRG” app:
		⁃ Rises steadily and levels off throughout the test.

❌	GPU STRESS TEST FAILED IF:
	⁃ The “GpuTest” app doesn't launch or shows an error.
	⁃ The “GpuTest” app crashes at any point.
	⁃ Any artifacts are ever seen in the animation.
	⁃ The animation freezes for extended periods.
	⁃ The machine shuts down at any point.
	⁃ If the Temperature Graph in the “XRG” app:
		⁃ Spikes and dips throughout the test.
		⁃ Never levels off throughout the test.

   👉 CONSULT AN INSTRUCTOR IF GPU STRESS TEST FAILS ‼️" buttons {"Run Longer Test…", "Quit", "Start " & (name of me)} cancel button 2 default button 3 with title (name of me)
	
	if ((button returned of result) is equal to "Start " & (name of me)) then
		set testDurationDisplay to "30 Minutes"
		set testDurationSeconds to 1800
		if (isBootedToSourceDrive) then
			set testDurationDisplay to "1 Minute"
			set testDurationSeconds to 60
		else if (mustRunLongerStressTest) then
			set testDurationDisplay to "1.5 Hours"
			set testDurationSeconds to 5400
		end if
	else if ((button returned of result) is equal to "Run Longer Test…") then
		set durationsList to {"1 Hour", "1.5 Hours", "2 Hours", "2.5 Hours", "3 Hours", "4 Hours", "5 Hours", "6 Hours", "Forever"}
		if (mustRunLongerStressTest) then set durationsList to {"2 Hours", "2.5 Hours", "3 Hours", "4 Hours", "5 Hours", "6 Hours", "7 Hours", "8 Hours", "Forever"}
		try
			activate
		end try
		set selectedDuration to (choose from list durationsList with prompt "Select a Longer " & (name of me) & " Duration:" default items (text item 1 of durationsList) OK button name "Start " & (name of me) & "…" cancel button name "Quit" with title "Run Longer " & (name of me))
		if (selectedDuration is not equal to false) then
			set testDurationDisplay to (selectedDuration as string)
			if (testDurationDisplay is equal to "forever") then
				set testDurationSeconds to -1
			else
				set testDurationSeconds to (((first word of testDurationDisplay) as number) * 3600)
			end if
		end if
	end if
	
	if ((testDurationSeconds = -1) or (testDurationSeconds > 0)) then
		set antiAliasingNote to ""
		repeat
			if (application ("Gpu" & "Test") is running) then
				try
					do shell script "killall -SIGKILL GpuTest" -- SIGKILL so it can't crash when quit nicely.
				end try
			end if
			try
				with timeout of 1 second
					tell application "XRG" to quit
				end timeout
			end try
			
			set progress total steps to -1
			set progress description to "🚧	Detecting Screen Size"
			set progress additional description to "
🚫	DO NOT TOUCH ANYTHING WHILE APPS ARE SETTING UP"
			
			try
				repeat with thisWindow in (current application's NSApp's |windows|())
					if (thisWindow's isVisible() is true) then
						if (((thisWindow's title()) as string) is equal to (name of me)) then
							repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
								if (((thisProgressWindowSubView's className()) as string) is equal to "NSProgressIndicator") then
									(thisWindow's setLevel:(current application's NSScreenSaverWindowLevel))
									
									exit repeat
								end if
							end repeat
						end if
					end if
				end repeat
			end try
			
			set setupAppsErrorMessages to {}
			
			try
				tell application "System Events" to set delay interval of screen saver preferences to 0
			on error (errorMessage)
				set end of setupAppsErrorMessages to errorMessage
			end try
			
			try
				tell application "System Events" to tell dock preferences to set autohide to true
			on error (errorMessage)
				if (setupAppsErrorMessages does not contain getScreenBoundsErrorMessage) then set end of setupAppsErrorMessages to errorMessage
			end try
			
			if ((count of setupAppsErrorMessages) is equal to 0) then
				set menuBarHeight to 22
				try
					set menuBarHeight to (current application's NSMenu's menuBarHeight())
				on error (errorMessage) number (errorNumber)
					if ((errorNumber is equal to -128) and (setupAppsErrorMessages does not contain getScreenBoundsErrorMessage)) then set end of setupAppsErrorMessages to errorMessage
				end try
				set screenBounds to {0, 23, 1280, 764}
				set tmpFileForScreenBounds to tmpPath & "DetectingScreenSize"
				try
					repeat with textEditAttemptCount from 1 to 5
						try
							set didGetScreenBounds to false
							do shell script "touch " & (quoted form of tmpFileForScreenBounds)
							try
								do shell script "open -b com.apple.TextEdit " & (quoted form of tmpFileForScreenBounds)
							end try
							delay textEditAttemptCount
							set originalWindowBounds to {0, 0, -1, 0}
							tell application ("Text" & "Edit") -- This stops Script Editor from opening TextEdit automatially.
								repeat with thisTextEditWindow in windows
									if ((name of thisTextEditWindow) ends with "DetectingScreenSize") then
										tell thisTextEditWindow
											set originalWindowBounds to (get bounds)
											if ((textEditAttemptCount is equal to 2) or (textEditAttemptCount is equal to 4)) then -- Try performing "AXZoomWindow" action a couple times if "set zoomed" isn't working.
												try
													tell application "System Events" to tell application process ("Text" & "Edit") to tell (first window whose name ends with "Untitled") to perform action "AXZoomWindow" of (first button whose subrole is "AXFullScreenButton")
												on error
													set zoomed to true
												end try
											else
												set zoomed to true
											end if
										end tell
										exit repeat
									end if
								end repeat
								delay textEditAttemptCount
								repeat with thisTextEditWindow in windows
									if ((name of thisTextEditWindow) ends with "DetectingScreenSize") then
										tell thisTextEditWindow to set screenBounds to (get bounds)
										if (((item 3 of originalWindowBounds) is not equal to -1) and (((item 3 of originalWindowBounds) is not equal to (item 3 of screenBounds)) or ((item 4 of originalWindowBounds) is not equal to (item 4 of screenBounds)))) then set didGetScreenBounds to true
										exit repeat
									end if
								end repeat
								quit
							end tell
							if (didGetScreenBounds and ((item 3 of screenBounds) ≥ 1280) and ((item 4 of screenBounds) ≥ 764)) then exit repeat
						on error (errorMessage) number (errorNumber)
							try
								with timeout of 1 second
									if (application ("Text" & "Edit") is running) then tell application ("Text" & "Edit") to quit
								end timeout
							end try
							if (errorNumber is equal to -128) then error errorMessage number errorNumber
						end try
					end repeat
					if (((item 3 of screenBounds) < 1280) or ((item 4 of screenBounds) < 764)) then error "Couldn't Get Screen Bounds"
				on error (getScreenBoundsErrorMessage) number (getScreenBoundsErrorNumber)
					set screenBounds to {0, 23, 1280, 764} -- Want GPU Test to run with smaller window even if screen bounds fails. So, we also don't collect the errors.
					if ((getScreenBoundsErrorNumber is equal to -128) and (setupAppsErrorMessages does not contain getScreenBoundsErrorMessage)) then set end of setupAppsErrorMessages to getScreenBoundsErrorMessage
				end try
				try
					with timeout of 1 second
						if (application ("Text" & "Edit") is running) then tell application ("Text" & "Edit") to quit
					end timeout
				end try
				do shell script "rm -f " & (quoted form of tmpFileForScreenBounds)
			end if
			
			if ((count of setupAppsErrorMessages) is equal to 0) then
				try
					repeat with thisWindow in (current application's NSApp's |windows|())
						if (thisWindow's isVisible() is true) then
							if (((thisWindow's title()) as string) is equal to (name of me)) then
								repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
									if (((thisProgressWindowSubView's className()) as string) is equal to "NSProgressIndicator") then
										set progressWindowFrame to (thisWindow's frame())
										set thisWindowsScreenVisibleFrame to (thisWindow's screen()'s frame()) -- Need to use windows screen to get the true bottom edge of any screen that can be used with setFrameOrigin. Can't use visibleFrame because for some reason it never calculated with the Dock hidden.
										(thisWindow's setFrameOrigin:{((item 3 of screenBounds) - (item 1 of (item 2 of progressWindowFrame))), (item 2 of (item 1 of thisWindowsScreenVisibleFrame))})
										
										exit repeat
									end if
								end repeat
							end if
						end if
					end repeat
				on error (errorMessage) number (errorNumber)
					if (setupAppsErrorMessages does not contain errorMessage) then set end of setupAppsErrorMessages to errorMessage
				end try
			end if
			
			if ((count of setupAppsErrorMessages) is equal to 0) then
				set progress description to "🚧	Setting Up “XRG” Monitoring Application"
				try
					set xrgHeight to 140
					do shell script "open -a '/Applications/XRG.app'"
					delay 1
					tell application "System Events" to tell application process "XRG"
						repeat 3 times
							try
								set frontmost to true
								tell window 1
									set position to {(item 1 of screenBounds), (item 4 of screenBounds) - xrgHeight}
									set size to {((item 3 of screenBounds) - (item 1 of screenBounds) - 404), xrgHeight}
								end tell
								exit repeat
							on error (errorMessage) number (errorNumber)
								if (errorNumber is equal to -128) then error errorMessage number errorNumber
							end try
						end repeat
						set frontmost to true
						keystroke "," using command down
						delay 1
						if ((count of windows) < 2) then
							set frontmost to true
							click menu item 2 of menu 1 of menu bar item "XRG" of menu bar 1
							delay 1
						end if
						repeat with thisWindow in windows
							set frontmost to true
							if ((offset of "Preferences" in (title of thisWindow)) > 0) then
								set position of thisWindow to {(item 1 of screenBounds), (item 2 of screenBounds)}
								
								set frontmost to true
								click button 1 of toolbar 1 of thisWindow
								delay 0.5
								set closeButton to (button 1 of thisWindow)
								
								set frontmost to true
								click button 5 of toolbar 1 of thisWindow
								delay 0.5
								set selectedSensors to {}
								set temperaturePopUpButtons to (reverse of (get pop up buttons of thisWindow))
								repeat with thisPopUpButton in temperaturePopUpButtons
									set frontmost to true
									click thisPopUpButton
									set thisPopUpButtonMenuItems to (menu items of menu 1 of thisPopUpButton)
									set clickedMenuItem to false
									set sensorPrefixPickingOrder to {"GPU", "Northbridge", "CPU", "Heatsink", "Power", "Memory", "Misc"}
									repeat with thisSensorPrefix in sensorPrefixPickingOrder
										if (clickedMenuItem is false) then
											repeat with thisMenuItem in thisPopUpButtonMenuItems
												set thisMenuItemName to ((name of thisMenuItem) as string)
												if (selectedSensors does not contain thisMenuItemName) then
													if ((offset of thisSensorPrefix in thisMenuItemName) > 0) then
														set frontmost to true
														click thisMenuItem
														set end of selectedSensors to thisMenuItemName
														set clickedMenuItem to true
														exit repeat
													end if
												end if
											end repeat
										end if
									end repeat
									set frontmost to true
									if (clickedMenuItem is false) then click (item 1 of thisPopUpButtonMenuItems)
								end repeat
								
								set frontmost to true
								click button 2 of toolbar 1 of thisWindow
								delay 0.5
								set allAppearanceGraphTextSliders to (sliders of group 1 of thisWindow)
								if ((count of allAppearanceGraphTextSliders) is equal to 1) then
									set value of (item 1 of allAppearanceGraphTextSliders) to 1
								end if
								set allAppearanceOpacitySliders to (sliders of group 3 of thisWindow)
								if ((count of allAppearanceOpacitySliders) is equal to 6) then
									set value of (item 1 of allAppearanceOpacitySliders) to 1 -- Graph Foreground 3
									set value of (item 2 of allAppearanceOpacitySliders) to 1 -- Graph Foreground 2
									set value of (item 3 of allAppearanceOpacitySliders) to 1 -- Graph Foreground 1
									set value of (item 4 of allAppearanceOpacitySliders) to 1 -- Background
									set value of (item 5 of allAppearanceOpacitySliders) to 0.6 -- Border
									set value of (item 6 of allAppearanceOpacitySliders) to 1 -- Background
								end if
								
								set frontmost to true
								click button 1 of toolbar 1 of thisWindow
								delay 0.5
								set allGeneralCheckboxes to (checkboxes of thisWindow)
								if ((count of allGeneralCheckboxes) is equal to 1) then
									set checkForUpdatesCheckbox to (item 1 of allGeneralCheckboxes)
									if ((checkForUpdatesCheckbox's value as boolean) is not equal to false) then click checkForUpdatesCheckbox
								end if
								set allGeneralAppearanceTextFields to (text fields of group 3 of thisWindow)
								if ((count of allGeneralAppearanceTextFields) is equal to 1) then set value of (item 1 of allGeneralAppearanceTextFields) to "XRG"
								set allGeneralAppearancePopUpButtons to (pop up buttons of group 3 of thisWindow)
								if ((count of allGeneralAppearancePopUpButtons) is equal to 1) then
									set frontmost to true
									click (item 1 of allGeneralAppearancePopUpButtons)
									set frontmost to true
									click (item 2 of (menu items of menu 1 of (item 1 of allGeneralAppearancePopUpButtons)))
								end if
								set allGeneralAppearanceSliders to (sliders of group 3 of thisWindow)
								set value of (item 1 of allGeneralAppearanceSliders) to 0
								set allGeneralGraphDisplayCheckboxes to (checkboxes of group 1 of thisWindow)
								set shouldShowGraphs to {"GPU Graph", "Temperature Graph"}
								repeat with thisCheckbox in allGeneralGraphDisplayCheckboxes
									set frontmost to true
									if ((thisCheckbox's value as boolean) is not equal to (shouldShowGraphs contains (name of thisCheckbox))) then click thisCheckbox
								end repeat
								set allGeneralBehaviorPopUpButtons to (pop up buttons of group 2 of thisWindow)
								if ((count of allGeneralBehaviorPopUpButtons) is equal to 2) then
									set frontmost to true
									click (item 1 of allGeneralBehaviorPopUpButtons)
									set frontmost to true
									click (item 3 of (menu items of menu 1 of (item 1 of allGeneralBehaviorPopUpButtons)))
								end if
								
								set frontmost to true
								click closeButton
								
								exit repeat
							end if
						end repeat
						
						set frontmost to true
						tell window 1
							set position to {(item 1 of screenBounds), (item 4 of screenBounds) - xrgHeight}
							set size to {((item 3 of screenBounds) - (item 1 of screenBounds) - 404), xrgHeight}
						end tell
					end tell
				on error (setupXRGErrorMessage)
					if (setupAppsErrorMessages does not contain setupXRGErrorMessage) then set end of setupAppsErrorMessages to setupXRGErrorMessage
				end try
				
				if ((count of setupAppsErrorMessages) is equal to 0) then
					set progress description to "🚧	Calibrating Anti-Aliasing in “GpuTest” Application"
					try
						set msaaArgument to "0"
						repeat 6 times
							if (application ("Gpu" & "Test") is running) then
								try
									do shell script "killall -SIGKILL GpuTest" -- SIGKILL so it can't crash when quit nicely.
								on error (errorMessage) number (errorNumber)
									if (errorNumber is equal to -128) then error errorMessage number errorNumber
								end try
							end if
							
							if (application "XRG" is not running) then do shell script "open -a '/Applications/XRG.app'"
							
							set testName to "fur"
							if (modelIdentifier is equal to "iMac7,1") then set testName to "gi" -- iMac7,1's are too slow to handle FurMark, they always freeze. But they can run GiMark successfully.
							do shell script "open -a '/Applications/GpuTest_OSX_x64_0.7.0/GpuTest.app' --args '/test=" & testName & " /msaa=" & msaaArgument & " /width=" & ((item 3 of screenBounds) - (item 1 of screenBounds)) & " /height=" & ((item 4 of screenBounds) - (item 2 of screenBounds) - menuBarHeight) & "'"
							
							repeat 10 times
								try
									delay 0.5
									tell application "System Events" to tell application process "GpuTest" to tell window 1
										set position to {(item 1 of screenBounds), (item 2 of screenBounds)}
										delay 0.5
										set size to {((item 3 of screenBounds) - (item 1 of screenBounds)), ((item 4 of screenBounds) - (item 2 of screenBounds) - xrgHeight)}
									end tell
									exit repeat
								on error (errorMessage) number (errorNumber)
									if (errorNumber is equal to -128) then error errorMessage number errorNumber
								end try
							end repeat
							
							delay 10
							
							set currentGpuTestWindowTitle to "UNKNOWN GPU TEST WINDOW TITLE"
							try
								tell application "System Events" to tell application process "GpuTest" to set currentGpuTestWindowTitle to (title of window 1)
							on error (errorMessage) number (errorNumber)
								if (errorNumber is equal to -128) then error errorMessage number errorNumber
							end try
							
							set currentGpuTestFPS to 0
							try
								set AppleScript's text item delimiters to {" | ", " FPS, "}
								set currentGpuTestWindowTitleParts to (every text item of currentGpuTestWindowTitle)
								if ((count of currentGpuTestWindowTitleParts) ≥ 5) then
									set currentGpuTestFPS to ((text item 3 of currentGpuTestWindowTitleParts) as number)
								end if
							on error (errorMessage) number (errorNumber)
								if (errorNumber is equal to -128) then error errorMessage number errorNumber
							end try
							
							if (currentGpuTestFPS = 0) then
								set msaaArgument to "0"
							else if (currentGpuTestFPS < 8) then
								if (msaaArgument is equal to "0") then
									exit repeat
								else if (msaaArgument is equal to "2") then
									set msaaArgument to "0"
								else if (msaaArgument is equal to "4") then
									set msaaArgument to "2"
								else if (msaaArgument is equal to "8") then
									set msaaArgument to "4"
								end if
							else if (currentGpuTestFPS > 15) then
								if (msaaArgument is equal to "0") then
									set msaaArgument to "2"
								else if (msaaArgument is equal to "2") then
									set msaaArgument to "4"
								else if (msaaArgument is equal to "4") then
									set msaaArgument to "8"
								else if (msaaArgument is equal to "8") then
									exit repeat
								end if
							else
								exit repeat
							end if
						end repeat
						if (msaaArgument is not equal to "0") then set antiAliasingNote to " (" & msaaArgument & "x Anti-Aliasing)"
						if (application ("Gpu" & "Test") is not running) then error "“GpuTest” application is no longer running."
					on error (setupGpuTestErrorMessage)
						if (setupAppsErrorMessages does not contain setupGpuTestErrorMessage) then set end of setupAppsErrorMessages to setupGpuTestErrorMessage
					end try
				end if
			end if
			
			if ((count of setupAppsErrorMessages) > 0) then
				set userCanceled to false
				repeat with thisErrorMessage in setupAppsErrorMessages
					if ((offset of "canceled" in thisErrorMessage) > 0) then
						set userCanceled to true
						exit repeat
					end if
				end repeat
				try
					do shell script "killall -SIGKILL GpuTest" -- SIGKILL so it can't crash when quit nicely.
				end try
				try
					with timeout of 1 second
						tell application "XRG" to quit
					end timeout
				end try
				try
					tell application "System Events" to tell dock preferences to set autohide to false
				end try
				if (userCanceled) then
					quit
					delay 10
				else
					set AppleScript's text item delimiters to (linefeed & linefeed)
					try
						activate
					end try
					display alert "Failed to Setup “XRG” or “GpuTest” Apps" message (setupAppsErrorMessages as string) buttons {"Quit", "Try Again"} cancel button 1 default button 2 as critical giving up after 15
				end if
			else
				exit repeat
			end if
		end repeat
		
		try
			if (application "XRG" is not running) then do shell script "open -a '/Applications/XRG.app'"
			
			set hourGlass to "⏳"
			set testStartTime to (current date)
			set testFinishTime to testStartTime + testDurationSeconds
			set singularTestDurationDisplay to testDurationDisplay
			if ((last character of singularTestDurationDisplay) is equal to "s") then set singularTestDurationDisplay to (text 1 thru -2 of singularTestDurationDisplay)
			set progress total steps to testDurationSeconds
			set progress completed steps to 0
			if (testDurationSeconds > 0) then
				if ((antiAliasingNote is not equal to "") and (gpuRecallNote is not equal to "")) then
					set progress description to "⏱	Running for " & testDurationDisplay & antiAliasingNote & gpuRecallNote
				else
					set progress description to "⏱	Running " & singularTestDurationDisplay & " " & (name of me) & antiAliasingNote & gpuRecallNote
				end if
				set progress additional description to "
" & hourGlass & "	Elapsed Time: 0 Minutes  —  Completion Time: " & (time string of testFinishTime)
			else
				if ((antiAliasingNote is not equal to "") and (gpuRecallNote is not equal to "")) then
					set progress description to "⏱	Running Forever " & antiAliasingNote & gpuRecallNote
				else
					set progress description to "⏱	Running " & (name of me) & " Forever" & antiAliasingNote & gpuRecallNote
				end if
				set progress additional description to "
" & hourGlass & "	Elapsed Time: 0 Minutes  —  Click “Stop” Button to End"
			end if
			set alertWaitTime to 0
			repeat
				set progress completed steps to (progress completed steps + 30)
				delay 60 - alertWaitTime
				set progress completed steps to (progress completed steps + 30)
				set elapsedTime to ((current date) - testStartTime)
				if (elapsedTime ≥ 3600) then
					set elapsedHours to (((round ((elapsedTime / 3600) * 10)) / 10) as string)
					if ((text -2 thru -1 of elapsedHours) is equal to ".0") then set elapsedHours to (text 1 thru -3 of elapsedHours)
					set elapsedTimeDisplay to elapsedHours & " Hours"
					if (elapsedHours is equal to "1") then set elapsedTimeDisplay to "1 Hour"
				else
					set elapsedMinutes to ((round (elapsedTime / 60)) as string)
					set elapsedTimeDisplay to elapsedMinutes & " Minutes"
					if (elapsedMinutes is equal to "1") then set elapsedTimeDisplay to "1 Minute"
				end if
				set completionTimeString to "Click “Stop” Button to End"
				if (testDurationSeconds > 0) then set completionTimeString to "Completion Time: " & (time string of testFinishTime)
				if (hourGlass is equal to "⏳") then
					set hourGlass to "⌛️"
				else
					set hourGlass to "⏳"
				end if
				set progress additional description to "
" & hourGlass & "	Elapsed Time: " & elapsedTimeDisplay & "  —  " & completionTimeString
				set gpuTestStillRunning to false
				try
					set gpuTestStillRunning to (application ("Gpu" & "Test") is running)
				on error (errorMessage) number (errorNumber)
					if (errorNumber is equal to -128) then error errorMessage number errorNumber
				end try
				set alertWaitTime to 0
				if (gpuTestStillRunning) then
					if ((testDurationSeconds > 0) and ((current date) ≥ testFinishTime)) then
						try
							do shell script "killall -SIGKILL GpuTest" -- SIGKILL so it can't crash when quit nicely.
						on error (errorMessage) number (errorNumber)
							if (errorNumber is equal to -128) then error errorMessage number errorNumber
						end try
						set progress total steps to 1
						set progress completed steps to 1
						set progress description to "
🍩	" & (name of me) & " Completed   ✅"
						set progress additional description to ""
						try
							set picturesFolderPath to ((POSIX path of (path to pictures folder)) & (name of me) & "/")
							set screenshotDate to (do shell script "date +'%F at %-I.%M.%S %p'")
							do shell script "mkdir " & (quoted form of picturesFolderPath) & "; /usr/sbin/screencapture -x " & (quoted form of (picturesFolderPath & (name of me) & " Completed - Screen Shot " & screenshotDate & ".png")) & " " & (quoted form of (picturesFolderPath & (name of me) & " Completed (2nd Screen) - Screen Shot " & screenshotDate & ".png"))
							try
								do shell script "afplay /System/Library/Sounds/Glass.aiff"
							end try
						on error (errorMessage) number (errorNumber)
							if (errorNumber is equal to -128) then error errorMessage number errorNumber
						end try
						set gpuStressTestCompleted to true
						try
							activate
						end try
						display dialog "			🍩 " & (name of me) & " Completed  ✅


	✨	Did you ever see any artifacts in the animation?
		👉 If so, the " & (name of me) & " has FAILED.  ❌
	
	❄️	Did the animation freeze for extended periods?
		👉 If so, the " & (name of me) & " has FAILED.  ❌

	📈	Did the Temperature Graph in the “XRG” app
		spike and dip throughout or never level off?
		👉 If so, the " & (name of me) & " as FAILED.  ❌


	✅ Otherwise, the " & (name of me) & " has PASSED!  👍


👉 CONSULT INSTRUCTOR IF GPU STRESS TEST FAILED ‼️" buttons {"Quit"} default button 1 with title "Completed " & singularTestDurationDisplay & " " & (name of me)
						try
							with timeout of 1 second
								tell application "XRG" to quit
							end timeout
						on error (errorMessage) number (errorNumber)
							if (errorNumber is equal to -128) then error errorMessage number errorNumber
						end try
						exit repeat
					else
						if (application "XRG" is not running) then do shell script "open -a '/Applications/XRG.app'"
					end if
				else
					set testFailDuration to ((current date) - testStartTime)
					if (testFailDuration ≥ 3600) then
						set testFailHours to (((round ((testFailDuration / 3600) * 10)) / 10) as string)
						if ((text -2 thru -1 of testFailHours) is equal to ".0") then set testFailHours to (text 1 thru -3 of testFailHours)
						set testFailTimeDisplay to testFailHours & " hours"
						if (testFailHours is equal to "1") then set testFailHoursDisplay to "1 hour"
					else
						set testFailMinutes to ((round (testFailDuration / 60)) as string)
						set testFailTimeDisplay to testFailMinutes & " minutes"
						if (testFailMinutes is equal to 1) then set testFailTimeDisplay to "1 minute"
					end if
					set progress total steps to 1
					set progress completed steps to 1
					set progress description to "⁉️	“GpuTest” application is no longer running."
					set progress additional description to "
⏱	" & singularTestDurationDisplay & " " & (name of me) & " only ran for " & testFailTimeDisplay & "."
					try
						set picturesFolderPath to ((POSIX path of (path to pictures folder)) & (name of me) & "/")
						set screenshotDate to (do shell script "date +'%F at %-I.%M.%S %p'")
						do shell script "mkdir " & (quoted form of picturesFolderPath) & "; /usr/sbin/screencapture -x " & (quoted form of (picturesFolderPath & (name of me) & " Failed 1 - Screen Shot " & screenshotDate & ".png")) & " " & (quoted form of (picturesFolderPath & (name of me) & " Failed 1 (2nd Screen) - Screen Shot " & screenshotDate & ".png"))
						try
							do shell script "afplay /System/Library/Sounds/Basso.aiff"
						end try
					on error (errorMessage) number (errorNumber)
						if (errorNumber is equal to -128) then error errorMessage number errorNumber
					end try
					try
						activate
					end try
					display dialog "	⁉️ “GpuTest” application is no longer running.

	⏱ " & singularTestDurationDisplay & " " & (name of me) & " only ran for " & testFailTimeDisplay & ".


	💣 Did the “GpuTest” application crash?
		👉 If so, the " & (name of me) & " has FAILED.  ❌
	
	
	😵	Did you quit “GpuTest” because…
	
		✨	You saw artifacts in the animation?
			👉 If so, the " & (name of me) & " has FAILED.  ❌

		❄️	The animation was completely frozen?
			👉 If so, the " & (name of me) & " has FAILED.  ❌
	
		📈	The Temperature Graph in the “XRG” app
			was spiking and dipping or never leveling off?
			👉 If so, the " & (name of me) & " has FAILED.  ❌


	⚠️	Did “GpuTest” not crash and wasn't quit?
		👉 If so, re-run the " & (name of me) & ".  🔁


👉 CONSULT INSTRUCTOR IF GPU STRESS TEST FAILED ‼️" buttons {"Quit"} default button 1 with title "Failed " & singularTestDurationDisplay & " " & (name of me)
					try
						set picturesFolderPath to ((POSIX path of (path to pictures folder)) & (name of me) & "/")
						set screenshotDate to (do shell script "date +'%F at %-I.%M.%S %p'")
						do shell script "mkdir " & (quoted form of picturesFolderPath) & "; /usr/sbin/screencapture -x " & (quoted form of (picturesFolderPath & (name of me) & " Failed 2 - Screen Shot " & screenshotDate & ".png")) & " " & (quoted form of (picturesFolderPath & (name of me) & " Failed 2 (2nd Screen) - Screen Shot " & screenshotDate & ".png"))
					on error (errorMessage) number (errorNumber)
						if (errorNumber is equal to -128) then error errorMessage number errorNumber
					end try
					try
						with timeout of 1 second
							tell application "XRG" to quit
						end timeout
					end try
					exit repeat
				end if
			end repeat
		on error runtimeErrorMessage number runtimeErrorNumber
			if (runtimeErrorNumber is equal to -128) then
				set testStopDuration to ((current date) - testStartTime)
				if (testStopDuration ≥ 3600) then
					set testStopHours to (((round ((testStopDuration / 3600) * 10)) / 10) as string)
					if ((text -2 thru -1 of testStopHours) is equal to ".0") then set testStopHours to (text 1 thru -3 of testStopHours)
					set testStopTimeDisplay to testStopHours & " hours"
					if (testStopHours is equal to "1") then set testStopTimeDisplay to "1 hour"
				else
					set testStopMinutes to ((round (testStopDuration / 60)) as string)
					set testStopTimeDisplay to testStopMinutes & " minutes"
					if (testStopMinutes is equal to 1) then set testStopTimeDisplay to "1 minute"
				end if
				set progress total steps to 1
				set progress completed steps to 1
				set progress description to "🍩	" & (name of me) & " Stopped   ❌"
				set progress additional description to "
⏱	" & singularTestDurationDisplay & " " & (name of me) & " only ran for " & testStopTimeDisplay & "."
				try
					set picturesFolderPath to ((POSIX path of (path to pictures folder)) & (name of me) & "/")
					set screenshotDate to (do shell script "date +'%F at %-I.%M.%S %p'")
					do shell script "mkdir " & (quoted form of picturesFolderPath) & "; /usr/sbin/screencapture -x " & (quoted form of (picturesFolderPath & (name of me) & " Stopped - Screen Shot " & screenshotDate & ".png")) & " " & (quoted form of (picturesFolderPath & (name of me) & " Stopped (2nd Screen) - Screen Shot " & screenshotDate & ".png"))
				end try
				try
					do shell script "killall -SIGKILL GpuTest" -- SIGKILL so it can't crash when quit nicely.
				end try
				try
					with timeout of 1 second
						if (application "XRG" is running) then tell application "XRG" to quit
					end timeout
				end try
				try
					do shell script "afplay /System/Library/Sounds/Basso.aiff"
				end try
				try
					activate
				end try
				display dialog "			  🍩 " & (name of me) & " Stopped  ❌

	⏱ " & singularTestDurationDisplay & " " & (name of me) & " only ran for " & testStopTimeDisplay & ".
	
	
	😵	Did you stop " & (name of me) & " because…
	
		💣 The “GpuTest” application crash?
			👉 If so, the " & (name of me) & " has FAILED.  ❌
		
		✨	You saw artifacts in the animation?
			👉 If so, the " & (name of me) & " has FAILED.  ❌

		❄️	The animation was completely frozen?
			👉 If so, the " & (name of me) & " has FAILED.  ❌
	
		📈	The Temperature Graph in the “XRG” app
			was spiking and dipping or never leveling off?
			👉 If so, the " & (name of me) & " as FAILED.  ❌


	⚠️	Did you stop " & (name of me) & " for some other reason?
		👉 If so, re-run the " & (name of me) & ".  🔁


👉 CONSULT INSTRUCTOR IF GPU STRESS TEST FAILED ‼️" buttons {"Quit"} default button 1 with title "Stopped " & singularTestDurationDisplay & " " & (name of me)
				tell application "System Events" to tell dock preferences to set autohide to false
			else
				try
					activate
				end try
				display alert (name of me) & " Runtime Error Occurred" message runtimeErrorMessage as critical giving up after 15
			end if
		end try
	end if
end if
do shell script "rm -f /Users/Tester/_geeks3d_gputest_log.txt"
try
	tell application "System Events" to tell dock preferences to set autohide to false
end try

if (gpuStressTestCompleted or (not shouldRunGPUStressTest)) then
	try
		(("/Applications/DriveDx.app" as POSIX file) as alias)
		if (application ("Drive" & "Dx") is not running) then
			try
				activate
			end try
			display alert "Would you like to launch “DriveDx”
to test the internal hard drive?" message ("If this Mac happens to have multiple internal hard drives, remember to test all of them.") buttons {"No", "Yes"} cancel button 1 default button 2 giving up after 15
			do shell script "open -a '/Applications/DriveDx.app'"
		end if
	on error
		try
			(("/Applications/Internet Test.app" as POSIX file) as alias)
			if (application ("Internet" & " Test") is not running) then
				try
					activate
				end try
				display alert "
Would you like to launch “Internet Test”?" buttons {"No", "Yes"} cancel button 1 default button 2 giving up after 15
				do shell script "open -na '/Applications/Internet Test.app'"
			end if
		end try
	end try
end if
