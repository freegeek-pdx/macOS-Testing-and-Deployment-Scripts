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

if ! ADMIN_PASSWORD="$(PlistBuddy -c 'Print :admin_password' "${PROJECT_DIR}/../../Build Tools/Free Geek Passwords.plist")" || [[ -z "${ADMIN_PASSWORD}" ]]; then
	echo 'FAILED TO GET ADMIN PASSWORD'
	exit 1
fi
readonly ADMIN_PASSWORD

if ! WIFI_PASSWORD="$(PlistBuddy -c 'Print :wifi_password' "${PROJECT_DIR}/../../Build Tools/Free Geek Passwords.plist")" || [[ -z "${WIFI_PASSWORD}" ]]; then
	echo 'FAILED TO GET WI-FI PASSWORD'
	exit 1
fi
readonly WIFI_PASSWORD

latest_firefox_version="$(curl -m 5 -sfw '%{redirect_url}' -o /dev/null 'https://download.mozilla.org/?product=firefox-pkg-latest-ssl&os=osx&lang=en-US' | awk -F '/' '{ print $7; exit }')"
if [[ -n "${latest_firefox_version}" ]]; then
	latest_firefox_pkg_path="${PROJECT_DIR}/Package Resources/Global/Apps/darwin-le-19/Firefox ${latest_firefox_version}.pkg"
	if [[ -f "${latest_firefox_pkg_path}" ]]; then
		echo "Firefox ${latest_firefox_version} PKG Is Up-to-Date"
	else
		rm -f "${PROJECT_DIR}/Package Resources/Global/Apps/darwin-le-19/Firefox"*'.pkg'
		echo "Downloading Firefox ${latest_firefox_version}..."
		mkdir -p "${latest_firefox_pkg_path%/*}"
		curl --connect-timeout 5 --progress-bar -fL 'https://download.mozilla.org/?product=firefox-pkg-latest-ssl&os=osx&lang=en-US' -o "${latest_firefox_pkg_path}"
	fi
else
	echo 'FAILED TO RETRIEVE LATEST FIREFOX VERSION'
fi

latest_drivedx_version="$(curl -m 5 -sfL 'https://binaryfruit.com/download/drivedx/mac/1/updates/?appcast&amp;appName=DriveDxMac' | xmllint --xpath 'string(//enclosure/@*[name()="sparkle:shortVersionString"])' -)"
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

latest_mactracker_version="$(curl -m 5 -sfL 'https://update.mactracker.ca/appcast-b.xml' | xmllint --xpath 'string(//enclosure/@*[name()="sparkle:version"])' -)"
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


# NOTE: KeyboardCleanTool (https://folivora.ai/keyboardcleantool) is also installed into user apps,
# but not sure how to check for latest version since the download link is always just "https://folivora.ai/releases/KeyboardCleanTool.zip".
# So, will just check/update it manually periodically instead of automating re-downloading the latest version (which may be the same as we already have) for every build.


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
