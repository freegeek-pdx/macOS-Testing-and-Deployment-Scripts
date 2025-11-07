#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

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

PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec' # Add "/usr/libexec" to PATH for easy access to PlistBuddy.

PROJECT_DIR="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)/.."
readonly PROJECT_DIR

if ! WIFI_PASSWORD="$(PlistBuddy -c 'Print :wifi_password' "${PROJECT_DIR}/../Build Tools/Free Geek Private Strings.plist")" || [[ -z "${WIFI_PASSWORD}" ]]; then
	echo 'FAILED TO GET WI-FI PASSWORD'
	exit 1
fi
readonly WIFI_PASSWORD


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
connected_fgMIB_count=0

if [[ -f "${PROJECT_DIR}/fg-install-os.sh" && -f '/Users/Shared/Mac Deployment/fg-prepare-os.pkg' ]]; then
	for this_fgMIB_volume in '/Volumes/fgMIB'*; do
		if [[ -d "${this_fgMIB_volume}" ]]; then
			(( connected_fgMIB_count ++ ))
			echo "STARTING ${this_fgMIB_volume}"
			this_fgMIB_start_timestamp="$(date '+%s')"

			# There is no point comparing "fg-install-os" files (like we do with other files) since they will never match
			# because the source contains the password placeholder and the target contains the obfuscated password.
			# Not sure if it's worth trying to compare versions or make a temp copy of the "fg-install-os" file with the obfuscated password to compare with the target since it's such a small and quick file to copy.

			rm -f "${this_fgMIB_volume}/fg-install-os"
			echo 'COPYING fg-install-os...'
			
			# DO NOT JUST COPY "fg-install-os" SCRIPT SINCE WI-FI PASSWORD PLACEHOLDER NEED TO BE REPLACED WITH THE ACTUAL OBFUSCATED WI-FI PASSWORD.
			# CANNOT USE "base64", "openssl base64", "xxd", or "uuencode"/"uudecode" TO OBFUSCATE WI-FI PASSWORD IN "fg-install-os" SINCE THEY ARE NOT IN RECOVERY, SO MUST USE A "tr" SHIFT.
			sed "s/'\[COPY RESOURCES SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD\]'/\"\$(echo '$(echo -n "${WIFI_PASSWORD}" | tr '\!-~' 'P-~\!-O')' | tr '\!-~' 'P-~\!-O')\"/" "${PROJECT_DIR}/fg-install-os.sh" > "${this_fgMIB_volume}/fg-install-os"
			
			chmod +x "${this_fgMIB_volume}/fg-install-os"
			
			if [[ -d "${this_fgMIB_volume}/install-packages" && ! -e "${this_fgMIB_volume}/customization-resources" ]]; then # Rename old packages folder name to new folder name if needed.
				echo 'RENAMING install-packages TO customization-resources...'
				mv "${this_fgMIB_volume}/install-packages" "${this_fgMIB_volume}/customization-resources"
			fi

			if ! cmp -s '/Users/Shared/Mac Deployment/fg-prepare-os.pkg' "${this_fgMIB_volume}/customization-resources/fg-prepare-os.pkg"; then
				if [[ -d "${this_fgMIB_volume}/customization-resources" ]]; then
					rm -f "${this_fgMIB_volume}/customization-resources/fg-prepare-os.pkg"
				fi

				echo 'COPYING customization-resources/fg-prepare-os.pkg...'
				ditto '/Users/Shared/Mac Deployment/fg-prepare-os.pkg' "${this_fgMIB_volume}/customization-resources/fg-prepare-os.pkg" || exit
			else
				echo "EXACT COPY EXISTS: customization-resources/fg-prepare-os.pkg"
			fi

			for this_install_packages_script_file_or_folder in "${PROJECT_DIR}/Install Packages Script/"*; do
				this_install_packages_script_file_or_folder_name="${this_install_packages_script_file_or_folder##*/}"
				
				if [[ "${this_install_packages_script_file_or_folder_name}" == 'OLD-'* ]]; then
					echo "IGNORING OLD FILE OR FOLDER: customization-resources/${this_install_packages_script_file_or_folder_name}"
				else
					if [[ -f "${this_install_packages_script_file_or_folder}" ]]; then
						if ! cmp -s "${this_install_packages_script_file_or_folder}" "${this_fgMIB_volume}/customization-resources/${this_install_packages_script_file_or_folder_name}"; then
							rm -f "${this_fgMIB_volume}/customization-resources/${this_install_packages_script_file_or_folder_name}"
							echo "COPYING customization-resources/${this_install_packages_script_file_or_folder_name}..."
							ditto "${this_install_packages_script_file_or_folder}" "${this_fgMIB_volume}/customization-resources/${this_install_packages_script_file_or_folder_name}" || exit
						else
							echo "EXACT COPY EXISTS: customization-resources/${this_install_packages_script_file_or_folder_name}"
						fi
					elif [[ -d "${this_install_packages_script_file_or_folder}" ]]; then
						if [[ ! -d "${this_fgMIB_volume}/customization-resources/${this_install_packages_script_file_or_folder_name}" ]]; then
							mkdir -p "${this_fgMIB_volume}/customization-resources/${this_install_packages_script_file_or_folder_name}"
						fi

						for this_install_packages_script_subfolder_file_or_folder in "${this_install_packages_script_file_or_folder}/"*; do
							this_install_packages_script_subfolder_file_or_folder_name="${this_install_packages_script_subfolder_file_or_folder##*/}"

							if [[ "${this_install_packages_script_subfolder_file_or_folder_name}" == 'OLD-'* ]]; then
								echo "IGNORING OLD FILE OR FOLDER: customization-resources/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}"
							else
								if [[ -f "${this_install_packages_script_subfolder_file_or_folder}" ]]; then
									if ! cmp -s "${this_install_packages_script_subfolder_file_or_folder}" "${this_fgMIB_volume}/customization-resources/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}"; then
										rm -f "${this_fgMIB_volume}/customization-resources/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}"
										echo "COPYING customization-resources/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}..."
										ditto "${this_install_packages_script_subfolder_file_or_folder}" "${this_fgMIB_volume}/customization-resources/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}" || exit
									else
										echo "EXACT COPY EXISTS: customization-resources/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}"
									fi
								elif [[ -d "${this_install_packages_script_subfolder_file_or_folder}" ]]; then
									# TODO: Check if exact copy exists instead of always re-copying whole dir (which will be an app). THIS IS NO LONGER CURRENTLY IMPORTANT SINCE NO LONGER INCLUDING APPS IN HERE (INCLUDING ZIP INSTEAD).
									rm -rf "${this_fgMIB_volume}/customization-resources/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}"
									echo "COPYING customization-resources/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}..."
									ditto "${this_install_packages_script_subfolder_file_or_folder}" "${this_fgMIB_volume}/customization-resources/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}" || exit
								fi
							fi
						done
					fi
				fi
			done
			
			for this_extra_bins_folder in "${PROJECT_DIR}/extra-bins/"*; do
				if [[ -d "${this_extra_bins_folder}" ]]; then
					this_extra_bins_folder_name="${this_extra_bins_folder##*/}"
					
					if [[ ! -d "${this_fgMIB_volume}/extra-bins/${this_extra_bins_folder_name}" ]]; then
						mkdir -p "${this_fgMIB_volume}/extra-bins/${this_extra_bins_folder_name}"
					fi

					for this_extra_bins_versioned_file in "${this_extra_bins_folder}/"*; do
						if [[ -f "${this_extra_bins_versioned_file}" ]]; then
							this_extra_bins_versioned_file_name="${this_extra_bins_versioned_file##*/}"

							if ! cmp -s "${this_extra_bins_versioned_file}" "${this_fgMIB_volume}/extra-bins/${this_extra_bins_folder_name}/${this_extra_bins_versioned_file_name}"; then
								rm -f "${this_fgMIB_volume}/extra-bins/${this_extra_bins_folder_name}/${this_extra_bins_versioned_file_name}"
								echo "COPYING extra-bins/${this_extra_bins_folder_name}/${this_extra_bins_versioned_file_name}..."
								ditto "${this_extra_bins_versioned_file}" "${this_fgMIB_volume}/extra-bins/${this_extra_bins_folder_name}/${this_extra_bins_versioned_file_name}" || exit
							else
								echo "EXACT COPY EXISTS: extra-bins/${this_extra_bins_folder_name}/${this_extra_bins_versioned_file_name}"
							fi
						fi
					done
				fi
			done
			
			echo "DONE WITH ${this_fgMIB_volume} ($(human_readable_duration_from_seconds "$(( $(date '+%s') - this_fgMIB_start_timestamp ))")) - UNMOUNTING..."
			diskutil unmountDisk "${this_fgMIB_volume}"
		else
			echo "ERROR - fgMIB VOLUME NOT FOUND"
		fi
	done
else
	echo -e "ERROR - CRITICAL FILES NOT FOUND IN PROJECT_DIR:\n${PROJECT_DIR}"
fi

echo -e "\nFinished Updating fgMIB on ${connected_fgMIB_count} Mac Drives in $(human_readable_duration_from_seconds "$(( $(date '+%s') - overall_start_timestamp ))")"
