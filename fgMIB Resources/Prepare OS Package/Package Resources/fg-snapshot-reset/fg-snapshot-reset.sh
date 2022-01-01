#!/bin/bash

#
# Created by Pico Mitchell on 3/15/21.
# For MacLand @ Free Geek
#
# MIT License
#
# Copyright (c) 2021 Free Geek
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
# WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#

# NOTICE: This script will only exist on boot to be able to run via LaunchDaemon when booting after restoring from the reset Snapshot.
# ALSO: fg-prepare-os will have created AppleSetupDone to not show Setup Assistant BEFORE creating the reset Snapshot so that Setup Assistant would also not show during Snapshot reset.

readonly SCRIPT_VERSION='2021.12.30-1'

SCRIPT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd -P)"
readonly SCRIPT_DIR

launch_daemon_path='/Library/LaunchDaemons/org.freegeek.fg-snapshot-reset.plist'

launch_login_progress_app() {
	if [[ -f "${SCRIPT_DIR}/Tools/Free-Geek-Login-Progress.zip" && ! -d "${SCRIPT_DIR}/Tools/Free Geek Login Progress.app" ]]; then
		ditto -x -k --noqtn "${SCRIPT_DIR}/Tools/Free-Geek-Login-Progress.zip" "${SCRIPT_DIR}/Tools" &> /dev/null
		touch "${SCRIPT_DIR}/Tools/Free Geek Login Progress.app"
	fi

	if [[ -d "${SCRIPT_DIR}/Tools/Free Geek Login Progress.app" ]]; then
		# Cannot open "Free Geek Login Progress" directly when at Login Window, but a LaunchAgent with LimitLoadToSessionType=LoginWindow and "launchctl load -S LoginWindow" can open it.

		echo "<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">
<plist version=\"1.0\">
<dict>
	<key>Label</key>
	<string>org.freegeek.Free-Geek-Login-Progress</string>
	<key>ProgramArguments</key>
	<array>
		<string>/usr/bin/open</string>
		<string>-n</string>
		<string>-a</string>
		<string>${SCRIPT_DIR}/Tools/Free Geek Login Progress.app</string>
	</array>
	<key>StandardOutPath</key>
	<string>/dev/null</string>
	<key>StandardErrorPath</key>
	<string>/dev/null</string>
	<key>RunAtLoad</key>
	<true/>
	<key>LimitLoadToSessionType</key>
	<string>LoginWindow</string>
</dict>
</plist>" > '/Library/LaunchAgents/org.freegeek.Free-Geek-Login-Progress.plist'

		launchctl load -S LoginWindow '/Library/LaunchAgents/org.freegeek.Free-Geek-Login-Progress.plist'

		for (( wait_for_progress_app_seconds = 0; wait_for_progress_app_seconds < 15; wait_for_progress_app_seconds ++ )); do
			if pgrep -q 'Free Geek Login Progress'; then
				break
			else
				sleep 1
			fi
		done

		launchctl unload -S LoginWindow '/Library/LaunchAgents/org.freegeek.Free-Geek-Login-Progress.plist'
		rm -f '/Library/LaunchAgents/org.freegeek.Free-Geek-Login-Progress.plist'
	fi
}

if [[ "${SCRIPT_DIR}" == '/Users/Shared/fg-snapshot-reset' && -f "${launch_daemon_path}" && -f '/private/var/db/.AppleSetupDone' && "${EUID:-$(id -u)}" == '0' && \
	  "$(dscl . -list /Users 2> /dev/null | grep -v '^_' | xargs)" == 'daemon nobody root' && "$(fdesetup isactive)" == 'false' && \
	  -f '/Users/Shared/Build Info/Prepare OS Log.txt' && "$(tail -1 '/Users/Shared/Build Info/Prepare OS Log.txt')" == *'Creating Reset Snapshot' ]]; then
	
	if [[ -f "${SCRIPT_DIR}/log.txt" && "$(tail -1 "${SCRIPT_DIR}/log.txt")" == *'ERROR:'* ]]; then
		# If rebooted after previous error, just re-display error and do not proceed.


		# ANNOUNCE ERROR (For some reason "say" does not work on macOS 11 Big Sur when run on boot via LaunchDaemon, so saved a recording of the text instead.)
		# Audio drivers (or something) need a few seconds before audio will be able to play when run early on boot via LaunchDaemon. So try for up to 60 seconds before continuing.
		
		for (( wait_to_play_seconds = 0; wait_to_play_seconds < 60; wait_to_play_seconds ++ )); do
			osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
			if afplay "${SCRIPT_DIR}/Announcements/fg-error-occurred.aiff" &> /dev/null; then
				break
			else
				sleep 1
			fi
		done


		# WAIT FOR FULL BOOT
		# Since LaunchDaemons start so early on boot, always wait for full boot before continuing so that everything is run in a consistent state and all system services have been started.
		# Through investigation, I found that "coreauthd" is consistently the last, or nearly the last, root process to be started before the login window is displayed.

		while ! pgrep -q 'coreauthd'; do
			sleep 2
		done
		

		# DO NOT ALLOW SLEEP

		caffeinate -dimsu -w "$$" &


		# LAUNCH LOGIN PROGRESS APP

		launch_login_progress_app
		

		# ANNOUNCE CANNOT BE SOLD AND DELIVER TO I.T. *AFTER* LOGIN WINDOW IS DISPLAYED

		osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
		afplay "${SCRIPT_DIR}/Announcements/fg-cannot-be-sold.aiff"
		afplay "${SCRIPT_DIR}/Announcements/fg-deliver-to-it.aiff"
		
	else

		write_to_log() {
			echo -e "$(date '+%D %T')\t$1" >> "${SCRIPT_DIR}/log.txt"
		}

		# ANNOUNCE STARTING RESET (For some reason "say" does not work on macOS 11 Big Sur when run on boot via LaunchDaemon, so saved a recording of the text instead.)
		# Audio drivers (or something) need a few seconds before audio will be able to play when run early on boot via LaunchDaemon. So try for up to 60 seconds before continuing.
		
		write_to_log "Finishing Reset After Restoring Reset Snapshot (version ${SCRIPT_VERSION})"

		for (( wait_to_play_seconds = 0; wait_to_play_seconds < 60; wait_to_play_seconds ++ )); do
			osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
			if afplay "${SCRIPT_DIR}/Announcements/fg-starting-reset.aiff" &> /dev/null; then
				break
			else
				sleep 1
			fi
		done
		

		# WAIT FOR FULL BOOT TO FINISH BEFORE RESETTING AND SHUTTING DOWN
		# Since LaunchDaemons start so early on boot, always wait for full boot before continuing so that everything is run in a consistent state and all system services have been started.
		# Through investigation, I found that "coreauthd" is consistently the last, or nearly the last, root process to be started before the login window is displayed.

		write_to_log 'Waiting for Full Boot'

		while ! pgrep -q 'coreauthd'; do
			sleep 2
		done
		

		# DO NOT ALLOW SLEEP WHILE RESETTING

		write_to_log 'Preventing Sleep During Process'

		caffeinate -dimsu -w "$$" &
		caffeinate_pid=$!


		# ANNOUNCE DO NOT DISTURB *AFTER* LOGIN WINDOW IS DISPLAYED (where it may be tempting to click things)

		osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
		afplay "${SCRIPT_DIR}/Announcements/fg-do-not-disturb.aiff" # DO wait for this to finish since reset can finish so quick that the next announcement can overlap if we continue before this is done being said.


		if [[ "$(sudo systemsetup -getusingnetworktime)" == *': Off' ]]; then # "sudo" is needed for "systemsetup" within subshell.
			
			if [[ -d "${SCRIPT_DIR}/actual-snapshot-time.txt" ]]; then

				# SET TIME TO ACTUAL SNAPSHOT TIME (since it gets set to midnight before creating the reset snapshot)
				
				actual_snapshot_time="$(cat "${SCRIPT_DIR}/actual-snapshot-time.txt")"

				write_to_log "Resetting Time to Actual Snapshot Time (${actual_snapshot_time})"

				systemsetup -settime "${actual_snapshot_time}" &> /dev/null
			fi


			# TURN ON NETWORK TIME (since it gets turned off before creating the reset snapshot)
			# Do this BEFORE launching "Free Geek Login Progress" since going back in time after launch can make "delay" in AppleScript hang forever on macOS 11 Big Sur.

			write_to_log 'Turning On Network Time'

			systemsetup -setusingnetworktime on &> /dev/null
			sleep 5 # Give system 5 seconds to sync to correct time before continuing.
		fi
		

		# LAUNCH LOGIN PROGRESS APP

		write_to_log 'Launching Login Progress App'
		launch_login_progress_app

		if ! pgrep -q 'Free Geek Login Progress'; then
			write_to_log 'Failed to Launch Login Progress App'
		fi


		if [[ "$(diskutil apfs listCryptoUsers /)" != 'No cryptographic users for disk'* ]]; then

			# DELETE ANY CRYPTO USER REFERENCES (SECURE TOKEN HOLDERS) IF THEY EXIST
			# Even though these accounts no longer exist, the crypto user references are not removed when restoring the reset Snapshot since it's stored in the APFS Metadata and not the filesystem itself.
			# This should only happen on macOS 10.15 Catalina (or older) since Secure Tokens can be prevented from being granted to our users on macOS 11 Big Sur.
			# But, there is no harm in always checking in case something unexpected happened.

			# IMPORTANT: This DOES NOT work on SEP-enabled devices, such as T2 Macs and Apple Silicon Macs (not sure about T1 Macs).
			# Running "diskutil apfs updatePreboot /" does not help this situation since it will fail because the Open Directory user doesn't exist.
			# So, we will only allow macOS 11 Big Sur to be installed on those since the Secure Token can be prevented rather than needing to be deleted.

			crypto_user_uuids_before="$(diskutil apfs listCryptoUsers / | awk '($1 == "+--") { print $NF }')"
			# NOTE: Even though all of the crypto users should be properly returned from "diskutil apfs listCryptoUsers /",
			# I wanted to also check and use "fdesetup list users" here to be overly thorough since it's very important,
			# but it seems to always return nothing when running in this LaunchDaemon.

			IFS=$'\n'
			for this_cryto_user_uuid in $crypto_user_uuids_before; do
				if [[ -n "${this_cryto_user_uuid}" ]] && (( ${#this_cryto_user_uuid} == 36 )); then
					# Since any and all Secure Token accounts no longer exists after restoring the reset Snapshot, their crypto user references can now be deleted using "fdesetup remove -uuid". But when the accounts still existed, macOS would not allow the last one to be removed.
					write_to_log "Deleting Leftover Secure Token Reference (${this_cryto_user_uuid})"
					fdesetup remove -uuid "${this_cryto_user_uuid}"
				fi
			done
			unset IFS

			crypto_user_uuids_after="$(diskutil apfs listCryptoUsers / | awk '($1 == "+--") { print $NF }')"
			
			if [[ "${crypto_user_uuids_before}" != "${crypto_user_uuids_after}" ]]; then

				# UPDATE APFS PREBOOT
				# I am not sure if this is necessary, but it seems wise after messing with Secure Tokens.
				# For info about what this command does, run "diskutil apfs updatePreboot" (with no device or path) in Terminal.

				write_to_log 'Updating Preboot After Deleting Leftover Secure Token References'

				diskutil apfs updatePreboot /
			fi
		fi


		if [[ "$(diskutil apfs listCryptoUsers /)" == 'No cryptographic users for disk'* ]]; then

			if [[ "$(tmutil listlocalsnapshots /)" == *'com.apple.TimeMachine'* ]]; then

				# DELETE ALL LOCAL SNAPSHOTS
				# The reset Snapshots will still exist, delete it so the customer does not accidentally try to restore it after creating their account.

				write_to_log 'Deleting Reset Snapshot'

				tmutil deletelocalsnapshots / &> /dev/null
			fi


			if [[ "$(tmutil listlocalsnapshots /)" != *'com.apple.TimeMachine'* ]]; then

				# NOTES ABOUT NOT NEEDING TO CLEAR TOUCH ID FINGERPRINTS

				# Through testing, I found that Touch ID fingerprints are cleared when the users are gone after restoring the reset Snapshot.
				# I am not sure exactly how this works internally, maybe Touch ID entries for non-existant users are allowed to be overwritten, but I tested this on both T1 and T2 Macs.
				# After restoring the reset Snapshot, "bioutil" always says there are no Touch ID fingerprints and while the xART Touch ID entry will still be visible in "xartutil",
				# manually deleting the xART Touch ID entry with "xartutil --erase" will seems to work after the command is run, but the entry will come back on reboot anyway.
				# Most importantly, even if the xART Touch ID entry exists, there are no Touch ID fingerprints stored when a new user is created after going through Setup Assistant.
				# I tested this by filling all 5 Touch ID fingerprint slots before restoring the reset Snapshot and was able to create add new Touch ID fingerprints after restoring
				# the reset Snapshot (without deleting any Touch ID fingerprint entries using "bioutil" or "xartutil") and going through Setup Assistant to create a new user.
				

				# DELETE ALL PREFERENCES, CACHES, AND TEMPORARY FILES

				write_to_log 'Cleaning Up Unnecessary Files'

				find '/Library/Preferences' -name '*.plist' -exec defaults delete {} \;
				rm -rf '/Library/Preferences/'{,.[^.],..?}*
				rm -rf '/Library/Caches/'{,.[^.],..?}
				rm -rf '/System/Library/Caches/'{,.[^.],..?}*
				rm -rf '/private/var/vm/'{,.[^.],..?}*
				rm -rf '/private/var/folders/'{,.[^.],..?}*
				rm -rf '/private/var/tmp/'{,.[^.],..?}*
				rm -rf '/private/tmp/'{,.[^.],..?}*
				rm -rf '/.TemporaryItems/'{,.[^.],..?}*


				if ! nvram 'EnableTRIM' && [[ "$(sw_vers -buildVersion)" > '20E' || "$(sysctl -in hw.optional.arm64)" != '1' ]]; then

					# CLEAR NVRAM
					# Unless TRIM has been enabled with "trimforce enable" since clearing NVRAM will undo it.
					# The TRIM flag is stored in NVRAM in macOS 10.15 Catalina or newer, previous versions of macOS stored in the filesystem which would
					# have been undone by the a Snapshot reset which is one reason we do not do Snapshot resets are only done on macOS 10.15 Catalina or newer.

					# Also, DO NOT clear NVRAM on Apple Silicon IF OLDER THAN macOS 11.3 Big Sur (build 20E232) since it will cause an error on reboot stating that macOS needs to be
					# reinstalled, but can be booted properly after re-selecting the internal drive in Startup Disk (which resets the necessary "boot-volume" key which was deleted in NVRAM).
					# This has been fixed in macOS 11.3 Big Sur by protecting the "boot-volume" key (among others) which can no longer be deleted by "nvram -c" or "nvram -d".
					
					write_to_log 'Clearing NVRAM'

					nvram -c
				fi


				# SET LANGUAGE CHOOSER AND SETUP ASSISTANT TO RUN ON NEXT BOOT

				write_to_log 'Setting Mac to Run "Setup Assistant" on Next Boot'

				rm -f '/private/var/db/.AppleSetupDone'
				touch '/private/var/db/.RunLanguageChooserToo'
				chown 0:0 '/private/var/db/.RunLanguageChooserToo' # Make sure this file is properly owned by root:wheel.


				if [[ ! -f '/private/var/db/.AppleSetupDone' && -f '/private/var/db/.RunLanguageChooserToo' ]]; then
				
					# DELETE fg-snapshot-reset LAUNCH DAEMON

					rm -f "${launch_daemon_path}"


					# DELETE fg-error-occurred LAUNCH DAEMON

					rm -f '/Library/LaunchDaemons/org.freegeek.fg-error-occurred.plist'


					if [[ ! -f "${launch_daemon_path}" && ! -f '/Library/LaunchDaemons/org.freegeek.fg-error-occurred.plist' ]]; then
						
						write_to_log 'Successfully Completed Snapshot Reset'

						sleep 3 # Give the Progress app a few seconds to update it's status after the LaunchDaemon file has been deleted.

					
						# ANNOUNCE COMPLETED RESET

						osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
						afplay "${SCRIPT_DIR}/Announcements/fg-completed-reset.aiff"
						afplay "${SCRIPT_DIR}/Announcements/fg-shutting-down.aiff"


						# DELETE fg-snapshot-reset FOLDER

						rm -rf "${SCRIPT_DIR}"


						# DELETE ANYTHING ELSE IN SHARED FOLDER
						# "Build Info" folder could exist with partial log from fg-prepare-os.
						# No other files or folder should normally exist at this point, but may exist when I'm debugging.

						rm -rf '/Users/Shared/'{,.[^.],..?}*


						if [[ ! -d "${SCRIPT_DIR}" ]]; then
						
							# KILL CAFFEINATE

							kill "${caffeinate_pid}" &> /dev/null


							# SHUT DOWN

							shutdown -h now &> /dev/null

							exit 0
						fi
					fi
				fi
			fi
		fi
		
			
		# ANNOUNCE ERROR (For some reason "say" does not work on macOS 11 Big Sur when run on boot via LaunchDaemon, so saved a recording of the text instead.)

		write_to_log 'ERROR: Failed to Perform Previous Task'

		osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
		afplay "${SCRIPT_DIR}/Announcements/fg-error-occurred.aiff"
		afplay "${SCRIPT_DIR}/Announcements/fg-cannot-be-sold.aiff"
		afplay "${SCRIPT_DIR}/Announcements/fg-deliver-to-it.aiff"
	fi
else
	
	# ANNOUNCE ERROR (For some reason "say" does not work on macOS 11 Big Sur when run on boot via LaunchDaemon, so saved a recording of the text instead.)
	# Audio drivers (or something) need a few seconds before audio will be able to play when run early on boot via LaunchDaemon. So try for up to 60 seconds before continuing.
	
	for (( wait_to_play_seconds = 0; wait_to_play_seconds < 60; wait_to_play_seconds ++ )); do
		osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
		if afplay "${SCRIPT_DIR}/Announcements/fg-error-occurred.aiff" &> /dev/null; then
			afplay "${SCRIPT_DIR}/Announcements/fg-cannot-be-sold.aiff"
			afplay "${SCRIPT_DIR}/Announcements/fg-deliver-to-it.aiff"
			break
		else
			sleep 1
		fi
	done
fi
