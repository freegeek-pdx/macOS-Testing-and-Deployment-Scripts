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

PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/libexec' # Add "/usr/libexec" to PATH for easy access to PlistBuddy.

readonly MIST_PATH='/usr/local/bin/mist'

installer_dmgs_path="${HOME}/Documents/Programming/Free Geek/MacLand Images/macOS Installers"

declare -a installer_names_to_download=( 'High Sierra' 'Mojave' 'Catalina' 'Big Sur' 'Monterey' 'Ventura' )

for this_installer_name_to_download in "${installer_names_to_download[@]}"; do
	mist_list_options=( 'list' 'installer' )
	if [[ "${this_installer_name_to_download}" == *' beta' ]]; then
		mist_list_options+=( '-b' )
	fi
	mist_list_options+=( '-l' '-q' '-o' 'plist' "${this_installer_name_to_download}" )

	this_installer_info_plist="$("${MIST_PATH}" "${mist_list_options[@]}")"

	this_installer_name="$(PlistBuddy -c 'Print :0:name' /dev/stdin <<< "${this_installer_info_plist}" 2> /dev/null)"
	this_installer_build="$(PlistBuddy -c 'Print :0:build' /dev/stdin <<< "${this_installer_info_plist}" 2> /dev/null)"
	this_installer_version="$(PlistBuddy -c 'Print :0:version' /dev/stdin <<< "${this_installer_info_plist}" 2> /dev/null)"

	if [[ -n "${this_installer_name}" && -n "${this_installer_build}" && -n "${this_installer_version}" ]]; then
		this_installer_dmg_name="Install ${this_installer_name} ${this_installer_version}-${this_installer_build}.dmg"

		if [[ -f "${installer_dmgs_path}/${this_installer_dmg_name}" ]]; then
			echo "\"${this_installer_dmg_name}\" is up-to-date!"
		else
			echo "\"${this_installer_dmg_name}\" needs to be downloaded..."
			rm -f "${installer_dmgs_path}/Install ${this_installer_name} "*'.dmg' # Delete any outdated installer dmgs.

			mist_download_options=( 'download' 'installer' "${this_installer_name}" 'image' )
			if [[ "${this_installer_name_to_download}" == *' beta' ]]; then
				mist_download_options+=( '-b' )
			fi
			mist_download_options+=( '-o' "${installer_dmgs_path}" )

			sudo "${MIST_PATH}" "${mist_download_options[@]}"
		fi
	else
		echo "\"${this_installer_name_to_download}\" WAS NOT FOUND!"
	fi
done
