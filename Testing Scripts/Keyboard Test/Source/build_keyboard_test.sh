#!/bin/bash
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables,require-double-brackets

# By: Pico Mitchell
# For: MacLand @ Free Geek
# Last Updated: 07/01/24
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

# This script required Nativefier (https://github.com/jiahaog/nativefier) which is a Node.js package.
# First, install Node.js: https://nodejs.org/en/download/
# Then, install Nativifier by running the following command in a Terminal window: sudo npm install -g nativefier
# Finally, run this script by drag-and-dropping it into a Terminal window.

PATH='/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin' # PATH must include "/usr/local/bin" for npm (and node) and nativefier.

PROJECT_PATH="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)"
readonly PROJECT_PATH

echo 'NOTICE: THIS SCRIPT HAS BEEN REPLACED BY https://github.com/freegeek-pdx/Keyboard-Test'
open "${PROJECT_PATH}/../../../../Keyboard Test"

exit 1

readonly BUILD_DIR="${PROJECT_PATH}/.."
readonly ZIPS_FOR_AUTO_UPDATE_PATH="${BUILD_DIR}/../../ZIPs for Auto-Update"
readonly fgMIB_USERAPPS_PATH="${BUILD_DIR}/../../fgMIB Resources/Prepare OS Package/Package Resources/User/fg-demo/Apps/darwin-all-versions"

readonly KEYBOARD_TESTER_URL='https://www.keyboardtester.com/tester.html'

readonly APP_BUILD='1' # REMEMBER TO RESET THIS TO "1" IF CHANGED FROM PREVIOUS BUILD!
APP_VERSION="$(date '+%Y.%-m.%-d')-${APP_BUILD}" # https://strftime.org
readonly APP_VERSION


echo -e '\nUPDATING NATIVEFIER (ADMIN PASSWORD REQUIRED)...'
sudo npm install -g nativefier

rm -rf "${BUILD_DIR}/Keyboard Test-win32-x64" "${BUILD_DIR}/Keyboard Test" "${BUILD_DIR}/KeyboardTest-windows.zip" "${BUILD_DIR}/KeyboardTest-linux-x64" "${BUILD_DIR}/keyboard-test" "${BUILD_DIR}/KeyboardTest-linux.zip" "${BUILD_DIR}/Keyboard Test-darwin-universal" "${BUILD_DIR}/darwin-universal-template-"* "${BUILD_DIR}/Keyboard Test-darwin-x64" "${BUILD_DIR}/Keyboard Test.app" "${BUILD_DIR}/Keyboard-Test.zip" "${HOME}/Library/Application Support/keyboard-test"*
# Any existing Application Support files are also being deleted since that stores the last window size which we don't want to remember if it's getting changed.

app_copyright='© KeyboardTester.com

Modifications by Pico Mitchell for Free Geek

App Wrapper Built with Nativefier

App Icon is “Keyboard” from Twemoji by Twitter licensed under CC-BY 4.0'

for this_platform in 'windows' 'linux'; do
	echo -e "\n\nBUILDING KEYBOARD TEST $(echo "${this_platform}" | tr '[:lower:]' '[:upper:]') APP (VERSION ${APP_VERSION}) WITH NATIVEFIER..."

	nativefier \
		"${KEYBOARD_TESTER_URL}" \
		"${BUILD_DIR}" \
		--name 'Keyboard Test' \
		--platform "${this_platform}" \
		--arch 'x64' \
		--app-version "${APP_VERSION}" \
		--app-copyright "${app_copyright}" \
		--icon "${PROJECT_PATH}/Keyboard Test Icon/Twemoji Keyboard 1024.png" \
		--internal-urls "${KEYBOARD_TESTER_URL//./\\.}" \
		--strict-internal-urls \
		--inject "${PROJECT_PATH}/keyboard_test_modifications-windows-linux.js" \
		--inject "${PROJECT_PATH}/keyboard_test_modifications-windows-linux.css" \
		--min-width 1190 \
		--min-height "$([[ "${this_platform}" == 'windows' ]] && echo '520' || echo '490')" \
		--max-width 1190 \
		--max-height "$([[ "${this_platform}" == 'windows' ]] && echo '520' || echo '490')" \
		--disable-dev-tools \
		--disable-gpu \
		--disable-context-menu \
		--fast-quit \
		--single-instance \
		--disable-old-build-warning-yesiknowitisinsecure # Do not ever want the Keyboard Test app to prompt "Old build detected" since it really doesn't matter for this kind of app.

	echo -e "\n\nZIPPING KEYBOARD TEST $(echo "${this_platform}" | tr '[:lower:]' '[:upper:]') APP..."

	app_folder_name='keyboard-test'
	if [[ "${this_platform}" == 'windows' ]]; then
		app_folder_name='Keyboard Test'
	fi

	mv -f "${BUILD_DIR}/Keyboard$([[ "${this_platform}" == 'windows' ]] && echo ' Test-win32' || echo 'Test-linux')-x64" "${BUILD_DIR}/${app_folder_name}"
	cd "${BUILD_DIR}" || exit 1
	zip -r "KeyboardTest-${this_platform}.zip" "${app_folder_name}"
	rm -rf "${BUILD_DIR:?}/${app_folder_name:?}"
done


echo -e "\n\nBUILDING KEYBOARD TEST MAC APP (VERSION ${APP_VERSION}) WITH NATIVEFIER..."

nativefier \
	"${KEYBOARD_TESTER_URL}" \
	"${BUILD_DIR}" \
	--name 'Keyboard Test' \
	--arch 'universal' \
	--app-version "${APP_VERSION}" \
	--app-copyright "${app_copyright}" \
	--icon "${PROJECT_PATH}/Keyboard Test Icon/Twemoji Keyboard.icns" \
	--internal-urls "${KEYBOARD_TESTER_URL//./\\.}" \
	--strict-internal-urls \
	--inject "${PROJECT_PATH}/keyboard_test_modifications-mac.js" \
	--inject "${PROJECT_PATH}/keyboard_test_modifications-mac.css" \
	--min-width 939 \
	--min-height 500 \
	--max-width 939 \
	--max-height 500 \
	--disable-dev-tools \
	--disable-gpu \
	--disable-context-menu \
	--darwin-dark-mode-support \
	--fast-quit \
	--single-instance \
	--disable-old-build-warning-yesiknowitisinsecure # Do not ever want the Keyboard Test app to prompt "Old build detected" since it really doesn't matter for this kind of app.

echo -e '\n\nMODIFYING KEYBOARD TEST MAC APP Info.plist & MOVING INTO BUILD DIR...'

app_info_plist_path="${BUILD_DIR}/Keyboard Test-darwin-universal/Keyboard Test.app/Contents/Info.plist"

plutil -remove 'CFBundleVersion' "${app_info_plist_path}"

plutil -replace 'LSMinimumSystemVersion' -string '10.13' "${app_info_plist_path}"

plutil -replace 'LSMultipleInstancesProhibited' -bool 'true' "${app_info_plist_path}"

mv "${BUILD_DIR}/Keyboard Test-darwin-universal/Keyboard Test.app/Contents/Resources/electron.icns" "${BUILD_DIR}/Keyboard Test-darwin-universal/Keyboard Test.app/Contents/Resources/Keyboard Test.icns"
plutil -replace 'CFBundleIconFile' -string 'Keyboard Test' "${app_info_plist_path}"

plutil -replace 'CFBundleIdentifier' -string 'org.freegeek.Keyboard-Test' "${app_info_plist_path}"

rm -rf "${BUILD_DIR}/Keyboard Test.app"
mv -f "${BUILD_DIR}/Keyboard Test-darwin-universal/Keyboard Test.app" "${BUILD_DIR}/Keyboard Test.app"
rm -rf "${BUILD_DIR}/Keyboard Test-darwin-universal" "${BUILD_DIR}/darwin-universal-template-"*


echo -e '\n\nCODE SIGNING KEYBOARD TEST MAC APP...'
codesign -fs 'Developer ID Application' --deep --strict "${BUILD_DIR}/Keyboard Test.app"


echo -e '\n\nZIPPING KEYBOARD TEST MAC APP & UPDATING VERSION IN latest-versions.txt...'

rm -f "${BUILD_DIR}/Keyboard-Test.zip"
rm -f "${ZIPS_FOR_AUTO_UPDATE_PATH}/Keyboard-Test.zip"
ditto -ck --keepParent --sequesterRsrc --zlibCompressionLevel 9 "${BUILD_DIR}/Keyboard Test.app" "${ZIPS_FOR_AUTO_UPDATE_PATH}/Keyboard-Test.zip"

mkdir -p "${fgMIB_USERAPPS_PATH}"
rm -f "${fgMIB_USERAPPS_PATH}/Keyboard-Test.zip"
ditto "${ZIPS_FOR_AUTO_UPDATE_PATH}/Keyboard-Test.zip" "${fgMIB_USERAPPS_PATH}/Keyboard-Test.zip"

if grep -qF 'Keyboard Test:' "${ZIPS_FOR_AUTO_UPDATE_PATH}/latest-versions.txt"; then
	sed -i '' "s/Keyboard Test: .*/Keyboard Test: ${APP_VERSION}/" "${ZIPS_FOR_AUTO_UPDATE_PATH}/latest-versions.txt"
else
	echo "Keyboard Test: ${APP_VERSION}" >> "${ZIPS_FOR_AUTO_UPDATE_PATH}/latest-versions.txt"
fi

echo -e '\n\nDONE!\n'
