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

PATH='/usr/bin:/bin:/usr/sbin:/sbin'

set -x

PROJECT_DIR="$(cd "${BASH_SOURCE[0]%/*}" &> /dev/null && pwd -P)/.."
readonly PROJECT_DIR

install_package_script_announcements_dir="${PROJECT_DIR}/Install Packages Script/Announcements"
prepare_os_package_announcements_dir="${PROJECT_DIR}/Prepare OS Package/Package Resources/Announcements"
error_occurred_announcements_dir="${PROJECT_DIR}/Prepare OS Package/Package Resources/fg-error-occurred/Announcements"
snapshot_reset_announcements_dir="${PROJECT_DIR}/Prepare OS Package/Package Resources/fg-snapshot-reset/Announcements"

# NOTE: These are recorded with the System Voice set to "Siri (Voice 5)" which works
# with "say" when it uses the default system voice (without specifying "-v"),
# but there does not seem to be a way to use "say -v" to set "Siri (Voice 5)" explicitly.

say 'Starting Free Geek customizations…' -o "${install_package_script_announcements_dir}/fg-starting-customizations.aiff"
ditto "${install_package_script_announcements_dir}/fg-starting-customizations.aiff" "${prepare_os_package_announcements_dir}"

say 'Completed Free Geek customizations!' -o "${prepare_os_package_announcements_dir}/fg-completed-customizations.aiff"


say 'Starting Free Geek reset…' -o "${snapshot_reset_announcements_dir}/fg-starting-reset.aiff"

say 'Completed Free Geek reset!' -o "${snapshot_reset_announcements_dir}/fg-completed-reset.aiff"


say 'Do not disturb this Mac!' -o "${install_package_script_announcements_dir}/fg-do-not-disturb.aiff"
ditto "${install_package_script_announcements_dir}/fg-do-not-disturb.aiff" "${prepare_os_package_announcements_dir}"
ditto "${install_package_script_announcements_dir}/fg-do-not-disturb.aiff" "${snapshot_reset_announcements_dir}"

say 'Shutting down this Mac!' -o "${snapshot_reset_announcements_dir}/fg-shutting-down.aiff"

say 'Rebooting this Mac!' -o "${install_package_script_announcements_dir}/fg-rebooting.aiff"


say 'An error has occurred!' -o "${install_package_script_announcements_dir}/fg-error-occurred.aiff"
ditto "${install_package_script_announcements_dir}/fg-error-occurred.aiff" "${prepare_os_package_announcements_dir}"
ditto "${install_package_script_announcements_dir}/fg-error-occurred.aiff" "${error_occurred_announcements_dir}"
ditto "${install_package_script_announcements_dir}/fg-error-occurred.aiff" "${snapshot_reset_announcements_dir}"

say 'This Mac cannot be sold!' -o "${snapshot_reset_announcements_dir}/fg-cannot-be-sold.aiff"

say 'Please deliver this Mac to Free Geek IT!' -o "${install_package_script_announcements_dir}/fg-deliver-to-it.aiff"
ditto "${install_package_script_announcements_dir}/fg-deliver-to-it.aiff" "${prepare_os_package_announcements_dir}"
ditto "${install_package_script_announcements_dir}/fg-deliver-to-it.aiff" "${error_occurred_announcements_dir}"
ditto "${install_package_script_announcements_dir}/fg-deliver-to-it.aiff" "${snapshot_reset_announcements_dir}"
