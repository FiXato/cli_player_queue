#!/usr/bin/env bash
# (C) 2021, Filip H.F. "FiXato" Slagter, contact.fixato.org
set -o nounset -o pipefail
query=${1:-""}

. "$(dirname "$(readlink -f "$0")")/functions.sh"

selected="$(cat "$PLAY_VIDEO_HISTORY_FILE" | fzf --exact -q "$query" -0 -1)"
error_code=$?
if (($error_code == 0)); then
	source="${selected%%#*}"
	echo "Launching $PLAYER for: $selected"
	$PLAYER $source
elif (($error_code == 130)); then # FZF was aborted with ctrl-c
	exit
elif (($error_code == 1)); then # FZF had no match
	capture_video_title "$query" || exit $?
	echo "$query # $video_title" >> $PLAY_VIDEO_HISTORY_FILE
	echo "Launching $PLAYER for: $query ($video_title)"
	$PLAYER "$query" # $video_title
elif (($error_code > 1)); then # FZF errored
	echo "Unknown error, likely with fzf. Error code: $error_code"
fi
