#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

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

readonly SCRIPT_VERSION='2025.10.13-1'

PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec' # Add "/usr/libexec" to PATH for easy access to PlistBuddy.

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)"
readonly SCRIPT_DIR

launch_daemon_path='/Library/LaunchDaemons/org.freegeek.fg-snapshot-reset.plist'

launch_login_progress_app() {
	if [[ -f "${SCRIPT_DIR}/Tools/Free-Geek-Login-Progress.zip" && ! -d "${SCRIPT_DIR}/Tools/Free Geek Login Progress.app" ]]; then
		ditto -xk --noqtn "${SCRIPT_DIR}/Tools/Free-Geek-Login-Progress.zip" "${SCRIPT_DIR}/Tools" &> /dev/null
		touch "${SCRIPT_DIR}/Tools/Free Geek Login Progress.app"
	fi

	if [[ -d "${SCRIPT_DIR}/Tools/Free Geek Login Progress.app" ]]; then
		# Cannot open "Free Geek Login Progress" directly when at Login Window, but a LaunchAgent with LimitLoadToSessionType=LoginWindow and "launchctl load -S LoginWindow" can open it.
		# In my testing I haven't been able to figure out how to do this with any of the modern "launchctl bootstrap" options, but maybe there is some way that I haven't found.

		login_progress_launch_agent_path='/Library/LaunchAgents/org.freegeek.Free-Geek-Login-Progress.plist'

		# NOTE: The following LaunchAgent is setup to run a signed script which launches the app and has "AssociatedBundleIdentifiers" specified to be properly displayed in the "Login Items" list in "System Settings" on macOS 13 Ventura and newer.
		# BUT, this is just done for consistency with other code since this particular script will never run when a user is logged in to even be able to see that list in macOS 13 Ventura.
		# On macOS 12 Monterey and older, the "AssociatedBundleIdentifiers" will just be ignored and the signed launcher script will behave just as if we ran "/usr/bin/open" directly via the LaunchAgent.
		PlistBuddy \
			-c 'Add :Label string org.freegeek.Free-Geek-Login-Progress' \
			-c 'Add :LimitLoadToSessionType string LoginWindow' \
			-c "Add :Program string '${SCRIPT_DIR}/Tools/Free Geek Login Progress.app/Contents/Resources/Launch Free Geek Login Progress'" \
			-c 'Add :AssociatedBundleIdentifiers string org.freegeek.Free-Geek-Login-Progress' \
			-c 'Add :RunAtLoad bool true' \
			-c 'Add :StandardOutPath string /dev/null' \
			-c 'Add :StandardErrorPath string /dev/null' \
			"${login_progress_launch_agent_path}" &> /dev/null

		launchctl load -S LoginWindow "${login_progress_launch_agent_path}"

		for (( wait_for_progress_app_seconds = 0; wait_for_progress_app_seconds < 15; wait_for_progress_app_seconds ++ )); do
			if pgrep -qax 'Free Geek Login Progress'; then
				break
			else
				sleep 1
			fi
		done

		launchctl unload -S LoginWindow "${login_progress_launch_agent_path}"
		rm -f "${login_progress_launch_agent_path}"
	fi
}

if [[ "${SCRIPT_DIR}" == '/Users/Shared/fg-snapshot-reset' && -f "${launch_daemon_path}" && -f '/private/var/db/.AppleSetupDone' && "${EUID:-$(id -u)}" == '0' &&
	  -z "$(dscl . -list /Users ShadowHashData 2> /dev/null | awk '($1 != "_mbsetupuser") { print $1 }')" && "$(fdesetup isactive)" == 'false' &&
	  -f '/Users/Shared/Build Info/Prepare OS Log.txt' && "$(tail -1 '/Users/Shared/Build Info/Prepare OS Log.txt')" == *'Creating Reset Snapshot' ]]; then # "_mbsetupuser" may have a password if customized a clean install that presented Setup Assistant.

	if [[ -f "${SCRIPT_DIR}/log.txt" ]] && grep -qF $'\tERROR:' "${SCRIPT_DIR}/log.txt"; then
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

		until pgrep -qax 'coreauthd'; do
			sleep 2
		done


		# DO NOT ALLOW SLEEP

		caffeinate -dimsuw "$$" &


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

		until pgrep -qax 'coreauthd'; do
			sleep 2
		done


		# DO NOT ALLOW SLEEP WHILE RESETTING

		write_to_log 'Preventing Sleep During Process'

		caffeinate -dimsuw "$$" &
		caffeinate_pid="$!"


		# ANNOUNCE DO NOT DISTURB *AFTER* LOGIN WINDOW IS DISPLAYED (where it may be tempting to click things)

		osascript -e 'set volume output volume 50 without output muted' -e 'set volume alert volume 100' &> /dev/null
		afplay "${SCRIPT_DIR}/Announcements/fg-do-not-disturb.aiff" # DO wait for this to finish since reset can finish so quick that the next announcement can overlap if we continue before this is done being said.


		if [[ "$(sudo systemsetup -getusingnetworktime)" == *': Off' ]]; then # "sudo" is needed for "systemsetup" within subshell.

			if [[ -d "${SCRIPT_DIR}/actual-snapshot-time.txt" ]]; then

				# SET TIME TO ACTUAL SNAPSHOT TIME (since it gets set to midnight before creating the reset snapshot)

				actual_snapshot_time="$(< "${SCRIPT_DIR}/actual-snapshot-time.txt")"

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

		if ! pgrep -qax 'Free Geek Login Progress'; then
			write_to_log 'Failed to Launch Login Progress App'
		fi


		did_delete_leftover_secure_token_references=false

		if [[ "$(diskutil apfs listCryptoUsers /)" != 'No cryptographic users for disk'* ]]; then

			# DELETE ANY CRYPTO USER REFERENCES (SECURE TOKEN HOLDERS) IF THEY EXIST
			# Even though these accounts no longer exist, the crypto user references are not removed when restoring the reset Snapshot since it's stored in the APFS Metadata and not the filesystem itself.
			# This should only happen on macOS 10.15 Catalina (or older but older versions don't do a Snapshot reset) since Secure Tokens can be prevented from being granted to our users on macOS 11 Big Sur.
			# But, there is no harm in always checking in case something unexpected happened.

			# IMPORTANT: This DOES NOT work on SEP-enabled (Secure Enclave Processor) devices, such as T2 Macs and Apple Silicon Macs,
			# but WORKS on T1 Macs whose Secure Enclave is only used for Touch ID (and nothing else like Secure Tokens or disk encryption keys).
			# Running "diskutil apfs updatePreboot /" does not help this situation since it will fail because the Open Directory user doesn't exist.
			# So, we will only allow macOS 11 Big Sur to be installed on those since the Secure Token can be prevented rather than needing to be deleted.

			while read -ra this_cryto_users_line_elements; do
				if [[ "${this_cryto_users_line_elements[0]}" == '+--' ]]; then
					# Since any and all Secure Token accounts no longer exists after restoring the reset Snapshot, their crypto user references can now be deleted using "fdesetup remove -uuid". But when the accounts still existed, macOS would not allow the last one to be removed.
					write_to_log "Deleting Leftover Secure Token Reference (${this_cryto_users_line_elements[1]})"
					fdesetup remove -uuid "${this_cryto_users_line_elements[1]}"
					did_delete_leftover_secure_token_references=true
				fi
			done < <(diskutil apfs listCryptoUsers /)
			# NOTE: Even though all of the crypto users should be properly returned from "diskutil apfs listCryptoUsers /",
			# I wanted to also check and use "fdesetup list users" here to be overly thorough since it's very important,
			# but it seems to always return nothing when running in this LaunchDaemon.
		fi


		if [[ "$(diskutil apfs listCryptoUsers /)" == 'No cryptographic users for disk'* ]]; then

			update_preboot_failed=false

			if $did_delete_leftover_secure_token_references; then

				# UPDATE APFS PREBOOT
				# I am not sure if this is necessary, but it seems wise after messing with Secure Tokens.
				# For info about what this command does, run "diskutil apfs updatePreboot" (with no device or path) in Terminal.

				write_to_log 'Updating Preboot Volume After Deleting Leftover Secure Token References'

				is_last_update_preboot_attempt=false
				for (( update_preboot_attempt = 1; update_preboot_attempt <= 3; update_preboot_attempt ++ )); do # Updating the Preboot Volume *should* work on the first attempt, but try up to 3 times just in case there is a fluke issue.
					if ! diskutil_apfs_update_preboot_output="$(diskutil apfs updatePreboot / 2>&1)" || [[ "${diskutil_apfs_update_preboot_output}" != *$'UpdatePreboot: Exiting Update Preboot operation with overall error=(ZeroMeansSuccess)=0\nFinished APFS operation' ]]; then
						write_to_log "$(echo "${diskutil_apfs_update_preboot_output}" | tail -2)" # If there was an error, log the last 2 updatePreboot output lines since it may be informative.
						if (( update_preboot_attempt == 3 )); then is_last_update_preboot_attempt=true; fi
						write_to_log "$($is_last_update_preboot_attempt && echo 'ERROR' || echo 'WARNING'): Attempt ${update_preboot_attempt} of 3 Failed to Update Preboot Volume After Deleting Leftover Secure Token References"
						if $is_last_update_preboot_attempt; then
							update_preboot_failed=true
						else
							sleep "${update_preboot_attempt}" # If there was an error, wait a bit before trying again.
						fi
					else
						break
					fi
				done
			fi

			if ! $update_preboot_failed; then

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


					# RESET TCC DATABASE
					# Since global TCC permissions are set within "fg-install-os" (see the "create_custom_global_tcc_database" function in that script for more info),
					# there will be TCC permissions that exist before the reset Snapshot is created, so we must remove those permissions manually during this reset process.

					write_to_log 'Resetting TCC Database'

					tccutil reset All


					# DELETE ALL PREFERENCES, CACHES, AND TEMPORARY FILES

					write_to_log 'Cleaning Up Unnecessary Files'

					while IFS='' read -rd '' this_preferences_file; do
						defaults delete "${this_preferences_file}" # Properly delete all preferences values through "cfprefsd" before deleting the actual file.
						rm -f "${this_preferences_file}"
						rmdir "${this_preferences_file%/*}" # Delete parent folder if it's empty.
					done < <(find '/Library/Preferences' -type f -name '*.plist' -not -path '*/OpenDirectory/Configurations/Search.plist' -print0)
					# NOTE: The "/Library/Preferences/OpenDirectory/Configurations/Search.plist" preferences file IS NOT being deleted because starting on macOS 13 Ventura
					# deleting it causes a Kernel Panic boot loop on the next reboot. I'm not sure what changed since it was never an issue to delete all these preferences before,
					# but since the default OpenDirectory search path is never changed it doesn't hurt to just keep that file as-is on all versions of macOS.
					# Through testing, I found that all other OpenDirectory preferences stored within "/Library/Preferences/OpenDirectory" can be deleted and properly
					# revert to their default values. When this Kernel Panic boot loop happened after this reset script ran and shut the computer, I narrowed the issue down by
					# enabling Verbose Mode by running "nvram boot-args='-v'" when in Recovery and then saw errors during the hanging period before the Kernel Panic that stated
					# "AMFI: Denying core dump for pid ### (opendirectoryd)" over and over again with new PIDs. This seemed to indicate some issue with "opendirectoryd" loading.
					# Then, I commented out sections of these file deletions since it seemed like the most likely culprit until I manually narrowed the issue down to exactly the
					# "/Library/Preferences/OpenDirectory/Configurations/Search.plist" preferences file needing to be preserved to avoid the Kernel Panic boot loop.

					rm -rf '/Library/Caches/'{,.[^.],..?}* \
						'/System/Library/Caches/'{,.[^.],..?}* \
						'/private/var/vm/'{,.[^.],..?}* \
						'/private/var/folders/'{,.[^.],..?}* \
						'/private/var/tmp/'{,.[^.],..?}* \
						'/private/tmp/'{,.[^.],..?}* \
						'/.TemporaryItems/'{,.[^.],..?}*


					is_apple_silicon="$([[ "$(sysctl -in hw.optional.arm64)" == '1' ]] && echo 'true' || echo 'false')"

					if ! nvram 'EnableTRIM' && { ! $is_apple_silicon || [[ "$(sw_vers -buildVersion)" > '20E' ]]; }; then

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


					# VERIFY STARTUP SECURITY FOR T2 AND APPLE SILICON MACS
					# T2 and Apple Silicon Macs should never have been able to have Startup Security reduced since doing so requires authenticating with a Secure Token administrator,
					# which will never exist in our testing process when doing a Snapshot Reset and also cannot have ever existed if we got this far in the reset process since it
					# would have errored above when the Secure Token user reference would have not been able to be removed, but still check and error just in case anyways.

					startup_security_is_full=true

					if [[ -n "$(ioreg -rn 'Apple T2 Controller' -d 1)" ]]; then
						write_to_log 'Verifying T2 Startup Security'

						if [[ "$(nvram '94B73556-2197-4702-82A8-3E1337DAFBFB:AppleSecureBootPolicy' 2> /dev/null)" != *$'\t%02' ]]; then # https://github.com/dortania/OpenCore-Legacy-Patcher/blob/b85256d9708a299b9f7ea15cb3456248a1a666b7/resources/utilities.py#L242 & https://macadmins.slack.com/archives/CGXNNJXJ9/p1686766296067939?thread_ts=1686766055.849109&cid=CGXNNJXJ9
							startup_security_is_full=false
						fi
					elif $is_apple_silicon; then
						write_to_log 'Verifying Apple Silicon Startup Security'

						if ! bputil -d | grep -qF '(smb0): absent'; then
							startup_security_is_full=false
						fi
					fi


					if $startup_security_is_full; then

						# VERIFY SYSTEM INTEGRITY PROTECTION (SIP)
						# SIP should never have been disabled since it is reset during installation and throughout the testing process, but check and reset it to be extra thorough anyways.
						# On Apple Silicon Macs, SIP cannot be disabled or re-enabled without authenticating with a Secure Token admin, but it should never be disabled since that also
						# requires reducing Startup Security which also requires a Secure Token admin which will never have existed during testing when doing a Snapshot Reset,
						# but still check and error just in case anyways.

						write_to_log 'Verifying System Integrity Protection (SIP)'

						sip_is_enabled="$([[ "$(csrutil status)" == 'System Integrity Protection status: enabled.' ]] && echo 'true' || echo 'false')"

						if ! $sip_is_enabled && ! $is_apple_silicon; then

							# ENABLE SYSTEM INTEGRITY PROTECTION (SIP)
							# "csrutil clear" can run from full macOS (Recovery is not required) but still needs a reboot to take effect (so it will be cleared on next boot to Setup Assistant).
							# BUT, if running on Apple Silicon, "csrutil clear" requires authentication from a Secure Token admin (which won't have ever existed) to enable or disable it,
							# so it should be impossible to be enabled during our process, but if somehow it is enabled then this reset process will fail with an error during this step.

							write_to_log 'Enabling System Integrity Protection (SIP)'

							if csrutil_clear_output="$(csrutil clear 2>&1)" && [[ "${csrutil_clear_output}" == 'Successfully cleared'* ]]; then
								sip_is_enabled=true # Even if "csrutil clear" is successful, checking "csrutil status" again will still show it's DISABLED since we haven't rebooted yet, so we just need to update the known SIP status manually instead of checking again.
							fi
						fi

						if $sip_is_enabled; then

							# SET LANGUAGE CHOOSER AND SETUP ASSISTANT TO RUN ON NEXT BOOT

							write_to_log 'Setting Mac to Run "Setup Assistant" on Next Boot'

							rm -f '/private/var/db/.AppleSetupDone'
							touch '/private/var/db/.RunLanguageChooserToo'
							chown 0:0 '/private/var/db/.RunLanguageChooserToo' # Make sure this file is properly owned by root:wheel.


							if [[ ! -f '/private/var/db/.AppleSetupDone' && -f '/private/var/db/.RunLanguageChooserToo' ]]; then

								# DELETE fg-snapshot-reset LAUNCH DAEMON

								rm -f "${launch_daemon_path}" # Do NOT bootout/unload the LaunchDaemon or this script will be terminated immediately. It won't be loaded anyway because it will no longer exist on next boot.


								# BOOTOUT & DELETE fg-error-occurred LAUNCH DAEMON

								launchctl bootout 'system/org.freegeek.fg-error-occurred'
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
									# "Build Info" folder will always exist with the installation log and partial prepare log up to the point of
									# the reset Snapshot being created, but do not save it since it won't contain any useful info for the customer.
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
