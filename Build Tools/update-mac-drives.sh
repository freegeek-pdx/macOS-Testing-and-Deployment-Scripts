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

if (( ${EUID:-$(id -u)} != 0 )); then
	>&2 echo 'ERROR: This script must be run as root (to be able to run the "createinstallmedia" and "asr" commands).'
	afplay /System/Library/Sounds/Basso.aiff
	exit 1
fi


declare -a installer_names_to_update=( 'High Sierra' 'Mojave' 'Catalina' 'Big Sur' 'Monterey' 'Ventura' )

for this_installer_name_to_update in "${installer_names_to_update[@]}"; do
	found_connected_installer_for_os=false
	# Suppress ShellCheck suggestion to use "find" instead of "ls" since we need "ls -t" to sort by modification date to easily get a single result of the newest installer, and this path will never contain non-alphanumeric characters.
	# shellcheck disable=SC2012
	installer_dmg_path="$(ls -t "${PROJECT_DIR}/../../MacLand Images/macOS Installers/Install macOS ${this_installer_name_to_update}"*'.dmg' | head -1)"
	echo -e "\nMounting Installer DMG \"${installer_dmg_path##*/}\"..."
	installer_source_volume="$(hdiutil attach "${installer_dmg_path}" -nobrowse -readonly -plist 2> /dev/null | xmllint --xpath 'string(//string[starts-with(text(), "/Volumes/")])' - 2> /dev/null)"
	if [[ -d "${installer_source_volume}" ]]; then
		installer_source_version="$(PlistBuddy -c 'Print :CFBundleVersion' "${installer_source_volume}/Install macOS ${this_installer_name_to_update}.app/Contents/version.plist")"

		echo "Mounted Installer DMG at \"${installer_source_volume}\" & Updating Connected Installers..."
		for this_os_installer_volume in "/Volumes/Install macOS ${this_installer_name_to_update}"*; do
			if [[ -d "${this_os_installer_volume}" && "${this_os_installer_volume}" != "${installer_source_volume}" ]]; then
				found_connected_installer_for_os=true
				this_os_installer_version="$(PlistBuddy -c 'Print :CFBundleVersion' "${this_os_installer_volume}/Install macOS ${this_installer_name_to_update}.app/Contents/version.plist")"
				if [[ "${this_os_installer_version}" != "${installer_source_version}" ]]; then
					echo "Updating Connected Installer at \"${this_os_installer_volume}\"..."
					"${installer_source_volume}/Install macOS ${this_installer_name_to_update}.app/Contents/Resources/createinstallmedia" --volume "${this_os_installer_volume}" --nointeraction &
					sleep 10 # Sleep a bit before starting the next "createinstallmedia" process since I've seen them fail consistently with "Couldn't find InstallInfo.plist" and "The bless of the installer disk failed." when two Montery "createinstallmedia" processes were started at the same time.
				else
					echo "Connected Installer at \"${this_os_installer_volume}\" Already Up-to-Date"
				fi
			fi
		done

		wait # Wait for child "createinstallmedia" processes for this OS version to finish before moving to the next to not tax each drive too much by writing to multiple partitions at the same time which tends to cause more failures.

		some_update_failed=false
		if ! $found_connected_installer_for_os; then
			echo "No Connected ${this_installer_name_to_update} Installers Found"
		else
			for this_os_installer_volume in "/Volumes/Install macOS ${this_installer_name_to_update}"*; do
				if [[ -d "${this_os_installer_volume}" && "${this_os_installer_volume}" != "${installer_source_volume}" ]]; then
					this_os_installer_version="$(PlistBuddy -c 'Print :CFBundleVersion' "${this_os_installer_volume}/Install macOS ${this_installer_name_to_update}.app/Contents/version.plist")"
					if [[ "${this_os_installer_version}" != "${installer_source_version}" ]]; then
						>&2 echo "ERROR: Failed to update connected installer at \"${this_os_installer_volume}\"."
						some_update_failed=true
					else
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


found_connected_mtb=false
# Suppress ShellCheck suggestion to use "find" instead of "ls" since we need "ls -t" to sort by modification date to easily get a single result of the newest MTB image, and this path will never contain non-alphanumeric characters.
# shellcheck disable=SC2012
mtb_dmg_path="$(ls -t "${PROJECT_DIR}/../../MacLand Images/FreeGeek-MacTestBoot-"*'.dmg' | head -1)"
echo -e "\nMounting MTB Source DMG \"${mtb_dmg_path##*/}\" to Get Version..."
mtb_source_volume="$(hdiutil attach "${mtb_dmg_path}" -nobrowse -readonly -plist 2> /dev/null | xmllint --xpath 'string(//string[starts-with(text(), "/Volumes/")])' - 2> /dev/null)"
if [[ -d "${mtb_source_volume}" ]]; then
	mtb_source_version="$(< "${mtb_source_volume}/private/var/root/.mtbVersion")"
	echo "MTB Source Version: ${mtb_source_version}"
	echo "Unmounting MTB Source DMG at \"${mtb_source_volume}\"..."
	hdiutil detach "${mtb_source_volume}" &> /dev/null || hdiutil detach "${mtb_source_volume}" -force &> /dev/null || >&2 echo "ERROR: Failed to unmount DMG at \"${mtb_source_volume}\"."

	echo -e '\nUpdating Connected MTBs...'
	for this_mtb_volume in '/Volumes/Mac Test Boot'*; do
		if [[ -d "${this_mtb_volume}" ]]; then
			found_connected_mtb=true
			this_connected_mtb_version="$(< "${this_mtb_volume}/private/var/root/.mtbVersion")"
			if [[ "${this_connected_mtb_version}" != "${mtb_source_version}" ]]; then
				echo "Updating Connected MTB at \"${this_mtb_volume}\"..."
				asr restore --source "${mtb_dmg_path}" --target "${this_mtb_volume}" --erase --noprompt &
			else
				echo "Connected MTB at \"${this_mtb_volume}\" Already Up-to-Date"
			fi
		fi
	done

	wait # Wait for child "asr" processes for the MTBs to finish before moving on.

	some_mtb_failed=false
	if ! $found_connected_mtb; then
		echo 'No Connected MTBs Found'
	else
		for this_mtb_volume in '/Volumes/Mac Test Boot'*; do
			if [[ -d "${this_mtb_volume}" ]]; then
				this_connected_mtb_version="$(< "${this_mtb_volume}/private/var/root/.mtbVersion")"
				if [[ "${this_connected_mtb_version}" != "${mtb_source_version}" ]]; then
					>&2 echo "ERROR: Failed to update connected MTB at \"${this_mtb_volume}\"."
					some_mtb_failed=true
				else
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

afplay /System/Library/Sounds/Glass.aiff
