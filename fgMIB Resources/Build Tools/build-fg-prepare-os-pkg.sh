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

PROJECT_DIR="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)/../Prepare OS Package"
readonly PROJECT_DIR

TMPDIR="$([[ -d "${TMPDIR}" && -w "${TMPDIR}" ]] && echo "${TMPDIR%/}/" || echo '/private/tmp/')" # Make sure "TMPDIR" is always set and that it always has a trailing slash for consistency regardless of the current environment.

if ! ADMIN_PASSWORD="$(PlistBuddy -c 'Print :admin_password' "${PROJECT_DIR}/../../Build Tools/Free Geek Private Strings.plist")" || [[ -z "${ADMIN_PASSWORD}" ]]; then
	echo 'FAILED TO GET ADMIN PASSWORD'
	exit 1
fi
readonly ADMIN_PASSWORD

if ! WIFI_PASSWORD="$(PlistBuddy -c 'Print :wifi_password' "${PROJECT_DIR}/../../Build Tools/Free Geek Private Strings.plist")" || [[ -z "${WIFI_PASSWORD}" ]]; then
	echo 'FAILED TO GET WI-FI PASSWORD'
	exit 1
fi
readonly WIFI_PASSWORD


latest_firefox_version="$(curl -m 5 -sfw '%{redirect_url}' -o /dev/null 'https://download.mozilla.org/?product=firefox-pkg-latest-ssl&os=osx&lang=en-US' | awk -F '/' '{ print $7; exit }')"
if [[ -n "${latest_firefox_version}" ]]; then
	latest_firefox_pkg_path="${PROJECT_DIR}/Package Resources/Global/Apps/darwin-le-20/Firefox ${latest_firefox_version}.pkg"
	if [[ -f "${latest_firefox_pkg_path}" ]]; then
		echo "Firefox ${latest_firefox_version} PKG Is Up-to-Date"
	else
		rm -f "${PROJECT_DIR}/Package Resources/Global/Apps/darwin-le-20/Firefox"*'.pkg'
		echo "Downloading Firefox ${latest_firefox_version}..."
		mkdir -p "${latest_firefox_pkg_path%/*}"
		curl --connect-timeout 5 --progress-bar -fL 'https://download.mozilla.org/?product=firefox-pkg-latest-ssl&os=osx&lang=en-US' -o "${latest_firefox_pkg_path}"
	fi
else
	echo 'FAILED TO RETRIEVE LATEST FIREFOX VERSION'
fi

latest_drivedx_version="$(curl -m 5 -sfL 'https://binaryfruit.com/download/drivedx/mac/1/updates/?appcast&amp;appName=DriveDxMac' | xmllint --xpath 'string(//enclosure/@*[name()="sparkle:shortVersionString"])' - 2> /dev/null)"
if [[ -n "${latest_drivedx_version}" ]]; then
	latest_drivedx_zip_path="${PROJECT_DIR}/Package Resources/User/fg-demo/Apps/darwin-all-versions/DriveDx ${latest_drivedx_version}.zip"
	if [[ -f "${latest_drivedx_zip_path}" ]]; then
		echo "DriveDx ${latest_drivedx_version} ZIP Is Up-to-Date"
	else
		rm -f "${PROJECT_DIR}/Package Resources/User/fg-demo/Apps/darwin-all-versions/DriveDx"*'.zip'
		echo "Downloading DriveDx ${latest_drivedx_version}..."
		mkdir -p "${latest_drivedx_zip_path%/*}"
		curl --connect-timeout 5 --progress-bar -fL 'https://binaryfruit.com/download/drivedx/mac/1/' -o "${latest_drivedx_zip_path}"
	fi
else
	echo 'FAILED TO RETRIEVE LATEST DRIVEDX VERSION'
fi

latest_mactracker_version="$(curl -m 5 -sfL 'https://update.mactracker.ca/appcast-b.xml' | xmllint --xpath 'string(//enclosure/@*[name()="sparkle:version"])' - 2> /dev/null)"
if [[ -n "${latest_mactracker_version}" ]]; then
	latest_mactracker_zip_path="${PROJECT_DIR}/Package Resources/User/fg-demo/Apps/darwin-all-versions/Mactracker ${latest_mactracker_version}.zip"
	if [[ -f "${latest_mactracker_zip_path}" ]]; then
		echo "Mactracker ${latest_mactracker_version} ZIP Is Up-to-Date"
	else
		rm -f "${PROJECT_DIR}/Package Resources/User/fg-demo/Apps/darwin-all-versions/Mactracker"*'.zip'
		echo "Downloading Mactracker ${latest_mactracker_version}..."
		mkdir -p "${latest_mactracker_zip_path%/*}"
		curl --connect-timeout 5 --progress-bar -fL "https://mactracker.ca/downloads/Mactracker_${latest_mactracker_version}.zip" -o "${latest_mactracker_zip_path}"
	fi
else
	echo 'FAILED TO RETRIEVE LATEST MACTRACKER VERSION'
fi

keyboardcleantool_homebrew_cask_json="$(curl -m 5 -sfL 'https://formulae.brew.sh/api/cask/keyboardcleantool.json')" # https://folivora.ai/keyboardcleantool DOES NOT list a latest version,
# but there is a Homebrew Cask and the JSON for it does list the latest version, so using that as the source and hoping it is kept up-to-date (but KeyboardCleanTool updates are rare).
latest_keyboardcleantool_version="$(osascript -l 'JavaScript' -e 'run = argv => JSON.parse(argv[0]).version' -- "${keyboardcleantool_homebrew_cask_json}" 2> /dev/null)"
if [[ -n "${latest_keyboardcleantool_version}" ]]; then
	latest_keyboardcleantool_zip_path="${PROJECT_DIR}/Package Resources/User/fg-demo/Apps/darwin-all-versions/KeyboardCleanTool ${latest_keyboardcleantool_version}.zip"
	if [[ -f "${latest_keyboardcleantool_zip_path}" ]]; then
		echo "KeyboardCleanTool ${latest_keyboardcleantool_version} ZIP Is Up-to-Date"
	else
		rm -f "${PROJECT_DIR}/Package Resources/User/fg-demo/Apps/darwin-all-versions/KeyboardCleanTool"*'.zip'
		echo "Downloading KeyboardCleanTool ${latest_keyboardcleantool_version}..."
		mkdir -p "${latest_keyboardcleantool_zip_path%/*}"
		curl --connect-timeout 5 --progress-bar -fL 'https://folivora.ai/releases/KeyboardCleanTool.zip' -o "${latest_keyboardcleantool_zip_path}"
	fi
else
	echo 'FAILED TO RETRIEVE LATEST KEYBOARDCLEANTOOL VERSION'
fi

# Download the latest Geekbench 6 for macOS 11 Big Sur and newer.
geekbench_download_url="$(curl -m 5 -sfL 'https://www.geekbench.com/download/mac/' | xmllint --html --xpath 'string(//a[contains(@href,"Mac.zip")]/@href)' - 2> /dev/null)"
latest_geekbench_version="$(echo "${geekbench_download_url}" | cut -d '-' -f 2)"
if [[ -n "${latest_geekbench_version}" ]]; then
	latest_geekbench_zip_path="${PROJECT_DIR}/Package Resources/User/fg-demo/Apps/darwin-ge-20/Geekbench ${latest_geekbench_version}.zip"
	if [[ -f "${latest_geekbench_zip_path}" ]]; then
		echo "Geekbench ${latest_geekbench_version} ZIP Is Up-to-Date"
	else
		rm -f "${PROJECT_DIR}/Package Resources/User/fg-demo/Apps/darwin-ge-20/Geekbench"*'.zip'
		echo "Downloading Geekbench ${latest_geekbench_version}..."
		mkdir -p "${latest_geekbench_zip_path%/*}"
		curl --connect-timeout 5 --progress-bar -fL "${geekbench_download_url}" -o "${latest_geekbench_zip_path}"
	fi
else
	echo 'FAILED TO RETRIEVE LATEST GEEKBENCH VERSION'
fi

# AND ALSO download Geekbench 5 for macOS 10.15 Catalina and older (not sure if any update beyond v5.5.1 will ever be released now that v6 is out, but doesn't hurt to check).
geekbench5_download_url="$(curl -m 5 -sfL 'https://www.geekbench.com/legacy/' | xmllint --html --xpath 'string(//a[contains(@href,"Geekbench-5") and contains(@href,"Mac.zip")]/@href)' - 2> /dev/null)"
latest_geekbench5_version="$(echo "${geekbench5_download_url}" | cut -d '-' -f 2)"
if [[ -n "${latest_geekbench5_version}" ]]; then
	latest_geekbench_zip_path="${PROJECT_DIR}/Package Resources/User/fg-demo/Apps/darwin-le-19/Geekbench ${latest_geekbench5_version}.zip"
	if [[ -f "${latest_geekbench_zip_path}" ]]; then
		echo "Geekbench ${latest_geekbench5_version} ZIP Is Up-to-Date"
	else
		rm -f "${PROJECT_DIR}/Package Resources/User/fg-demo/Apps/darwin-le-19/Geekbench"*'.zip'
		echo "Downloading Geekbench ${latest_geekbench5_version}..."
		mkdir -p "${latest_geekbench_zip_path%/*}"
		curl --connect-timeout 5 --progress-bar -fL "${geekbench5_download_url}" -o "${latest_geekbench_zip_path}"
	fi
else
	echo 'FAILED TO RETRIEVE LATEST GEEKBENCH 5 VERSION'
fi

# NOTE: INVESTIGATING PRE-INSTALLATING SAFARI UPDATES, BUT NOT CURRENTLY DOING SO IN PRODUCTION

# sucatalog_url='https://swscan.apple.com/content/catalogs/others/index-14-13-12-10.16-10.15-10.14-10.13-10.12-10.11-10.10-10.9-mountainlion-lion-snowleopard-leopard.merged-1.sucatalog.gz'
# if ! sucatalog_plist="$(curl -m 10 -sfL --compressed "${sucatalog_url}")" || [[ "${sucatalog_plist}" != *'<plist'* ]]; then
# 	>&2 echo 'ERROR: Failed to download Software Update Catalog for Safari Packages.'
# fi

# # Use Objective-C bridge of JavaScript for Automation (JXA) to get the Safari package URLs since it requires semi-complex
# # plist traversal which is much simpler using a JavaScript dictionary rather than multiple "PlistBuddy" commands in the shell.
# IFS=$'\n' read -rd '' -a safari_urls < <(printf '%s\n' "${sucatalog_plist}" | osascript -l JavaScript -e '
# "use strict"
# const stdinFileHandle = $.NSFileHandle.fileHandleWithStandardInput
# const sucatalogPlist = $.NSString.alloc.initWithDataEncoding((stdinFileHandle.respondsToSelector("readDataToEndOfFileAndReturnError:") ? stdinFileHandle.readDataToEndOfFileAndReturnError(ObjC.wrap()) : stdinFileHandle.readDataToEndOfFile), $.NSUTF8StringEncoding)
# const safariURLs = []
# Object.values(ObjC.deepUnwrap($.NSPropertyListSerialization.propertyListWithDataOptionsFormatError(ObjC.wrap(sucatalogPlist).dataUsingEncoding($.NSUTF8StringEncoding), $.NSPropertyListImmutable, null, ObjC.wrap())).Products).forEach(thisProductDict => {
# 	thisProductDict.Packages.forEach(thisPackageDict => {
# 		const thisPackageURL = thisPackageDict.URL
# 		if (thisPackageURL && thisPackageURL.includes("/Safari") && thisPackageURL.endsWith("Auto.pkg"))
# 			safariURLs.push(thisPackageURL)
# 	})
# })
# safariURLs.join("\n")
# ' 2> /dev/null)

# for this_safari_url in "${safari_urls[@]}"; do
# 	this_safari_pkg_filename="${this_safari_url##*/}"
# 	this_safari_pkg_filename="${this_safari_pkg_filename%.*}"
# 	latest_safari_version="$(echo "${this_safari_pkg_filename}" | tr -dc '[:digit:].')"

# 	if [[ -n "${latest_safari_version}" ]]; then
# 		safari_darwin_folder=''
# 		if [[ "${this_safari_pkg_filename}" == *'Catalina'* ]]; then
# 			safari_darwin_folder='darwin-eq-19'
# 			this_safari_pkg_filename="Safari ${latest_safari_version} for Catalina"
# 		elif [[ "${this_safari_pkg_filename}" == *'BigSur'* ]]; then
# 			safari_darwin_folder='darwin-eq-20'
# 			this_safari_pkg_filename="Safari ${latest_safari_version} for Big Sur"
# 		elif [[ "${this_safari_pkg_filename}" == *'Monterey'* ]]; then # NOTE: The Safari update would be reverted by "Erase All Content & Settings" reset on T2 and Apple Silicon Macs running macOS 12 Monterey or newer so it will not be installed by "fg-prepare-os.sh" on them, but IS NOT reverted for Macs reset by Snapshot so it will be installed on those.
# 			safari_darwin_folder='darwin-eq-21'
# 			this_safari_pkg_filename="Safari ${latest_safari_version} for Monterey"
# 		elif [[ "${this_safari_pkg_filename}" == *'Ventura'* ]]; then
# 			safari_darwin_folder='darwin-eq-22'
# 			this_safari_pkg_filename="Safari ${latest_safari_version} for Ventura"
# 		fi

# 		if [[ -n "${safari_darwin_folder}" ]]; then
# 			latest_safari_pkg_path="${PROJECT_DIR}/Package Resources/Global/Apps/${safari_darwin_folder}/${this_safari_pkg_filename}.pkg"
# 			if [[ -f "${latest_safari_pkg_path}" ]]; then
# 				echo "${this_safari_pkg_filename} PKG Is Up-to-Date"
# 			else
# 				rm -f "${PROJECT_DIR}/Package Resources/Global/Apps/${safari_darwin_folder}/Safari"*'.pkg'
# 				echo "Downloading ${this_safari_pkg_filename}..."
# 				mkdir -p "${latest_safari_pkg_path%/*}"
# 				curl --connect-timeout 5 --progress-bar -fL "${this_safari_url}" -o "${latest_safari_pkg_path}"
# 			fi
# 		fi
# 	fi
# done


# Sign "fg-snapshot-preserver.sh" so that it can be displayed nicely in macOS 13 Ventura using "AssociatedBundleIdentifiers" in the LaunchDaemon.
# See "Setting Up Snapshot Preserver LaunchDaemon" section in "fg-prepare-os.sh" for more information.
codesign -fs 'Developer ID Application' --strict "${PROJECT_DIR}/Package Resources/fg-snapshot-reset/fg-snapshot-preserver.sh"

package_name='fg-prepare-os'
package_id="org.freegeek.${package_name}"

rm -rf "${PROJECT_DIR}/Package Scripts"
mkdir -p "${PROJECT_DIR}/Package Scripts"

# DO NOT JUST COPY "fg-prepare-os" SCRIPT SINCE ADMIN AND WI-FI PASSWORD PLACEHOLDERS NEED TO BE REPLACED WITH THE ACTUAL OBFUSCATED ADMIN AND WI-FI PASSWORDS.
sed "s/'\[BUILD PACKAGE SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED ADMIN PASSWORD\]'/\"\$(echo '$(echo -n "${ADMIN_PASSWORD}" | base64)' | base64 -D)\"/; s/'\[BUILD PACKAGE SCRIPT WILL REPLACE THIS PLACEHOLDER WITH OBFUSCATED WI-FI PASSWORD\]'/\"\$(echo '$(echo -n "${WIFI_PASSWORD}" | base64)' | base64 -D)\"/" "${PROJECT_DIR}/fg-prepare-os.sh" > "${PROJECT_DIR}/Package Scripts/postinstall"

chmod +x "${PROJECT_DIR}/Package Scripts/postinstall"
rm -f "${PROJECT_DIR}/Package Scripts/.DS_Store"

rm -f "${TMPDIR}${package_name}.pkg"
rm -f "${PROJECT_DIR}/${package_name}.pkg"

pkg_version="$(date '+%Y.%-m.%-d')" # https://strftime.org

pkgbuild \
	--install-location "/private/tmp/${package_id}" \
	--root "${PROJECT_DIR}/Package Resources" \
	--scripts "${PROJECT_DIR}/Package Scripts" \
	--identifier "${package_id}" \
	--version "${pkg_version}" \
	"${TMPDIR}${package_name}.pkg"

rm -rf "${PROJECT_DIR}/Package Scripts"

productbuild \
	--sign 'Developer ID Installer' \
	--package "${TMPDIR}${package_name}.pkg" \
	--identifier "${package_id}" \
	--version "${pkg_version}" \
	"${PROJECT_DIR}/${package_name}.pkg"

rm -f "${TMPDIR}${package_name}.pkg"
