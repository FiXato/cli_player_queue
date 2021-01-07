#!/usr/bin/env bash
# (C) 2021, Filip H.F. "FiXato" Slagter, contact.fixato.org
set -o nounset -o pipefail
PLAYER="${PLAYER:-mpv}"
PLAY_VIDEO_HISTORY_FILE=${PLAY_VIDEO_HISTORY_FILE:-~/.config/play_video_history.log}
query=${1:-""}
selected="$(cat "$PLAY_VIDEO_HISTORY_FILE" | fzf -q "$query" -0 -1)"
error_code=$?
if (($error_code == 0)); then
	source="${selected%%#*}"
	$PLAYER $source
elif (($error_code == 130)); then # FZF was aborted with ctrl-c
	exit
elif (($error_code == 1)); then # FZF had no match
	path_to_script="$(dirname "$(readlink -f "$0")")"
	video_title="$(${path_to_script}/get_title_from_url.sh "$query")"
	error_code=$?
	(( $error_code > 0 )) && exit $error_code
	echo "$query # $video_title" >> $PLAY_VIDEO_HISTORY_FILE
	$PLAYER "$query" # $video_title
elif (($error_code > 1)); then # FZF errored
	echo "Unknown error, likely with fzf. Error code: $error_code"
fi
