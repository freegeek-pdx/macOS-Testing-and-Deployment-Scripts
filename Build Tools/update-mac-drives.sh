#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

#
# MIT License
#
# Copyright (c) 2022 Free Geek
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

PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec' # Add "/usr/libexec" to PATH for easy access to PlistBuddy.

PROJECT_DIR="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)/.."
readonly PROJECT_DIR

TMPDIR="$([[ -d "${TMPDIR}" && -w "${TMPDIR}" ]] && echo "${TMPDIR%/}" || echo '/tmp')" # Make sure "TMPDIR" is always set and that it DOES NOT have a trailing slash for consistency regardless of the current environment.

if (( ${EUID:-$(id -u)} != 0 )); then
	>&2 echo 'ERROR: This script must be run as root (to be able to run the "createinstallmedia" and "asr" commands).'
	afplay /System/Library/Sounds/Basso.aiff
	exit 1
fi

echo -e "\nUSB Device Tree:\n$(system_profiler "$(system_profiler -listDataTypes | grep -m 1 '^SPUSB')")" # On macOS 14 Sequoia and older the data type name is "SPUSBDataType" and then on macOS 26 Tahoe and newer it was changed to "SPUSBHostDataType". 

external_disk_list="$(diskutil list external physical)"
external_disk_count="$(echo "${external_disk_list}" | grep -c '^/dev/disk')"

if [[ -z "${external_disk_count}" || "${external_disk_count}" == '0' ]]; then
	>&2 echo 'ERROR: No Mac drives detected.'
	afplay /System/Library/Sounds/Basso.aiff
	exit 1
fi

echo -e "\n${external_disk_count} Connected External Drives:\n$(diskutil list external physical)"

echo -en "\nDo any of the ${external_disk_count} Mac drives need to be formatted before being updated? [y/N] "
read -r confirm_format_drives
if [[ "${confirm_format_drives}" =~ ^[Yy] ]]; then
	echo -en '\nEnter space-separated Disk IDs (or "ALL") to Format and Partition for fgMIB + macOS Installers + Mac Test Boot: '
	read -r disk_ids

	# Suppress ShellCheck warning to use double quotes to prevent word splitting, because intentionally WANT word splitting on spaces.
	# shellcheck disable=SC2086
	disk_ids="$(printf '%s\n' $disk_ids | tr '[:upper:]' '[:lower:]' | sort -un)"

	if [[ " ${disk_ids} " == *' all '* ]]; then
		disk_ids="$(echo "${external_disk_list}" | awk -F '/| ' '/^\/dev\/disk/ { print $3 }')"
		echo -e "ALL listed Mac drives specified:\n${disk_ids}"
	fi

	for this_disk_id in $disk_ids; do
		if [[ "${this_disk_id}" != 'disk'* ]]; then
			this_disk_id="disk${this_disk_id}"
		fi

		this_disk_info_plist_path="$(mktemp -t 'update_mac_drives-this_disk_info')"
		diskutil info -plist "${this_disk_id}" > "${this_disk_info_plist_path}"

		if [[ "$(PlistBuddy -c 'Print :Error' "${this_disk_info_plist_path}" 2> /dev/null)" == 'true' ]]; then
			echo -e "\nNOTICE: Skipping \"${this_disk_id}\" with error \"$(PlistBuddy -c 'Print :ErrorMessage' "${this_disk_info_plist_path}" 2> /dev/null)\"."
		elif [[ "$(PlistBuddy -c 'Print :Internal' "${this_disk_info_plist_path}" 2> /dev/null)" == 'true' ]]; then
			echo -e "\nNOTICE: Skipping internal drive \"${this_disk_id}\"."
		elif [[ "$(PlistBuddy -c 'Print :ParentWholeDisk' "${this_disk_info_plist_path}" 2> /dev/null)" != "${this_disk_id}" ||
			"$(PlistBuddy -c 'Print :WholeDisk' "${this_disk_info_plist_path}" 2> /dev/null)" == 'false' ||
			"$(PlistBuddy -c 'Print :VirtualOrPhysical' "${this_disk_info_plist_path}" 2> /dev/null)" == 'Virtual' ]]; then
			echo -e "\nNOTICE: Skipping sub-device \"${this_disk_id}\"."
		elif [[ "$(PlistBuddy -c 'Print :BusProtocol' "${this_disk_info_plist_path}" 2> /dev/null)" != 'USB' ]]; then
			echo -e "\nNOTICE: Skipping non-USB drive \"${this_disk_id}\"."
		else
			echo -e "\nFormatting \"${this_disk_id}\"..."

			# NOTE: For some reason (at least as of macOS 26.0.1 Tahoe) each desired size need 0.13 GB added to it to result in the correct desired size.
			# The sizes (plus 0.13 GB) being used for each installer are specified in the "Create macOS USB Installer Commands.txt" file based on testing to find the minimum required size for each macOS version installer.

			diskutil_partition_disk_array=(
				JHFS+ 'fgMIB'						1.33G		# 1.2 GB
			#	JHFS+ 'Install macOS High Sierra'	5.435G		# 5.305 GB
			#	JHFS+ 'Install macOS Mojave'		6.245G		# 6.115 GB
				JHFS+ 'Install macOS Catalina'		8.46G		# 8.33 GB
				JHFS+ 'Install macOS Big Sur'		13.665G		# 13.535 GB
				JHFS+ 'Install macOS Monterey'		14.735G		# 14.605 GB
				JHFS+ 'Install macOS Ventura'		14.53G		# 14.4 GB
				JHFS+ 'Install macOS Sonoma'		15.985G		# 15.855 GB
				JHFS+ 'Install macOS Sequoia'		17.995G		# 17.865 GB
				JHFS+ 'Install macOS Tahoe'			19.285G		# 19.155 GB
				JHFS+ 'Mac Test Boot'				0B			# All Remaining Space
			)

			if ! diskutil partitionDisk "${this_disk_id}" "$(( ${#diskutil_partition_disk_array[@]} / 3 ))" GPT "${diskutil_partition_disk_array[@]}"; then
				echo "ERROR: Formatting ${this_disk_id} failed (see error above)."
				exit 2
			fi
		fi
	done
fi


if [[ "$(sysctl -in hw.optional.arm64)" == '1' ]]; then
	rm -rf "${TMPDIR}/Install macOS "*
fi

human_readable_duration_from_seconds() { # Based On: https://stackoverflow.com/a/39452629
	total_seconds="$1"
	if [[ ! "${total_seconds}" =~ ^[0123456789]+$ ]]; then
		echo 'INVALID Seconds'
		return 1
	fi

	duration_output=''

	display_days="$(( total_seconds / 86400 ))"
	if (( display_days > 0 )); then
		duration_output="${display_days} Day$( (( display_days != 1 )) && echo 's' )"
	fi

	display_hours="$(( (total_seconds % 86400) / 3600 ))"
	if (( display_hours > 0 )); then
		if [[ -n "${duration_output}" ]]; then
			duration_output+=', '
		fi
		duration_output+="${display_hours} Hour$( (( display_hours != 1 )) && echo 's' )"
	fi

	display_minutes="$(( (total_seconds % 3600) / 60 ))"
	if (( display_minutes > 0 )); then
		if [[ -n "${duration_output}" ]]; then
			duration_output+=', '
		fi
		duration_output+="${display_minutes} Minute$( (( display_minutes != 1 )) && echo 's' )"
	fi

	display_seconds="$(( total_seconds % 60 ))"
	if (( display_seconds > 0 )) || [[ -z "${duration_output}" ]]; then
		if [[ -n "${duration_output}" ]]; then
			duration_output+=', '
		fi
		duration_output+="${display_seconds} Second$( (( display_seconds != 1 )) && echo 's' )"
	fi

	echo "${duration_output}"
}


overall_start_timestamp="$(date '+%s')"

declare -a installer_names_to_update=(
#	'High Sierra' 'Mojave'
	'Catalina' 'Big Sur' 'Monterey' 'Ventura' 'Sonoma' 'Sequoia' 'Tahoe'
)

for this_installer_name_to_update in "${installer_names_to_update[@]}"; do
	this_installer_start_timestamp="$(date '+%s')"
	this_connected_installer_volume_count=0

	# Suppress ShellCheck suggestion to use "find" instead of "ls" since we need "ls -t" to sort by modification date to easily get a single result of the newest installer, and this path will never contain non-alphanumeric characters.
	# shellcheck disable=SC2012
	installer_dmg_path="$(ls -t "${PROJECT_DIR}/../../MacLand Images/macOS Installers/Install macOS ${this_installer_name_to_update}"*'.dmg' | head -1)"
	echo -e "\nMounting Installer DMG \"${installer_dmg_path##*/}\"..."
	installer_source_volume="$(hdiutil attach "${installer_dmg_path}" -nobrowse -readonly -plist 2> /dev/null | xmllint --xpath 'string(//string[starts-with(text(), "/Volumes/")])' - 2> /dev/null)"
	if [[ -d "${installer_source_volume}" ]]; then
		installer_source_version="$(PlistBuddy -c 'Print :CFBundleVersion' "${installer_source_volume}/Install macOS ${this_installer_name_to_update}.app/Contents/version.plist")"

		echo "Mounted Installer DMG at \"${installer_source_volume}\" & Updating Connected Installers..."
		if [[ "$(sysctl -in hw.optional.arm64)" == '1' && -e "${TMPDIR}/Install macOS ${this_installer_name_to_update}.app" ]]; then
			rm -rf "${TMPDIR}/Install macOS ${this_installer_name_to_update}.app"
		fi

		background_pids=()
		failed_count=0
		is_first_installer_volume=true
		for this_os_installer_volume in "/Volumes/Install macOS ${this_installer_name_to_update}"*; do
			if [[ -d "${this_os_installer_volume}" && "${this_os_installer_volume}" != "${installer_source_volume}" ]]; then
				(( this_connected_installer_volume_count ++ ))
				this_os_installer_version="$(PlistBuddy -c 'Print :CFBundleVersion' "${this_os_installer_volume}/Install macOS ${this_installer_name_to_update}.app/Contents/version.plist")"
				if [[ "${this_os_installer_version}" != "${installer_source_version}" ]]; then
					echo "Updating Connected Installer at \"${this_os_installer_volume}\"..."

					createinstallmedia_path="${installer_source_volume}/Install macOS ${this_installer_name_to_update}.app/Contents/Resources/createinstallmedia"

					if [[ "$(sysctl -in hw.optional.arm64)" == '1' && "$(lipo -archs "${createinstallmedia_path}")" != *'arm64'* ]]; then
						# See "UPDATE 3" on https://github.com/ninxsoft/Mist/issues/85#issuecomment-2021342539
						if [[ ! -e "${TMPDIR}/Install macOS ${this_installer_name_to_update}.app" ]]; then
							echo "Copying \"Install macOS ${this_installer_name_to_update}.app\" to temporary location to be able to remove expired code signatures so \"createinstallmedia\" can run via Rosetta on Apple Silicon..."
							ditto "${installer_source_volume}/Install macOS ${this_installer_name_to_update}.app" "${TMPDIR}/Install macOS ${this_installer_name_to_update}.app"

							echo "Removing expired code signatures so \"createinstallmedia\" can run via Rosetta on Apple Silicon..."
							while IFS='' read -rd '' this_installer_app_path; do
								if codesign -d "${this_installer_app_path}" &> /dev/null; then # Remove expired signatures for ANYTHING that is currently signed (which could be executables or bundles/folders such as frameworks, etc).
									echo "Removing expired code signature: ${this_installer_app_path}"
									codesign --remove-signature "${this_installer_app_path}"
									# NOTE: Others found the replacing with an ad-hoc signature works (https://forums.macrumors.com/threads/you-cant-use-an-m1-mac-to-create-bootable-pre-bigsur-macos-installers.2283560/page-2?post=31104893#post-31104893),
									# but through testing I found that simply removing all the apps expired signatures is enough to get "createinstallmedia" to run on Apple Silicon and removing the signatures is FASTER than re-signing.
								fi
							done < <(find "${TMPDIR}/Install macOS ${this_installer_name_to_update}.app" -print0)
						fi

						createinstallmedia_path="${TMPDIR}/Install macOS ${this_installer_name_to_update}.app/Contents/Resources/createinstallmedia"

						{
							this_installer_for_volume_start_timestamp="$(date '+%s')"

							"${createinstallmedia_path}" --volume "${this_os_installer_volume}" --nointeraction
							createinstallmedia_exit_code="$?"

							if (( createinstallmedia_exit_code == 0 )); then
								echo "Merging ORIGINAL \"Install macOS ${this_installer_name_to_update}.app\" with expired Apple code signatures into bootable USB \"${this_os_installer_volume}\" so that \"startosinstall\" works when booted into the USB..."
								# IMPORTANT: While removing (or replacing) the expired Apple code signature is required to be able to run "createinstallmedia" on Apple Silicon to make a bootable USB,
								# once you are booted into the USB installer, "startosinstall" or the GUI installer will HANG or FAIL when run without Apple's original code signatures (even though they are expired).
								# So, MERGE the installer app within the bootable USB installer with the ORIGINAL installer app with Apple's expired code signatures which allows the installation to work properly.
								# Using "rsync" to MERGE the contents ONLY copies over the signed executables and "_CodeSignature" folder contents without having to re-copy the large DMGs that were not modified,
								# which is faster than deleting the modified app in the installer USB and copying over the entire original installer app.
								
								set -o pipefail # Enable pipefail to catch any "rsync" error exit code since piping to "grep".
								rsync -avi "${installer_source_volume}/Install macOS ${this_installer_name_to_update}.app/" "${this_os_installer_volume}/Install macOS ${this_installer_name_to_update}.app" | grep -v '^\.' # Use "grep" to ignore any lines where files were not updated.
								rsync_exit_code="$?"
								set +o pipefail # Disable pipefail after retrieving the exit code of "rsync" command pipeline to reset normal exit code behavior.

								if (( rsync_exit_code == 0 )); then
									echo "Successfully completed merging ORIGINAL for \"${this_installer_name_to_update}\" installer on \"${this_os_installer_volume}\"."
								else
									echo "ERROR: \"rsync\" for \"${this_installer_name_to_update}\" on \"${this_os_installer_volume}\" failed with exit code ${rsync_exit_code}."
								fi

								echo "Finished Updating \"${this_installer_name_to_update}\" on \"${this_os_installer_volume}\" in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_installer_for_volume_start_timestamp ))")"

								exit "${rsync_exit_code}"
							fi
							
							echo "ERROR: \"createinstallmedia\" for \"${this_installer_name_to_update}\" on \"${this_os_installer_volume}\" failed with exit code ${createinstallmedia_exit_code}."
							exit "${createinstallmedia_exit_code}"
						} &
					else
						{
							this_installer_for_volume_start_timestamp="$(date '+%s')"

							"${createinstallmedia_path}" --volume "${this_os_installer_volume}" --nointeraction
							createinstallmedia_exit_code="$?"

							if (( createinstallmedia_exit_code != 0 )); then
								echo "ERROR: \"createinstallmedia\" for \"${this_installer_name_to_update}\" on \"${this_os_installer_volume}\" failed with exit code ${createinstallmedia_exit_code}."
							fi

							echo "Finished Updating \"${this_installer_name_to_update}\" on \"${this_os_installer_volume}\" in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_installer_for_volume_start_timestamp ))")"

							exit "${createinstallmedia_exit_code}"
						} &
					fi

					this_background_pid="$!"

					if $is_first_installer_volume; then # Always wait for the first volume to finish in case the installer app needs to be verified which seems like it can cause errors when multiple are started simultaneously when the installer app hasn't been verified yet.
						echo "Waiting for first \"createinstallmedia\" process for \"${this_installer_name_to_update}\" (on \"${this_os_installer_volume}\") to finish before starting the rest simultaneously (in case installer app verification is required)..."

						if ! wait "${this_background_pid}"; then
							((failed_count ++ ))
							break
						fi

						is_first_installer_volume=false
					else
						background_pids+=( "${this_background_pid}" )
						sleep 10 # Sleep a bit before starting the next "createinstallmedia" process since I've seen them fail consistently with "Couldn't find InstallInfo.plist" and "The bless of the installer disk failed." when two Montery "createinstallmedia" processes were started at the same time.
					fi
				else
					echo "Connected Installer at \"${this_os_installer_volume}\" Already Up-to-Date"
				fi
			fi
		done

		for this_background_pid in "${background_pids[@]}"; do # Wait for child "createinstallmedia" processes (and check each exit code) for this OS version to finish before moving to the next to not tax each drive too much by writing to multiple partitions at the same time which tends to cause more failures.
			if ! wait "${this_background_pid}"; then
				((failed_count ++ ))
			fi
		done

		echo -e "\nFinished Updating \"${this_installer_name_to_update}\" on ${this_connected_installer_volume_count} Mac Drives in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_installer_start_timestamp ))")"

		some_update_failed=false
		if (( failed_count > 0 )); then
			>&2 echo "ERROR: ${failed_count} \"createinstallmedia\" (or \"rsync\") processes exited with non-zero exit codes (see detailed errors above)."
			some_update_failed=true
		fi

		if (( this_connected_installer_volume_count == 0 )); then
			echo "No Connected ${this_installer_name_to_update} Installers Found"
		else
			if [[ "$(sysctl -in hw.optional.arm64)" == '1' && -e "${TMPDIR}/Install macOS ${this_installer_name_to_update}.app" ]]; then
				rm -rf "${TMPDIR}/Install macOS ${this_installer_name_to_update}.app"
			fi

			for this_os_installer_volume in "/Volumes/Install macOS ${this_installer_name_to_update}"*; do
				if [[ -d "${this_os_installer_volume}" && "${this_os_installer_volume}" != "${installer_source_volume}" ]]; then
					this_os_installer_version="$(PlistBuddy -c 'Print :CFBundleVersion' "${this_os_installer_volume}/Install macOS ${this_installer_name_to_update}.app/Contents/version.plist")"
					if [[ "${this_os_installer_version}" != "${installer_source_version}" ]]; then
						>&2 echo "ERROR: Failed to update connected installer at \"${this_os_installer_volume}\"."
						some_update_failed=true
					elif ! $some_update_failed; then
						echo "Unmounting Connected Installer at \"${this_os_installer_volume}\"..."
						diskutil unmount "${this_os_installer_volume}" &> /dev/null || diskutil unmount force "${this_os_installer_volume}" &> /dev/null || >&2 echo "ERROR: Failed to unmount connected installer at \"${this_os_installer_volume}\"."
					fi
				fi
			done
		fi

		echo "Unmounting Installer DMG at \"${installer_source_volume}\"..."
		hdiutil detach "${installer_source_volume}" &> /dev/null || hdiutil detach "${installer_source_volume}" -force &> /dev/null || >&2 echo "ERROR: Failed to unmount DMG at \"${installer_source_volume}\"."

		if $some_update_failed; then
			afplay /System/Library/Sounds/Basso.aiff
			exit 2
		fi
	else
		>&2 echo "ERROR: \"${this_installer_name_to_update}\" Installer DMG was not found or mounted."
		afplay /System/Library/Sounds/Basso.aiff
		exit 3
	fi
done


connected_mtb_count=0
# Suppress ShellCheck suggestion to use "find" instead of "ls" since we need "ls -t" to sort by modification date to easily get a single result of the newest MTB image, and this path will never contain non-alphanumeric characters.
# shellcheck disable=SC2012
mtb_dmg_path="$(ls -t "${PROJECT_DIR}/../../MacLand Images/FreeGeek-MacTestBoot-"*'.dmg' | head -1)"
echo -e "\nMounting MTB Source DMG \"${mtb_dmg_path##*/}\" to Get Version..."
mtb_source_volume="$(hdiutil attach "${mtb_dmg_path}" -nobrowse -readonly -plist 2> /dev/null | xmllint --xpath 'string(//string[starts-with(text(), "/Volumes/")])' - 2> /dev/null)"
if [[ -d "${mtb_source_volume}" ]]; then
	all_mtb_start_timestamp="$(date '+%s')"

	mtb_source_version="$(< "${mtb_source_volume}/private/var/root/.mtbVersion")"
	echo "MTB Source Version: ${mtb_source_version}"
	echo "Unmounting MTB Source DMG at \"${mtb_source_volume}\"..."
	hdiutil detach "${mtb_source_volume}" &> /dev/null || hdiutil detach "${mtb_source_volume}" -force &> /dev/null || >&2 echo "ERROR: Failed to unmount DMG at \"${mtb_source_volume}\"."

	echo -e '\nUpdating Connected MTBs...'
	background_pids=()
	for this_mtb_volume in '/Volumes/Mac Test Boot'*; do
		if [[ -d "${this_mtb_volume}" ]]; then
			this_mtb_volume_info_plist="$(diskutil info -plist "${this_mtb_volume}" 2> /dev/null)"
			if [[ "$(echo "${this_mtb_volume_info_plist}" | plutil -extract 'WritableVolume' raw - 2> /dev/null)" == 'true' ]]; then # Do not want to detect UNWRITABLE mounted DMG as target.
				this_mtb_parent_disk_size="$(diskutil info -plist "$(echo "${this_mtb_volume_info_plist}" | plutil -extract 'ParentWholeDisk' raw - 2> /dev/null)" 2> /dev/null | plutil -extract 'TotalSize' raw - 2> /dev/null)"
				if (( this_mtb_parent_disk_size > 33000000000 )); then # The MTB source drive is 32 GB but all production drives are 120+ GB.
					(( connected_mtb_count ++ ))
					this_connected_mtb_version="$(< "${this_mtb_volume}/private/var/root/.mtbVersion")"
					if [[ "${this_connected_mtb_version}" != "${mtb_source_version}" ]]; then
						echo "Updating Connected MTB at \"${this_mtb_volume}\"..."
						
						{
							this_mtb_start_timestamp="$(date '+%s')"

							asr restore --source "${mtb_dmg_path}" --target "${this_mtb_volume}" --erase --noprompt
							asr_exit_code="$?"

							if (( asr_exit_code != 0 )); then
								echo "ERROR: \"asr\" on \"${this_mtb_volume}\" failed with exit code ${asr_exit_code}."
							fi

							echo "Finished Updating MTB on \"${this_mtb_volume}\" in $(human_readable_duration_from_seconds "$(( $(date '+%s') - this_mtb_start_timestamp ))")"

							exit "${asr_exit_code}"
						} &
						background_pids+=( "$!" )
					else
						echo "Connected MTB at \"${this_mtb_volume}\" Already Up-to-Date"
					fi
				else
					echo "Ignoring & Unmounting SOURCE MTB at \"${this_mtb_volume}\"..."
					diskutil unmount "${this_mtb_volume}" &> /dev/null || diskutil unmount force "${this_mtb_volume}" &> /dev/null || >&2 echo "ERROR: Failed to unmount SOURCE MTB at \"${this_mtb_volume}\"."
				fi
			else
				echo "Ignoring & Unmounting UNWRITABLE MTB at \"${this_mtb_volume}\""
				diskutil unmount "${this_mtb_volume}" &> /dev/null || diskutil unmount force "${this_mtb_volume}" &> /dev/null || >&2 echo "ERROR: Failed to unmount UNWRITABLE MTB at \"${this_mtb_volume}\"."
			fi
		fi
	done

	mtb_failed_count=0
	for this_background_pid in "${background_pids[@]}"; do # Wait for child "asr" processes (and check each exit code) for the MTBs to finish before moving on.
		if ! wait "${this_background_pid}"; then
			((mtb_failed_count ++ ))
		fi
	done

	echo -e "\nFinished Updating MTB on ${connected_mtb_count} Mac Drives in $(human_readable_duration_from_seconds "$(( $(date '+%s') - all_mtb_start_timestamp ))")"

	some_mtb_failed=false
	if (( mtb_failed_count > 0 )); then
		>&2 echo "ERROR: ${mtb_failed_count} \"asr\" processes exited with non-zero exit codes (see detailed errors above)."
		some_mtb_failed=true
	fi
	
	if (( connected_mtb_count == 0 )); then
		echo 'No Connected MTBs Found'
	else
		for this_mtb_volume in '/Volumes/Mac Test Boot'*; do
			if [[ -d "${this_mtb_volume}" ]]; then
				this_connected_mtb_version="$(< "${this_mtb_volume}/private/var/root/.mtbVersion")"
				if [[ "${this_connected_mtb_version}" != "${mtb_source_version}" ]]; then
					>&2 echo "ERROR: Failed to update connected MTB at \"${this_mtb_volume}\"."
					some_mtb_failed=true
				elif ! $some_mtb_failed; then
					echo "Unmounting Connected MTB at \"${this_mtb_volume}\"..."
					diskutil unmount "${this_mtb_volume}" &> /dev/null || diskutil unmount force "${this_mtb_volume}" &> /dev/null || >&2 echo "ERROR: Failed to unmount connected MTB at \"${this_mtb_volume}\"."
				fi
			fi
		done
	fi

	if $some_mtb_failed; then
		afplay /System/Library/Sounds/Basso.aiff
		exit 5
	fi
else
	>&2 echo "ERROR: \"${mtb_dmg_path}\" MTB source DMG was not found or mounted."
	afplay /System/Library/Sounds/Basso.aiff
	exit 4
fi

echo -e '\nUpdating Connected fgMIBs...'
bash "${PROJECT_DIR}/fgMIB Resources/Build Tools/copy-fgMIB-resources-to-drives.sh"

echo -e "\nFinished Updating All Mac Drives in $(human_readable_duration_from_seconds "$(( $(date '+%s') - overall_start_timestamp ))")"

afplay /System/Library/Sounds/Glass.aiff
