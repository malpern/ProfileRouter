#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Dia (AppleScript JS)
# @raycast.mode silent
# @raycast.packageName Browsers
# @raycast.icon 🌐
#
# Launches Dia. Normally this would pass --enable-applescript-javascript, which
# ProfileRouter needs for YouTube playback-position preservation when moving tabs
# between profiles.
#
# DISABLED 2026-06-19: that flag reliably CRASHES Dia 1.36.0 (~30s after launch,
# stack-overflow / EXC_BAD_ACCESS — reproduced twice). Until Dia ships a fix we
# launch flagless; Ctrl+S cycling and domain auto-routing work fine without it,
# only the YouTube-position feature is lost.
#
# TO RE-ENABLE after a Dia update: uncomment the flagged line below and re-test.

if pgrep -x Dia >/dev/null; then
  open -a Dia                                            # already running -> focus
else
  open -a Dia                                            # cold start (flagless, safe)
  # open -a Dia --args --enable-applescript-javascript   # <- re-enable when Dia fixes the crash
fi
