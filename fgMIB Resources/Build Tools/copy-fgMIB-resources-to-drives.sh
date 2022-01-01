#!/bin/bash

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

PROJECT_DIR="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd -P)/.."
readonly PROJECT_DIR

if ! WIFI_PASSWORD="$(/usr/libexec/PlistBuddy -c 'Print :wifi_password' "${PROJECT_DIR}/../Build Tools/Free Geek Passwords.plist")" || [[ -z "${WIFI_PASSWORD}" ]]; then
	echo 'FAILED TO GET WI-FI PASSWORD'
	exit 1
fi
readonly WIFI_PASSWORD

if [[ -f "${PROJECT_DIR}/fg-install-os.sh" && -f "${PROJECT_DIR}/Prepare OS Package/fg-prepare-os.pkg" ]]; then
	for this_fgMIB_volume in '/Volumes/fgMIB'*; do
		if [[ -d "${this_fgMIB_volume}" ]]; then
			echo "STARTING ${this_fgMIB_volume}"

			# There is no point comparing "fg-install-os" files (like we do with other files) since they will never match
			# because the source contains the password placeholder and the target contains the obfuscated password.
			# Not sure if it's worth trying to compare versions or make a temp copy of the "fg-install-os" file with the obfuscated password to compare with the target since it's such a small and quick file to copy.

			rm -f "${this_fgMIB_volume}/fg-install-os"
			echo 'COPYING fg-install-os...'
			
			# DO NOT JUST COPY "fg-install-os" SCRIPT SINCE WI-FI PASSWORD PLACEHOLDER NEED TO BE REPLACED WITH THE ACTUAL OBFUSCATED WI-FI PASSWORD.
			# CANNOT USE "base64", "openssl base64", "xxd", or "uuencode"/"uudecode" TO OBFUSCATE WI-FI PASSWORD IN "fg-install-os" SINCE THEY ARE NOT IN RECOVERY, SO MUST USE A "tr" SHIFT.
			sed "s/'\[COPY RESOURCES SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD\]'/\"\$(tr '\!-~' 'P-~\!-O' <<< '$(echo -n "${WIFI_PASSWORD}" | tr '\!-~' 'P-~\!-O')')\"/" "${PROJECT_DIR}/fg-install-os.sh" > "${this_fgMIB_volume}/fg-install-os"
			
			chmod +x "${this_fgMIB_volume}/fg-install-os"
			
			if ! cmp -s "${PROJECT_DIR}/Prepare OS Package/fg-prepare-os.pkg" "${this_fgMIB_volume}/install-packages/fg-prepare-os.pkg"; then
				if [[ -d "${this_fgMIB_volume}/install-packages" ]]; then
					rm -f "${this_fgMIB_volume}/install-packages/fg-prepare-os.pkg"
				fi

				echo 'COPYING install-packages/fg-prepare-os.pkg...'
				ditto "${PROJECT_DIR}/Prepare OS Package/fg-prepare-os.pkg" "${this_fgMIB_volume}/install-packages/fg-prepare-os.pkg"
			else
				echo "EXACT COPY EXISTS: install-packages/fg-prepare-os.pkg"
			fi

			for this_install_packages_script_file_or_folder in "${PROJECT_DIR}/Install Packages Script/"*; do
				this_install_packages_script_file_or_folder_name="$(basename "${this_install_packages_script_file_or_folder}")"
				
				if [[ -f "${this_install_packages_script_file_or_folder}" ]]; then
					if ! cmp -s "${this_install_packages_script_file_or_folder}" "${this_fgMIB_volume}/install-packages/${this_install_packages_script_file_or_folder_name}"; then
						rm -f "${this_fgMIB_volume}/install-packages/${this_install_packages_script_file_or_folder_name}"
						echo "COPYING install-packages/${this_install_packages_script_file_or_folder_name}..."
						ditto "${this_install_packages_script_file_or_folder}" "${this_fgMIB_volume}/install-packages/${this_install_packages_script_file_or_folder_name}"
					else
						echo "EXACT COPY EXISTS: install-packages/${this_install_packages_script_file_or_folder_name}"
					fi
				elif [[ -d "${this_install_packages_script_file_or_folder}" ]]; then
					if [[ ! -d "${this_fgMIB_volume}/install-packages/${this_install_packages_script_file_or_folder_name}" ]]; then
						mkdir -p "${this_fgMIB_volume}/install-packages/${this_install_packages_script_file_or_folder_name}"
					fi

					for this_install_packages_script_subfolder_file_or_folder in "${this_install_packages_script_file_or_folder}/"*; do
						this_install_packages_script_subfolder_file_or_folder_name="$(basename "${this_install_packages_script_subfolder_file_or_folder}")"

						if [[ -f "${this_install_packages_script_subfolder_file_or_folder}" ]]; then
							if ! cmp -s "${this_install_packages_script_subfolder_file_or_folder}" "${this_fgMIB_volume}/install-packages/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}"; then
								rm -f "${this_fgMIB_volume}/install-packages/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}"
								echo "COPYING install-packages/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}..."
								ditto "${this_install_packages_script_subfolder_file_or_folder}" "${this_fgMIB_volume}/install-packages/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}"
							else
								echo "EXACT COPY EXISTS: install-packages/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}"
							fi
						elif [[ -d "${this_install_packages_script_subfolder_file_or_folder}" ]]; then
							# TODO: Check if exact copy exists instead of always re-copying whole dir (which will be an app). THIS IS NO LONGER CURRENTLY IMPORTANT SINCE NO LONGER INCLUDING APPS IN HERE (INCLUDING ZIP INSTEAD).
							rm -rf "${this_fgMIB_volume}/install-packages/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}"
							echo "COPYING install-packages/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}..."
							ditto "${this_install_packages_script_subfolder_file_or_folder}" "${this_fgMIB_volume}/install-packages/${this_install_packages_script_file_or_folder_name}/${this_install_packages_script_subfolder_file_or_folder_name}"
						fi
					done
				fi
			done
			
			for this_extra_bins_folder in "${PROJECT_DIR}/extra-bins/"*; do
				if [[ -d "${this_extra_bins_folder}" ]]; then
					this_extra_bins_folder_name="$(basename "${this_extra_bins_folder}")"
					
					if [[ ! -d "${this_fgMIB_volume}/extra-bins/${this_extra_bins_folder_name}" ]]; then
						mkdir -p "${this_fgMIB_volume}/extra-bins/${this_extra_bins_folder_name}"
					fi

					for this_extra_bins_versioned_file in "${this_extra_bins_folder}/"*; do
						if [[ -f "${this_extra_bins_versioned_file}" ]]; then
							this_extra_bins_versioned_file_name="$(basename "${this_extra_bins_versioned_file}")"

							if ! cmp -s "${this_extra_bins_versioned_file}" "${this_fgMIB_volume}/extra-bins/${this_extra_bins_folder_name}/${this_extra_bins_versioned_file_name}"; then
								rm -f "${this_fgMIB_volume}/extra-bins/${this_extra_bins_folder_name}/${this_extra_bins_versioned_file_name}"
								echo "COPYING extra-bins/${this_extra_bins_folder_name}/${this_extra_bins_versioned_file_name}..."
								ditto "${this_extra_bins_versioned_file}" "${this_fgMIB_volume}/extra-bins/${this_extra_bins_folder_name}/${this_extra_bins_versioned_file_name}"
							else
								echo "EXACT COPY EXISTS: extra-bins/${this_extra_bins_folder_name}/${this_extra_bins_versioned_file_name}"
							fi
						fi
					done
				fi
			done
			
			echo "DONE WITH ${this_fgMIB_volume} - UNMOUNTING..."
			diskutil unmountDisk "${this_fgMIB_volume}"
		else
			echo "ERROR - fgMIB VOLUME NOT FOUND"
		fi
	done
else
	echo -e "ERROR - CRITICAL FILES NOT FOUND IN PROJECT_DIR:\n${PROJECT_DIR}"
fi
