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

-- Version: 2022.2.22-1

-- Build Flag: LSUIElement

use AppleScript version "2.7"
use scripting additions
use framework "Cocoa"

set currentBundleIdentifier to "UNKNOWN"

try
	set infoPlistPath to ((POSIX path of (path to me)) & "Contents/Info.plist")
	((infoPlistPath as POSIX file) as alias)
	
	set intendedAppName to "Free Geek Login Progress" -- Hardcode intended App name because Name or Bundle Identifier changes should not be done lightly or accidentally.
	
	try
		do shell script ("/usr/libexec/PlistBuddy -c 'Print :FGBuiltByMacLandScriptBuilder' "& (quoted form of infoPlistPath))
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
	set currentBundleIdentifier to ((do shell script ("/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "& (quoted form of infoPlistPath))) as string)
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

set isRunningAtLoginWindow to false
try
	set isRunningAtLoginWindow to ((do shell script "launchctl managername") is equal to "LoginWindow")
end try

set isResetting to ((POSIX path of (path to me)) contains "/fg-snapshot-reset/")

set logPath to "/Users/Shared/Build Info/Prepare OS Log.txt"
if (isResetting) then set logPath to "/Users/Shared/fg-snapshot-reset/log.txt"

set progress total steps to -1
set progress completed steps to 0

set doNotDisturbNote to "🚫	DO NOT DISTURB THIS MAC WHILE IT IS BEING CUSTOMIZED"

if (isResetting) then
	set progress description to "🧹	Resetting this Mac…"
	set doNotDisturbNote to "🚫	DO NOT DISTURB THIS MAC WHILE IT IS BEING RESET"
else
	set progress description to "🚧	Customizing this Mac…"
end if

set progress additional description to ("
" & doNotDisturbNote)

try
	repeat with thisWindow in (current application's NSApp's |windows|())
		if (thisWindow's isVisible() is true) then
			if (((thisWindow's title()) as string) is equal to (name of me)) then
				repeat with thisProgressWindowSubView in ((thisWindow's contentView())'s subviews())
					if (((thisProgressWindowSubView's className()) as string) is equal to "NSProgressIndicator") then
						if (isResetting) then
							(thisWindow's setTitle:"Free Geek Reset Progress")
						else
							(thisWindow's setTitle:"Free Geek Customizations Progress")
						end if
						
						-- Set Style Mask to ONLY be Titled, which make it not minimizable or resizable and hides all the titlebar buttons.
						(thisWindow's setStyleMask:(current application's NSWindowStyleMaskTitled as integer))
						
						-- Also do not want window to be movable so that it stays over the login fields.
						if (isRunningAtLoginWindow) then (thisWindow's setMovable:false) -- Only do this if at Login Window to make debugging easier when running in OS.
						
						-- Make the window wider so that the width doesn't need to be expanded automatically when long log entries get added, which makes re-centering look funky.
						set thisWindowSize to (item 2 of (thisWindow's frame()))
						(thisWindow's setContentSize:{650, (item 2 of thisWindowSize)}) -- Largest width seen was 630 for the log line deleting Secure Token References with the UUID.
						
						-- Center the window so it's in a nice spot on the screen and will leave a lot of room below for the log.
						-- The window will also keep being re-centered as the log grows so that the most contents will always stay visible no matter what the screen size is.
						-- Previously was just moving the window up 100 points to hide the login icon/fields, but that didn't work great as I added more logging and the window could grow to go below the bottom of the screen.
						-- So now, when the log is short the login icon/fields may be visible but should get covered as the log grows throughout the process.
						(thisWindow's |center|())
						
						-- Reference for Visibility at Login Screen: https://bitbucket.org/twocanoes/macdeploystick/src/a7989eddae93d3339b54e30356da0c6ff13fd795/first-run-install/Scripts/com.twocanoes.mds/LoginLog.app/Contents/Resources/LLLogWindowController.py#lines-130
						(thisWindow's setLevel:2.147483647E+9) -- maximumWindow AND THEN SOME (any more and the window is no longer topmost): https://michelf.ca/blog/2016/choosing-window-level/
						(thisWindow's setCanBecomeVisibleWithoutLogin:true)
					else if ((((thisProgressWindowSubView's className()) as string) is equal to "NSButton") and ((thisProgressWindowSubView's title() as string) is equal to "Stop")) then
						if (isRunningAtLoginWindow) then (thisProgressWindowSubView's setEnabled:false) -- Only do this if at Login Window to make debugging easier when running in OS.
					end if
				end repeat
			end if
		end if
	end repeat
end try

repeat
	try
		activate
	end try
	
	if ((progress completed steps) is equal to 0) then
		try
			((logPath as POSIX file) as alias)
			
			set logOutput to (do shell script ("cat " & (quoted form of logPath)))
			
			if (logOutput contains "ERROR:") then
				set progress total steps to 1
				set progress completed steps to 1
				
				if (isResetting) then
					set progress description to "❌	Error Occurred While Resetting this Mac"
				else
					set progress description to "❌	Error Occurred While Customizing this Mac"
				end if
				
				set progress additional description to ("
‼️	PLEASE INFORM AND DELIVER THIS MAC TO FREE GEEK I.T.

" & logOutput)
			else
				set progress additional description to ("
" & doNotDisturbNote & "

" & logOutput)
			end if
		end try
		
		if ((progress completed steps) is equal to 0) then -- Do not check for completion if an error was detected in the log.
			try
				-- The LaunchDaemon being deleted indicates successful completion.
				if (isResetting) then
					(("/Library/LaunchDaemons/org.freegeek.fg-snapshot-reset.plist" as POSIX file) as alias)
				else
					(("/Library/LaunchDaemons/org.freegeek.fg-install-packages.plist" as POSIX file) as alias)
				end if
			on error
				set progress total steps to 1
				set progress completed steps to 1
				
				if (isResetting) then
					set progress description to "✅	Successfully Reset this Mac"
					set progress additional description to (progress additional description & "

⤵️	SHUTTING DOWN THIS MAC")
				else
					set progress description to "✅	Successfully Customized this Mac"
					set progress additional description to (progress additional description & "

🔄	REBOOTING THIS MAC")
				end if
			end try
		end if
		
		try
			repeat with thisWindow in (current application's NSApp's |windows|())
				if (thisWindow's isVisible() is true) then
					set thisWindowTitle to ((thisWindow's title()) as string)
					if ((thisWindowTitle is equal to (name of me)) or (thisWindowTitle ends with " Progress")) then
						-- Force display before re-centering since sometimes it takes a moment for the window contents to be updated on their own which can cause the centering to happen before the contents update.
						((thisWindow's contentView())'s display())
						
						-- Keep re-centering window so the most contents will always be displayed no matter how long the log gets and what the screen size is.
						(thisWindow's |center|())
					end if
				end if
			end repeat
		end try
	end if
	
	delay 1
end repeat
