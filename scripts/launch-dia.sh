#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Dia (AppleScript JS)
# @raycast.mode silent
# @raycast.packageName Browsers
# @raycast.icon 🌐
#
# Launches Dia with --enable-applescript-javascript, which ProfileRouter needs
# for YouTube playback-position preservation when moving tabs between profiles.
# Cold start passes the flag; if Dia is already running it just focuses it
# (so re-triggering won't kill your session).

if pgrep -x Dia >/dev/null; then
  open -a Dia                                          # already running -> focus
else
  open -a Dia --args --enable-applescript-javascript   # cold start -> with flag
fi
