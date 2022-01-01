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

use AppleScript version "2.4" -- Yosemite (10.10) or later
use scripting additions

set bundleIdentifierPrefix to "org.freegeek."

try
	set infoPlistPath to ((POSIX path of (path to me)) & "Contents/Info.plist")
	((infoPlistPath as POSIX file) as alias)
	
	set AppleScript's text item delimiters to "-"
	set correctBundleIdentifier to bundleIdentifierPrefix & ((words of (name of me)) as string)
	try
		set currentBundleIdentifier to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' " & (quoted form of infoPlistPath)) as string)
		if (currentBundleIdentifier is not equal to correctBundleIdentifier) then error "INCORRECT Bundle Identifier"
	on error
		do shell script "plutil -replace CFBundleIdentifier -string " & (quoted form of correctBundleIdentifier) & " " & (quoted form of infoPlistPath)
		
		try
			set currentCopyright to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :NSHumanReadableCopyright' " & (quoted form of infoPlistPath)) as string)
			if (currentCopyright does not contain "Twemoji") then error "INCORRECT Copyright"
		on error
			do shell script "plutil -replace NSHumanReadableCopyright -string " & (quoted form of ("Copyright © " & (year of (current date)) & " Free Geek
Designed and Developed by Pico Mitchell")) & " " & (quoted form of infoPlistPath)
		end try
		
		try
			set minSystemVersion to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' " & (quoted form of infoPlistPath)) as string)
			if (minSystemVersion is not equal to "10.13") then error "INCORRECT Minimum System Version"
		on error
			do shell script "plutil -replace LSMinimumSystemVersion -string '10.13' " & (quoted form of infoPlistPath)
			try
				do shell script "plutil -remove LSMinimumSystemVersionByArchitecture " & (quoted form of infoPlistPath)
			end try
		end try
		
		try
			set prohibitMultipleInstances to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :LSMultipleInstancesProhibited' " & (quoted form of infoPlistPath)) as number)
			if (prohibitMultipleInstances is equal to 0) then error "INCORRECT Multiple Instances Prohibited"
		on error
			do shell script "plutil -replace LSMultipleInstancesProhibited -bool true " & (quoted form of infoPlistPath)
		end try
		
		try
			set allowMixedLocalizations to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :CFBundleAllowMixedLocalizations' " & (quoted form of infoPlistPath)) as number)
			if (allowMixedLocalizations is equal to 1) then error "INCORRECT Localization"
		on error
			do shell script "plutil -replace CFBundleAllowMixedLocalizations -bool false " & (quoted form of infoPlistPath)
			do shell script "plutil -replace CFBundleDevelopmentRegion -string 'en_US' " & (quoted form of infoPlistPath)
		end try
		
		try
			set currentAppleEventsUsageDescription to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :NSAppleEventsUsageDescription' " & (quoted form of infoPlistPath)) as string)
			if (currentAppleEventsUsageDescription does not contain (name of me)) then error "INCORRECT AppleEvents Usage Description"
		on error
			do shell script "plutil -replace NSAppleEventsUsageDescription -string " & (quoted form of ("You MUST click the “OK” button for “" & (name of me) & "” to be able to function.")) & " " & (quoted form of infoPlistPath)
		end try
		
		try
			set currentVersion to ((do shell script "/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' " & (quoted form of infoPlistPath)) as string)
			if (currentVersion is equal to "1.0") then error "INCORRECT Version"
		on error
			tell application "System Events" to set myCreationDate to (creation date of (path to me))
			set shortCreationDateString to (short date string of myCreationDate)
			set AppleScript's text item delimiters to "/"
			set correctVersion to ((text item 3 of shortCreationDateString) & "." & (text item 1 of shortCreationDateString) & "." & (text item 2 of shortCreationDateString))
			do shell script "plutil -replace CFBundleShortVersionString -string " & (quoted form of correctVersion) & " " & (quoted form of infoPlistPath)
			try
				do shell script "plutil -remove CFBundleVersion " & (quoted form of infoPlistPath)
			end try
		end try
		
		do shell script "osascript -e 'delay 0.5' -e 'repeat while (application \"" & (POSIX path of (path to me)) & "\" is running)' -e 'delay 0.5' -e 'end repeat' -e 'try' -e 'do shell script \"chmod a-w \\\"" & ((POSIX path of (path to me)) & "Contents/Resources/Scripts/main.scpt") & "\\\"\"' -e 'do shell script \"codesign -s \\\"Developer ID Application\\\" --deep --force \\\"" & (POSIX path of (path to me)) & "\\\"\"' -e 'on error codeSignError' -e 'activate' -e 'display alert \"Code Sign Error\" message codeSignError' -e 'end try' -e 'do shell script \"open -n -a \\\"" & (POSIX path of (path to me)) & "\\\"\"' &> /dev/null &"
		quit
		delay 10
	end try
end try

global passwordCharacterShiftCount

set bundleIdentifierPrefix to "org.freegeek."
set currentYear to ((year of (current date)) as string)
set shortCurrentDateString to (short date string of (current date))

repeat
	set buildResultsOutput to {}
	
	tell application "Finder"
		set parentFolder to (container of (path to me))
		
		set fgPasswordsPlistPath to ((POSIX path of (parentFolder as alias)) & "Free Geek Passwords.plist")
		
		set adminPassword to ""
		try
			set adminPassword to (do shell script ("/usr/libexec/PlistBuddy -c 'Print :admin_password' " & (quoted form of fgPasswordsPlistPath)) as string)
		end try
		
		set wiFiPassword to ""
		try
			set wiFiPassword to (do shell script ("/usr/libexec/PlistBuddy -c 'Print :wifi_password' " & (quoted form of fgPasswordsPlistPath)) as string)
		end try
		
		if (adminPassword is equal to "") then
			set (end of buildResultsOutput) to "❌		FAILED TO RETRIEVE ADMINISTRATOR PASSWORD"
			set (end of buildResultsOutput) to ""
		else if (wiFiPassword is equal to "") then
			set (end of buildResultsOutput) to "❌		FAILED TO RETRIEVE WI-FI PASSWORD"
			set (end of buildResultsOutput) to ""
		else if ((name of parentFolder) is equal to "Build Tools") then
			set macLandFolder to (container of parentFolder)
			set zipsForAutoUpdateFolderPath to ((POSIX path of (macLandFolder as alias)) & "ZIPs for Auto-Update/")
			try
				do shell script "mkdir -p " & (quoted form of zipsForAutoUpdateFolderPath)
			end try
			set scriptTypeFolders to (get folders of macLandFolder)
			repeat with thisScriptTypeFolder in scriptTypeFolders
				if (((name of thisScriptTypeFolder) as string) is equal to "ZIPs for Auto-Update") then
					set latestVersionsFilePath to ((POSIX path of (thisScriptTypeFolder as alias)) & "latest-versions.txt")
					do shell script "rm -f " & (quoted form of latestVersionsFilePath)
					do shell script "touch " & (quoted form of latestVersionsFilePath)
					
					set zipFilesForAutoUpdate to (every file of thisScriptTypeFolder whose name extension is "zip")
					repeat with thisScriptZip in zipFilesForAutoUpdate
						if (((name of thisScriptZip) as string) is equal to "fgreset.zip") then
							do shell script ("ditto -x -k --noqtn " & (quoted form of (POSIX path of (thisScriptZip as alias))) & " ${TMPDIR}MacLand-Script-Builder-Versions/")
							
							set thisScriptVersionLine to (do shell script "cat ${TMPDIR}MacLand-Script-Builder-Versions/*.sh | grep -m 1 '# Version: '")
							
							if (thisScriptVersionLine contains "# Version: ") then
								do shell script "echo '" & (text 1 thru -5 of ((name of thisScriptZip) as string)) & ": " & ((text 12 thru -1 of thisScriptVersionLine) as string) & "' >> " & (quoted form of latestVersionsFilePath)
							end if
							
							do shell script "rm -f ${TMPDIR}MacLand-Script-Builder-Versions/*.sh"
						else
							do shell script "unzip -jo " & (quoted form of (POSIX path of (thisScriptZip as alias))) & " */Contents/Info.plist -d ${TMPDIR}MacLand-Script-Builder-Versions/"
							set thisAppName to (do shell script "/usr/libexec/PlistBuddy -c 'Print :CFBundleName' ${TMPDIR}MacLand-Script-Builder-Versions/Info.plist")
							set thisAppVersion to (do shell script "/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' ${TMPDIR}MacLand-Script-Builder-Versions/Info.plist")
							do shell script "echo '" & thisAppName & ": " & thisAppVersion & "' >> " & (quoted form of latestVersionsFilePath)
						end if
					end repeat
					do shell script "rm -rf ${TMPDIR}MacLand-Script-Builder-Versions/"
				else if ((((name of thisScriptTypeFolder) as string) is not equal to "Build Tools") and (((name of thisScriptTypeFolder) as string) is not equal to "fgMIB Resources")) then
					set scriptFoldersForThisScriptType to (get folders of thisScriptTypeFolder)
					repeat with thisScriptFolder in scriptFoldersForThisScriptType
						set thisScriptName to ((name of thisScriptFolder) as string)
						set thisScriptFolderPath to (POSIX path of (thisScriptFolder as alias))
						
						set AppleScript's text item delimiters to "-"
						set thisScriptHyphenatedName to ((words of thisScriptName) as string)
						
						-- Only build if .app doesn't exit and Source folder does exist
						set thisScriptAppPath to (thisScriptFolderPath & thisScriptName & ".app")
						
						try
							((thisScriptAppPath as POSIX file) as alias)
							set (end of buildResultsOutput) to "⏭		" & (name of thisScriptTypeFolder) & " > " & thisScriptName & " ALREADY BUILT"
						on error
							try
								set thisScriptSourcePath to (thisScriptFolderPath & "Source/" & thisScriptName & ".applescript")
								((thisScriptSourcePath as POSIX file) as alias)
								
								try
									do shell script "rm -f " & (quoted form of (thisScriptFolderPath & thisScriptHyphenatedName & ".zip"))
								end try
								try
									do shell script "rm -f " & (quoted form of (zipsForAutoUpdateFolderPath & thisScriptHyphenatedName & ".zip"))
								end try
								
								set thisScriptSource to (do shell script "cat " & (quoted form of thisScriptSourcePath))
								
								set obfuscatedAdminPasswordPlaceholder to "\"[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD]\""
								set obfuscatedWiFiPasswordPlaceholder to "\"[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD]\""
								
								set addBuildRunOnlyArg to ""
								if (thisScriptSource contains "-- Build Flag: Run-Only" or (thisScriptSource contains obfuscatedAdminPasswordPlaceholder) or (thisScriptSource contains obfuscatedWiFiPasswordPlaceholder)) then
									set addBuildRunOnlyArg to " -x"
									
									if ((thisScriptSource contains obfuscatedAdminPasswordPlaceholder) or (thisScriptSource contains obfuscatedWiFiPasswordPlaceholder)) then
										set passwordCharacterShiftCount to (random number from 100000 to 999999)
										
										if (thisScriptSource contains obfuscatedAdminPasswordPlaceholder) then
											tell me to set obfuscatedAdminPassword to shiftString(adminPassword)
											
											set AppleScript's text item delimiters to obfuscatedAdminPasswordPlaceholder
											set thisScriptSourcePartsSplitAtObfuscatedAdminPasswordPlaceholder to (every text item of thisScriptSource)
											
											set AppleScript's text item delimiters to "x(\"" & obfuscatedAdminPassword & "\")"
											set thisScriptSource to (thisScriptSourcePartsSplitAtObfuscatedAdminPasswordPlaceholder as string)
										end if
										
										if (thisScriptSource contains obfuscatedWiFiPasswordPlaceholder) then
											tell me to set obfuscatedWiFiPassword to shiftString(wiFiPassword)
											
											set AppleScript's text item delimiters to obfuscatedWiFiPasswordPlaceholder
											set thisScriptSourcePartsSplitAtObfuscatedWiFiPasswordPlaceholder to (every text item of thisScriptSource)
											
											set AppleScript's text item delimiters to "x(\"" & obfuscatedWiFiPassword & "\")"
											set thisScriptSource to (thisScriptSourcePartsSplitAtObfuscatedWiFiPasswordPlaceholder as string)
										end if
										
										set thisScriptSource to thisScriptSource & "

on x(s)
	set y to id of s as list
	repeat with c in y
		set contents of c to c - " & passwordCharacterShiftCount & "
	end repeat
	return string id y
end x"
									end if
									
									set (end of buildResultsOutput) to "✅🔒	" & (name of thisScriptTypeFolder) & " > BUILT " & thisScriptName & " (AS RUN-ONLY)"
								else
									set (end of buildResultsOutput) to "✅🛠	" & (name of thisScriptTypeFolder) & " > BUILT " & thisScriptName
								end if
								
								set thisScriptAppBundleIdentifier to (bundleIdentifierPrefix & thisScriptHyphenatedName)
								
								try
									do shell script "osacompile" & addBuildRunOnlyArg & " -o " & (quoted form of thisScriptAppPath) & " -e " & (quoted form of thisScriptSource)
									
									try
										do shell script ("tccutil reset All " & (quoted form of ("com.apple.ScriptEditor.id" & thisScriptHyphenatedName))) -- If it was previously built with Script Editor
									end try
									
									set thisScriptAppInfoPlistPath to (thisScriptAppPath & "/Contents/Info.plist")
									
									try
										((thisScriptAppInfoPlistPath as POSIX file) as alias)
										
										if (thisScriptSource contains "-- Build Flag: LSUIElement") then
											do shell script "plutil -replace LSUIElement -bool true " & (quoted form of thisScriptAppInfoPlistPath)
										end if
										
										do shell script "plutil -replace LSMinimumSystemVersion -string '10.13' " & (quoted form of thisScriptAppInfoPlistPath)
										do shell script "plutil -remove LSMinimumSystemVersionByArchitecture " & (quoted form of thisScriptAppInfoPlistPath)
										
										do shell script "plutil -replace LSMultipleInstancesProhibited -bool true " & (quoted form of thisScriptAppInfoPlistPath)
										
										do shell script "plutil -replace CFBundleAllowMixedLocalizations -bool false " & (quoted form of thisScriptAppInfoPlistPath) -- These two are so that error text is always in English,
										do shell script "plutil -replace CFBundleDevelopmentRegion -string 'en_US' " & (quoted form of thisScriptAppInfoPlistPath) -- so that I can trust and conditions which check errors.
										
										do shell script "plutil -replace NSAppleEventsUsageDescription -string " & (quoted form of ("You MUST click the “OK” button for “" & thisScriptName & "” to be able to function.")) & " " & (quoted form of thisScriptAppInfoPlistPath)
										
										if (thisScriptSource contains "-- Version: ") then
											set AppleScript's text item delimiters to "-- Version: "
											set thisScriptAppVersionPart to ((text item 2 of thisScriptSource) as string)
											set AppleScript's text item delimiters to {linefeed, return}
											set thisScriptAppVersion to ((first text item of thisScriptAppVersionPart) as string)
											do shell script "plutil -replace CFBundleShortVersionString -string " & (quoted form of thisScriptAppVersion) & " " & (quoted form of thisScriptAppInfoPlistPath)
										else
											do shell script "plutil -replace CFBundleShortVersionString -string " & (quoted form of (currentYear & "." & (word 1 of shortCurrentDateString) & "." & (word 2 of shortCurrentDateString))) & " " & (quoted form of thisScriptAppInfoPlistPath)
										end if
										
										do shell script "mv " & (quoted form of (thisScriptAppPath & "/Contents/MacOS/applet")) & " " & (quoted form of (thisScriptAppPath & "/Contents/MacOS/" & thisScriptName))
										do shell script "plutil -replace CFBundleExecutable -string " & (quoted form of thisScriptName) & " " & (quoted form of thisScriptAppInfoPlistPath)
										
										do shell script "mv " & (quoted form of (thisScriptAppPath & "/Contents/Resources/applet.rsrc")) & " " & (quoted form of (thisScriptAppPath & "/Contents/Resources/" & thisScriptName & ".rsrc"))
										
										do shell script "ditto " & (quoted form of (thisScriptFolderPath & "Source/" & thisScriptName & " Icon/applet.icns")) & " " & (quoted form of (thisScriptAppPath & "/Contents/Resources/" & thisScriptName & ".icns"))
										do shell script "plutil -replace CFBundleIconFile -string " & (quoted form of thisScriptName) & " " & (quoted form of thisScriptAppInfoPlistPath)
										do shell script "rm -f " & (quoted form of (thisScriptAppPath & "/Contents/Resources/applet.icns"))
										
										set thisScriptAppIconTwemojiAttribution to ""
										if (thisScriptSource contains "App Icon is “") then
											set AppleScript's text item delimiters to {"App Icon is “", "” from Twemoji"}
											set thisScriptAppIconEmojiName to ((text item 2 of thisScriptSource) as string)
											set thisScriptAppIconTwemojiAttribution to "

App Icon is “" & thisScriptAppIconEmojiName & "” from Twemoji by Twitter licensed under CC-BY 4.0"
										end if
										do shell script "plutil -replace NSHumanReadableCopyright -string " & (quoted form of ("Copyright © " & currentYear & " Free Geek
Designed and Developed by Pico Mitchell" & thisScriptAppIconTwemojiAttribution)) & " " & (quoted form of thisScriptAppInfoPlistPath)
										
										-- Do CFBundleIdentifier SECOND TO LAST because each script checks that it was set properly or alerts that not built correctly.
										do shell script "plutil -replace CFBundleIdentifier -string " & (quoted form of thisScriptAppBundleIdentifier) & " " & (quoted form of thisScriptAppInfoPlistPath)
										
										-- Add custom FGBuiltByMacLandScriptBuilder key VERY LAST for scripts to check to alert if not built correctly.
										do shell script "plutil -replace FGBuiltByMacLandScriptBuilder -bool true " & (quoted form of thisScriptAppInfoPlistPath)
										
										do shell script "chmod a-w " & (quoted form of (thisScriptAppPath & "/Contents/Resources/Scripts/main.scpt"))
										
										try
											(((thisScriptFolderPath & "Source/Resources/") as POSIX file) as alias)
											do shell script "ditto " & (quoted form of (thisScriptFolderPath & "Source/Resources/")) & " " & (quoted form of (thisScriptAppPath & "/Contents/Resources/"))
											do shell script "rm -f " & (quoted form of (thisScriptAppPath & "/Contents/Resources/.DS_Store"))
										end try
										
										try
											do shell script "xattr -crs " & (quoted form of thisScriptAppPath) -- Required to make sure codesign works
											do shell script "codesign -s 'Developer ID Application' --deep --force " & (quoted form of thisScriptAppPath)
											
											do shell script "ditto -c -k --keepParent --sequesterRsrc --zlibCompressionLevel 9 " & (quoted form of thisScriptAppPath) & " " & (quoted form of (zipsForAutoUpdateFolderPath & thisScriptHyphenatedName & ".zip"))
										on error codeSignError
											activate
											display alert "Code Sign & ZIP “" & thisScriptName & "” Error" message codeSignError
										end try
										
										do shell script "touch " & (quoted form of thisScriptAppPath)
									on error infoPlistError
										activate
										display alert "“" & thisScriptName & "” Info Plist Error" message infoPlistError
									end try
								on error osaCompileError
									activate
									display alert "Compile “" & thisScriptName & "” Error" message osaCompileError
								end try
								
								try
									do shell script ("tccutil reset All " & (quoted form of thisScriptAppBundleIdentifier))
								end try
								try
									do shell script ("tccutil reset All " & (quoted form of ("com.mycompany." & thisScriptHyphenatedName))) -- If it was previously built with default Script Debugger
								end try
								try
									do shell script ("tccutil reset All " & (quoted form of ("com.randomapplications." & thisScriptHyphenatedName))) -- If it was previously built with my Script Debugger
								end try
							on error
								try
									set thisFGresetSourcePath to (thisScriptFolderPath & "fgreset.sh")
									((thisFGresetSourcePath as POSIX file) as alias)
									
									do shell script "xattr -c " & (quoted form of thisFGresetSourcePath)
									
									do shell script "rm -rf ${TMPDIR}MacLand-Script-Builder-fgreset; mkdir -p ${TMPDIR}MacLand-Script-Builder-fgreset"
									
									-- CANNOT directly edit shell script source strings in AppleScript (like we do with AppleScript source) since it messes up escaped characters for ANSI styles. So, we'll use "sed" instead.
									do shell script "sed \"s/'\\[MACLAND SCRIPT BUILDER WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD\\]'/\\\"\\$(base64 -D <<< '$(/bin/echo -n " & (quoted form of adminPassword) & " | base64)')\\\"/\" " & (quoted form of thisFGresetSourcePath) & " > ${TMPDIR}MacLand-Script-Builder-fgreset/fgreset.sh"
									
									-- DO NOT "--keepParent" WHEN DITTO ZIPPING A SINGLE FILE!
									do shell script "ditto -c -k --sequesterRsrc --zlibCompressionLevel 9 ${TMPDIR}MacLand-Script-Builder-fgreset/fgreset.sh " & (quoted form of (zipsForAutoUpdateFolderPath & "fgreset.zip"))
									
									do shell script "rm -rf ${TMPDIR}MacLand-Script-Builder-fgreset"
									
									try
										do shell script "mkdir -p " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/Global/Scripts/"))
									end try
									try
										do shell script "rm -f " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/Global/Scripts/fgreset.zip"))
									end try
									try
										do shell script "ditto " & (quoted form of (zipsForAutoUpdateFolderPath & "fgreset.zip")) & " " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/Global/Scripts/"))
									end try
									
									set (end of buildResultsOutput) to "📄		" & (name of thisScriptTypeFolder) & " > ZIPPED " & thisScriptName
								on error
									set (end of buildResultsOutput) to "❌		" & (name of thisScriptTypeFolder) & " > " & thisScriptName & " NOT APPLESCRIPT APP"
								end try
							end try
						end try
						
						if ((((name of thisScriptTypeFolder) as string) is equal to "Production Scripts") or (thisScriptName is equal to "Free Geek Updater")) then
							if (thisScriptName is equal to "Free Geek Login Progress") then
								try
									do shell script "mkdir -p " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Install Packages Script/Tools/"))
								end try
								try
									do shell script "rm -f " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Install Packages Script/Tools/" & thisScriptHyphenatedName & ".zip"))
								end try
								try
									do shell script "ditto " & (quoted form of (zipsForAutoUpdateFolderPath & thisScriptHyphenatedName & ".zip")) & " " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Install Packages Script/Tools/"))
								end try
								
								try
									do shell script "mkdir -p " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/fg-error-occurred/Tools/"))
								end try
								try
									do shell script "rm -f " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/fg-error-occurred/Tools/" & thisScriptHyphenatedName & ".zip"))
								end try
								try
									do shell script "ditto " & (quoted form of (zipsForAutoUpdateFolderPath & thisScriptHyphenatedName & ".zip")) & " " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/fg-error-occurred/Tools/"))
								end try
								
								try
									do shell script "mkdir -p " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/fg-snapshot-reset/Tools/"))
								end try
								try
									do shell script "rm -f " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/fg-snapshot-reset/Tools/" & thisScriptHyphenatedName & ".zip"))
								end try
								try
									do shell script "ditto " & (quoted form of (zipsForAutoUpdateFolderPath & thisScriptHyphenatedName & ".zip")) & " " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/fg-snapshot-reset/Tools/"))
								end try
							else
								try
									do shell script "mkdir -p " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/User/fg-demo/Apps/"))
								end try
								try
									do shell script "rm -f " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/User/fg-demo/Apps/" & thisScriptHyphenatedName & ".zip"))
								end try
								try
									do shell script "ditto " & (quoted form of (zipsForAutoUpdateFolderPath & thisScriptHyphenatedName & ".zip")) & " " & (quoted form of ((POSIX path of (macLandFolder as alias)) & "fgMIB Resources/Prepare OS Package/Package Resources/User/fg-demo/Apps/"))
								end try
							end if
						end if
						
					end repeat
					
					set (end of buildResultsOutput) to ""
				end if
			end repeat
		end if
	end tell
	
	activate
	set buildResultsOutputReply to (choose from list (items 1 thru -2 of buildResultsOutput) with prompt "MacLand Script Builder Results" OK button name "Quit" cancel button name "Build Again" with title "MacLand Script Builder" with empty selection allowed)
	
	if (buildResultsOutputReply is not equal to false) then
		exit repeat
	end if
end repeat

-- From: https://stackoverflow.com/questions/14612235/protecting-an-applescript-script/14616010#14616010
on shiftString(sourceString)
	set stringID to id of sourceString as list
	repeat with thisCharacter in stringID
		set contents of thisCharacter to thisCharacter + passwordCharacterShiftCount
	end repeat
	return string id stringID
end shiftString
