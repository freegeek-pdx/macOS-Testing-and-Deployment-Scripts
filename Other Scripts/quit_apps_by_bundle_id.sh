#!/bin/sh
# shellcheck enable=add-default-case,avoid-nullary-conditions,check-unassigned-uppercase,deprecate-which,quote-safe-variables

quit_apps_by_bundle_id() { # Arguments = Bundle IDs to Quit (multiple can be specified)
	#
	# Created by Pico Mitchell (of Free Geek) on 9/13/22 (updated on 1/9/23).
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

	if [ "$#" -eq '0' ]; then
		>&2 echo 'Quit App by Bundle ID ERROR: At least one Bundle ID must be specified.'
		return 1
	fi

	# Based On: https://github.com/t-lark/Auto-Update/blob/master/app_quitter.py#L179-L190 (Copyright (c) 2019 Snowflake Inc. Licensed under the Apache License, Version 2.0)
	/usr/bin/osascript -l 'JavaScript' -e '
"use strict"
ObjC.import("AppKit")

function run(argv) {
	for (const thisBundleID of argv) {
		const runningAppsForBundleID = $.NSRunningApplication.runningApplicationsWithBundleIdentifier(thisBundleID).js

		for (const thisRunningApp of runningAppsForBundleID) { // An array is always returned, so must iterate all NSRunningApplication objects.
			thisRunningApp.terminate // First tell the app to quit itself gracefully.

			for (let waitForQuitSeconds = 0; waitForQuitSeconds < 6; waitForQuitSeconds ++) { // Wait for UP TO 3 seconds for the app to quit.
				delay(0.5) // Wait in half seconds so that we can be done quickly when the app quits itself gracefully.
				if (thisRunningApp.terminated)
					break
			}

			if (!thisRunningApp.terminated) // If app has not quit gracefully after 3 seconds, force quit it.
				thisRunningApp.forceTerminate
		}
	}
}
' -- "$@" 2> /dev/null
}

quit_apps_by_bundle_id "$@"
