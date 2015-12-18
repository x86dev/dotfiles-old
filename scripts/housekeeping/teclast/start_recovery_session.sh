#!/bin/sh
#
# Boots a (x86-based) Teclast tablet into a temporary recovery
# session. Tested with various Teclast X98 Air 3G.
#
# To use this script, the tablet already must be in fastboot mode.
# To do that, turn the tablet off, press and hold volume- and press
# the power button while still holding the volume- button.
#
#

PATH_TO_INTEL_FBRL=/path/to/the/IntelAndroid-FBRL-XXX-package
PATH_TO_FASTBOOT=${HOME}/opt/android-sdk/platform-tools/fastboot

#
# Don't touch the stuff below unless you know
# what you're doing.
#

MY_TRIGGER="$PATH_TO_INTEL_FBRL/fbrl.trigger"
MY_LAUNCHER="$PATH_TO_INTEL_FBRL/recovery.launcher"
# Note: TWRP unusable -- no touch screen driver for Teclast X98.
MY_RECOVERY="$PATH_TO_INTEL_FBRL/cwm.zip"

MY_OEMTRIGGER="/system/bin/logcat"
MY_OEMCMD="stop_partitioning"

${PATH_TO_FASTBOOT} flash /tmp/recovery.zip ${MY_RECOVERY}
${PATH_TO_FASTBOOT} flash /tmp/recovery.launcher ${MY_LAUNCHER}

${PATH_TO_FASTBOOT} oem start_partitioning
${PATH_TO_FASTBOOT} flash "/system/bin/logcat" ${MY_TRIGGER}
${PATH_TO_FASTBOOT} oem stop_partitioning

