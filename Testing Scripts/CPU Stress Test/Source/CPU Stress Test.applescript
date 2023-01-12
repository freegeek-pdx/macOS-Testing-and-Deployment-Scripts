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

-- Version: 2022.11.30-1

-- App Icon is “Brain” from Twemoji (https://twemoji.twitter.com/) by Twitter (https://twitter.com)
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
	
	set intendedAppName to "CPU Stress Test" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
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
	(("/Applications/CPUTest.app" as POSIX file) as alias)
on error
	try
		activate
	end try
	display alert "“" & (name of me) & "” requires “CPUTest”" message "“CPUTest” must be installed in the “Applications” folder." buttons {"Quit", "Download “CPUTest”"} cancel button 1 default button 2 as critical
	do shell script "open 'http://www.coolbook.se/CPUTest.html'"
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
		tell application id "com.apple.systemevents" to every window -- To prompt for Automation access on Mojave
	on error automationAccessErrorMessage number automationAccessErrorNumber
		if (automationAccessErrorNumber is equal to -1743) then
			try
				tell application id "com.apple.systempreferences" to activate
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
	tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "com.apple.finder") to (get windows)
on error (assistiveAccessTestErrorMessage)
	if ((offset of "not allowed assistive" in assistiveAccessTestErrorMessage) > 0) then
		try
			tell application id "com.apple.finder" to reveal (path to me)
		end try
		try
			tell application id "com.apple.systempreferences"
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


set waitForCpuTestLaunchSeconds to 3
repeat
	set cpuTestStatus to "Setting Up"
	set finishedTests to "0"
	set successfulTests to "0"
	set failedTests to "0"
	set remainingTests to "0"
	
	try
		do shell script "killall 'CPUTest'"
	end try
	try
		repeat
			do shell script "killall 'glucas'"
		end repeat
	end try
	
	set listOfRunningApps to {}
	try
		tell application id "com.apple.systemevents"
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
" & (listOfRunningApps as text) buttons {"Don't Run “" & (name of me) & "”", "Quit All Other Applications"} cancel button 1 default button 2 as critical
		try
			tell application id "com.apple.systemevents" to set listOfRunningAppIDs to (bundle identifier of every application process where ((background only is false) and (bundle identifier is not "com.apple.finder") and (bundle identifier is not "org.freegeek.Mac-Scope") and (bundle identifier is not (id of me))))
			if ((count of listOfRunningAppIDs) > 0) then
				try
					repeat with thisAppID in listOfRunningAppIDs
						try
							if (application id thisAppID is running) then
								with timeout of 1 second
									tell application id thisAppID to quit without saving
								end timeout
							end if
						end try
					end repeat
				end try
				delay 3
				try
					set AppleScript's text item delimiters to space
					tell application id "com.apple.systemevents" to set allRunningAppPIDs to ((unix id of every application process where ((background only is false) and (bundle identifier is not "com.apple.finder") and (bundle identifier is not "org.freegeek.Mac-Scope") and (bundle identifier is not (id of me)))) as text)
					if (allRunningAppPIDs is not equal to "") then
						do shell script ("kill " & allRunningAppPIDs)
					end if
				end try
			end if
		end try
	end if
	
	set isLaptop to false
	set processorsCount to "0"
	set processorTotalCoreCount to "0"
	
	set AppleScript's text item delimiters to ""
	set tmpPath to ((POSIX path of (((path to temporary items) as text) & "::")) & "fg" & ((words of (name of me)) as text) & "-") -- On Catalina, writing to trailing folder "/TemporaryItems/" often fails with "Operation not permitted" for some reason. Also, prefix all files with "fg" and name of script.
	set hardwareInfoPath to tmpPath & "hardwareInfo.plist"
	try
		do shell script "system_profiler -xml SPHardwareDataType > " & (quoted form of hardwareInfoPath)
		tell application id "com.apple.systemevents" to tell property list file hardwareInfoPath
			set hardwareItems to (first property list item of property list item "_items" of first property list item)
			set shortModelName to ((value of property list item "machine_name" of hardwareItems) as text)
			if ((words of shortModelName) contains "MacBook") then set isLaptop to true
			set processorsCount to ((value of property list item "packages" of hardwareItems) as text)
			set processorTotalCoreCount to ((value of property list item "number_processors" of hardwareItems) as text)
		end tell
	on error (hardwareInfoErrorMessage)
		log "Hardware Info Error: " & hardwareInfoErrorMessage
	end try
	do shell script "rm -f " & (quoted form of hardwareInfoPath)
	
	try
		activate
	end try
	set progress total steps to -1
	set progress description to "🚧	Setting Up “CPUTest” Application"
	set progress additional description to "
🚫	DO NOT CLICK ANYTHING WHILE APP IS SETTING UP"
	
	if (processorsCount is not equal to "0") then
		set processorsDisplayCount to processorsCount & " processors"
		if (processorsCount is equal to "1") then set processorsDisplayCount to "1 processor"
		try
			set processorThreadCount to ((do shell script "sysctl -n hw.logicalcpu_max") as number)
			do shell script "open -a '/Applications/CPUTest.app'"
			try
				activate
			end try
			delay waitForCpuTestLaunchSeconds
			try
				activate
			end try
			tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "se.coolbook.CPUTest")
				--set frontmost to true
				set cpuTestWindow to window 1
				repeat with thisWindow in windows
					if ((title of thisWindow) is "CPUTest") then
						set cpuTestWindow to thisWindow
						exit repeat
					end if
				end repeat
				set position of cpuTestWindow to {0, 0}
				click (radio button 1 of tab group 1 of cpuTestWindow)
				--set frontmost to true
				set testTypePopUpButton to (pop up button 1 of tab group 1 of cpuTestWindow)
				click testTypePopUpButton
				--set frontmost to true
				click (last item of (menu items of menu 1 of testTypePopUpButton))
				--set frontmost to true
				click (radio button 1 of tab group 1 of cpuTestWindow)
				--set frontmost to true
				set instancesPopUpButton to (pop up button 3 of tab group 1 of cpuTestWindow)
				click instancesPopUpButton
				set instancesPopUpButtonMenuItems to (menu items of menu 1 of instancesPopUpButton)
				set clickedMenuItem to false
				set selectedNumberOfInstances to 0
				repeat with thisInstancesMenuItem in instancesPopUpButtonMenuItems
					--set frontmost to true
					set thisInstancesMenuItemCount to ((name of thisInstancesMenuItem) as number)
					if (thisInstancesMenuItemCount ≥ processorThreadCount) then
						set selectedNumberOfInstances to thisInstancesMenuItemCount
						click thisInstancesMenuItem
						set clickedMenuItem to true
						exit repeat
					end if
				end repeat
				if (clickedMenuItem is false) then
					--set frontmost to true
					set lastInstancesMenuItem to (last item of instancesPopUpButtonMenuItems)
					set selectedNumberOfInstances to ((name of lastInstancesMenuItem) as number)
					click lastInstancesMenuItem
				end if
			end tell
			delay 0.5
			set progress total steps to -1
			set progress description to "
🧠	Finished Setting Up “CPUTest” Application"
			set progress additional description to ""
			delay 0.5
			set plugInLaptopAlert to ""
			if (isLaptop) then set plugInLaptopAlert to "


🔌	MAKE SURE LAPTOP PLUGGED IN BEFORE STARTING  ‼️
"
			try
				activate
			end try
			set buttonPadding to "            "
			display alert "“CPUTest” has been setup to run a full " & (name of me) & "…

This Mac has " & processorsDisplayCount & " with a total of " & processorTotalCoreCount & " cores that can run " & processorThreadCount & " parallel processes.


🔊	While the " & (name of me) & " runs, it is normal and
	expected for the fans to run high and loud.

👂	Listen closely to the computer to hear if any fans sound
	like they are ticking, clicking, or sounding abnormal.

⚡️	If you hear any electronic sizzling sounds, a serious
	issue may be happening or is about to happen.

⁉️	If you hear any QUESTIONABLE SOUNDS, or if the fans
	DO NOT run high, INFORM AN INSTRUCTOR IMMEDIATELY!

💣	Also, if this computer shuts itself down during
	" & (name of me) & ", that is a FAILURE." & plugInLaptopAlert message "
	“Test Type” has been set to “all” for the most thorough test.

	“Instances” has been set to “" & selectedNumberOfInstances & "” to test the entire processor capacity.


		   " & (name of me) & " should take approximately 10 minutes.
" buttons {(buttonPadding & "Quit" & buttonPadding), (buttonPadding & "Start " & (name of me) & "" & buttonPadding)} cancel button 1 default button 2
			if ((button returned of result) is equal to (buttonPadding & "Start " & (name of me) & "" & buttonPadding)) then
				set progress total steps to -1
				set progress description to "
🧠	Starting " & (name of me)
				set progress additional description to ""
				delay 0.5
				tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "se.coolbook.CPUTest")
					--set frontmost to true
					set cpuTestWindow to window 1
					repeat with thisWindow in windows
						if ((title of thisWindow) is "CPUTest") then
							set cpuTestWindow to thisWindow
							exit repeat
						end if
					end repeat
					set startStopButton to (last button of cpuTestWindow)
					if (((name of startStopButton) as text) is equal to "Start") then click startStopButton
				end tell
				try
					activate
				end try
				try
					set didExtraPassAfterFinished to false
					set hourGlass to "⏳"
					repeat
						if (application id ("se.coolbook." & "CPUTest") is running) then -- Break up App ID or else build will fail if not found during compilation when app is not installed.
							tell application id "com.apple.systemevents" to tell (first application process whose bundle identifier is "se.coolbook.CPUTest")
								set cpuTestWindow to window 1
								repeat with thisWindow in windows
									if ((title of thisWindow) is "CPUTest") then
										set cpuTestWindow to thisWindow
										exit repeat
									end if
								end repeat
								
								click (radio button 1 of tab group 1 of cpuTestWindow)
								
								set startStopButtonName to ((name of (last button of cpuTestWindow)) as text)
								
								set finishedTests to ((value of (static text 5 of tab group 1 of cpuTestWindow)) as text)
								set successfulTests to ((value of (static text 6 of tab group 1 of cpuTestWindow)) as text)
								set failedTests to ((value of (static text 7 of tab group 1 of cpuTestWindow)) as text)
								set remainingTests to ((value of (static text 10 of tab group 1 of cpuTestWindow)) as text)
								set elapsedTime to ((value of (static text 11 of tab group 1 of cpuTestWindow)) as text)
								
								tell me
									set progress total steps to ((remainingTests + finishedTests) as number)
									set progress completed steps to (finishedTests as number)
									set progress description to "🧠	Running " & (name of me)
									set progress additional description to "
" & hourGlass & "	Finished Tests: " & finishedTests & " of " & (remainingTests + finishedTests) & "  —  ⏱ Elapsed Time: " & elapsedTime
								end tell
								
								if (hourGlass is equal to "⏳") then
									set hourGlass to "⌛️"
								else
									set hourGlass to "⏳"
								end if
								
								if (startStopButtonName is equal to "Stop") then
									set cpuTestStatus to "Running"
								else if (didExtraPassAfterFinished) then
									try
										repeat
											do shell script "killall 'glucas'"
										end repeat
									end try
									
									if (remainingTests is equal to "0") then
										if ((failedTests is equal to "0") and (finishedTests is equal to successfulTests)) then
											set cpuTestStatus to "Passed"
										else
											set cpuTestStatus to "Failed"
										end if
									else
										set cpuTestStatus to "Incomplete"
									end if
									
									exit repeat
								else
									-- Do an extra pass to make sure to get the correct test counts.
									set didExtraPassAfterFinished to true
								end if
							end tell
						else
							try
								repeat
									do shell script "killall 'glucas'"
								end repeat
							end try
							set cpuTestStatus to "No Longer Running"
							exit repeat
						end if
						delay 1
					end repeat
				on error (runningCPUTestErrorMessage) number (runningCPUTestErrorNumber)
					try
						do shell script "killall 'CPUTest'"
					end try
					try
						repeat
							do shell script "killall 'glucas'"
						end repeat
					end try
					set cpuTestStatus to "Stopped"
				end try
			end if
		on error (setupCPUTestErrorMessage) number (setupCPUTestErrorNumber)
			try
				do shell script "killall 'CPUTest'"
			end try
			try
				repeat
					do shell script "killall 'glucas'"
				end repeat
			end try
			if (setupCPUTestErrorNumber is not equal to -128) then
				set cpuTestStatus to "Failed to Setup"
				set progress total steps to -1
				set progress description to "
🧠	" & (name of me) & " " & cpuTestStatus
				set progress additional description to ""
				try
					activate
				end try
				display alert "Failed to Setup “CPUTest”" message setupCPUTestErrorMessage buttons {"Quit", "Try Again"} cancel button 1 default button 2 as critical
				set waitForCpuTestLaunchSeconds to (waitForCpuTestLaunchSeconds + 2)
			else
				set cpuTestStatus to "Canceled"
			end if
		end try
	else
		try
			set cpuTestStatus to "Failed to Setup"
			set progress total steps to -1
			set progress description to "
🧠	" & (name of me) & " " & cpuTestStatus
			set progress additional description to ""
			
			try
				activate
			end try
			display alert "Failed to Retrieve Processor Information" message "“CPUTest” cannot be setup properly without knowing what the capabilities of the processor in this Mac." buttons {"Quit", "Try Again"} cancel button 1 default button 2 as critical
		on error
			set cpuTestStatus to "Canceled"
		end try
	end if
	
	set progress total steps to -1
	set progress description to "
🧠	" & (name of me) & " " & cpuTestStatus
	set progress additional description to ""
	
	try
		if (cpuTestStatus is equal to "Passed") then
			try
				do shell script "afplay /System/Library/Sounds/Glass.aiff"
			end try
			try
				activate
			end try
			display alert "
✅             " & (name of me) & " PASSED             ✅" buttons {"Done"} default button 1
			exit repeat
		else if (cpuTestStatus is equal to "Failed") then
			try
				do shell script "afplay /System/Library/Sounds/Basso.aiff"
			end try
			try
				activate
			end try
			display alert "❌              " & (name of me) & " FAILED              ❌" message "
“CPUTest” reports that " & failedTests & " out of " & (remainingTests + finishedTests) & " tested failed.

👉 “CPUTest” may fail if RAM is bad and not the CPU.
(If RAM is replaced, " & (name of me) & " MUST be run again and PASS before checking off " & (name of me) & ".)

‼️ CONSULT INSTRUCTOR BEFORE CONTINUING ‼️" buttons {"Quit", "Start Over"} cancel button 1 default button 2 as critical
		else if (cpuTestStatus is equal to "Incomplete") then
			try
				do shell script "afplay /System/Library/Sounds/Basso.aiff"
			end try
			try
				activate
			end try
			display alert "⚠️        " & (name of me) & " INCOMPLETE        ⚠️" message "
	" & (name of me) & " has not PASSED or FAILED.

  " & (name of me) & " must be started over to complete it.
" buttons {"Quit", "Start Over"} cancel button 1 default button 2 as critical
		else if (cpuTestStatus is equal to "No Longer Running") then
			try
				do shell script "afplay /System/Library/Sounds/Basso.aiff"
			end try
			try
				activate
			end try
			display alert "❌   " & (name of me) & " MAY HAVE FAILED   ❌

⚠️ “CPUTest” app is no longer running…" message "
💣 Did the “CPUTest” application crash?
	👉 If so, the " & (name of me) & " has FAILED.  ❌

	‼️	CONSULT AN INSTRUCTOR IF YOU	‼️
	‼️	DID NOT QUIT THE “CPUTest” APP	‼️
" buttons {"Quit", "Start Over"} cancel button 1 default button 2 as critical
		else if (cpuTestStatus is equal to "Stopped") then
			try
				do shell script "afplay /System/Library/Sounds/Basso.aiff"
			end try
			try
				activate
			end try
			display alert "
🚫            " & (name of me) & " STOPPED            🚫" buttons {"Quit", "Start Over"} cancel button 1 default button 2 as critical
		else if (cpuTestStatus is not equal to "Failed to Setup") then
			exit repeat
		end if
	on error
		exit repeat
	end try
	
	set progress total steps to -1
	set progress description to "
🔄	Restarting " & (name of me)
	set progress additional description to ""
end repeat

try
	do shell script "killall 'CPUTest'"
end try
try
	repeat
		do shell script "killall 'glucas'"
	end repeat
end try

if (cpuTestStatus is equal to "Passed") then
	try
		(("/Applications/GPU Stress Test.app" as POSIX file) as alias)
		if (application id ("org.freegeek." & "GPU-Stress-Test") is not running) then -- Break up App ID or else build will fail if not found during compilation when app is not installed.
			try
				activate
			end try
			display alert "
Would you like to launch “GPU Stress Test”?" buttons {"No", "Yes"} cancel button 1 default button 2 giving up after 15
			do shell script "open -na '/Applications/GPU Stress Test.app'"
		end if
	end try
end if
