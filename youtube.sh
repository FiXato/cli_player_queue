#!/usr/bin/env bash
# (C) 2021, Filip H.F. "FiXato" Slagter, contact.fixato.org
set -o nounset -o pipefail
username=${1:-""}

. "$(dirname "$(readlink -f "$0")")/functions.sh"

if [ "$username" != "" ]; then
	store_recent_youtube_video_titles_for_user "$username"
else
	videos_file=""$PLAY_VIDEO_YOUTUBE_DIR"/$(find "$PLAY_VIDEO_YOUTUBE_DIR" -type f -name '*.txt' | grep -oP "$PLAY_VIDEO_YOUTUBE_DIR"'/\K(.+)' | sort -u | fzf --preview "cat \"$PLAY_VIDEO_YOUTUBE_DIR/\"{}" --preview-window=down --no-sort --tac -q "'videos 'by_title.txt !^si")"
	error_code=$?
	(( $error_code > 0 )) && error_msg $error_code "Error while selecting file" && exit $error_code
	PLAY_VIDEO_HISTORY_FILE="$videos_file" play_video && "$0"

fi
