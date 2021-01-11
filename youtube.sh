#!/usr/bin/env bash
# (C) 2021, Filip H.F. "FiXato" Slagter, contact.fixato.org
set -o nounset -o pipefail
cmd="${1:-""}"

. "$(dirname "$(readlink -f "$0")")/functions.sh"

case "$cmd" in
	"update_feed_from_fzf")
		feed_username="$(echo "${2}" | grep -oP "$PLAY_VIDEO_YOUTUBE_DIR"'/\K[^/]+')"
		echo "Feed username: $feed_username" >> test.log && "$0" "update_feed" "$feed_username"
		;;

	"update_feed")
		username="$(ensure_param 2 "youtube_username" "$@")" || exit $?
		channel_id="${3:-""}"

		if [ "$channel_id" != "" ]; then
			store_channel_id_for_user "$username" "$channel_id"
		fi
		store_recent_youtube_video_titles_for_user "$username"
		;;

	"list")
		find "$PLAY_VIDEO_YOUTUBE_DIR" -type f -name '*.txt' | sort -u #| grep -oP "$PLAY_VIDEO_YOUTUBE_DIR"'/\K(.+)' | sort -u
		;;

	"")
		#FZF_DEFAULT_COMMAND="\"$(script_real_path)\" list" videos_file="$("$0" "list" | fzf --preview "cat {}" --preview-window=down --with-nth=-2,-1 --delimiter=/ --bind "ctrl-u:reload(tmux display-message updating && \"$(script_real_path)\" update_feed_from_fzf {} && $FZF_DEFAULT_COMMAND)" --no-sort --tac --query "'videos 'by_title.txt !^si")"

		videos_file="$(FZF_DEFAULT_COMMAND="$0"' list' fzf --preview "cat {}" --preview-window=down --with-nth=-2,-1 --delimiter=/ --bind 'ctrl-u:reload(tmux display-message updating && ./youtube.sh update_feed_from_fzf {} && $FZF_DEFAULT_COMMAND),ctrl-n:execute(read -p "Username? " username && read -p "Channel ID? " channel_id && ./youtube.sh update_feed "$username" "$channel_id")+reload($FZF_DEFAULT_COMMAND),ctrl-r:reload($FZF_DEFAULT_COMMAND)' --no-sort --tac --query "'videos '.by_title !^si")"

		error_code=$?
		(( $error_code > 0 )) && error_msg $error_code "Error while selecting file" && exit $error_code
		PLAY_VIDEO_HISTORY_FILE="${videos_file}" play_video && "$0"
		;;

	*)
		echo "Unknown command: '$cmd'"
		;;

esac
