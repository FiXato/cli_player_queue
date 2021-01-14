#!/usr/bin/env bash
# (C) 2021, Filip H.F. "FiXato" Slagter, contact.fixato.org
set -o nounset -o pipefail
cmd="${1:-""}"

. "$(dirname "$(readlink -f "$0")")/functions.sh"

case "$cmd" in
	"update_feed_from_fzf")
		feed_username="$(echo "${2}" | grep -oP "$PLAY_VIDEO_YOUTUBE_DIR"'/\K[^/]+')"
		"$0" "update_feed" "$feed_username"
		;;

	"update_feed")
		username="$(ensure_param 2 "youtube_username" "$@")" || exit $?
		channel_id="${3:-""}"

		if [ "$channel_id" != "" ]; then
			store_channel_id_for_user "$username" "$channel_id"
		fi
		store_recent_youtube_video_titles_for_user "$username"
		;;

	"update_feeds")
		newer_than_days="${2:-""}"
		find_args=""
		if [ "${newer_than_days:0:1}" == "-" ]; then
			find_args+=" !"
			newer_than_days="${newer_than_days:1}"
		fi
		if [ "$newer_than_days" != "" ]; then
			find_args+=" -ctime $newer_than_days"
		fi
		usernames="$(youtube_feed_names)" #FIXME: I guess theoretically a channel directory could have a slash in its name?
		echo "$usernames" | xargs -I {} "$0" update_feed {}
		;;

	"list")
		find "$PLAY_VIDEO_YOUTUBE_DIR" -type f -name '*.txt' | sort -u
		;;

	"grep")
		INITIAL_QUERY="${INITIAL_QUERY:-""}"
		RG_PREFIX="rg --column --line-number --no-heading --color=always --smart-case "
		RG_PATH="${PLAY_VIDEO_YOUTUBE_DIR}/*/videos.by_date.txt"
		readarray -t result < <(FZF_DEFAULT_COMMAND="$RG_PREFIX '$INITIAL_QUERY' $RG_PATH" fzf --print-query --bind "change:reload:$RG_PREFIX {q} $RG_PATH || true" --ansi --phony --query "$INITIAL_QUERY" --layout=reverse --with-nth=2 --delimiter="$PLAY_VIDEO_YOUTUBE_DIR") && pv "$(printf '%s\n' "${result[@]: 1}" | grep -oP 'https://\S+')" && INITIAL_QUERY="${result[0]}" "$0" grep
		;;

	"menu")
		videos_file="$(LAUNCHER="$0" FZF_DEFAULT_COMMAND="$0"' list' fzf --preview "cat {}" --preview-window="down:wrap" --with-nth=-2,-1 --delimiter=/ --bind 'ctrl-u:reload(tmux display-message updating && "$LAUNCHER" update_feed_from_fzf {} && $FZF_DEFAULT_COMMAND),ctrl-n:execute(read -p "Username? " username && read -p "Channel ID? " channel_id && "$LAUNCHER" update_feed "$username" "$channel_id")+reload($FZF_DEFAULT_COMMAND),ctrl-r:reload($FZF_DEFAULT_COMMAND)' --no-sort --tac --border --color 'fg:#dddddd,bg:#020502,fg+:#000000,bg+:#55aa55,hl+:#006600,preview-fg:#aaeeaa,preview-bg:#050505,border:#aaffaa,header:#99ff99' --header='ctrl+n: add new feed / ctrl+u: update selected feed / ctrl+r: reload results / ESC: exit' --query "'videos '.by_title !^si")"

		error_code=$?
		(( $error_code > 0 )) && error_msg $error_code "Error while selecting file" && exit $error_code
		PLAY_VIDEO_SOURCE="${videos_file}" play_video && "$0"
		;;

	"menu2")
		ACTION='PLAY_VIDEO_SOURCE="{}" play_video' LAUNCHER="$0" FZF_DEFAULT_COMMAND="$0 list" fzf --preview "cat {}" --preview-window="down:wrap" --with-nth=-2,-1 --delimiter=/ --bind 'enter:execute-silent($ACTION),double-click:execute-silent($ACTION),ctrl-u:reload(tmux display-message updating && "$LAUNCHER" update_feed_from_fzf {} && $FZF_DEFAULT_COMMAND),ctrl-n:execute(read -p "Username? " username && read -p "Channel ID? " channel_id && "$LAUNCHER" update_feed "$username" "$channel_id")+reload($FZF_DEFAULT_COMMAND),ctrl-r:reload($FZF_DEFAULT_COMMAND)' --no-sort --tac --border --color 'fg:#dddddd,bg:#020502,fg+:#000000,bg+:#55aa55,hl+:#006600,preview-fg:#aaeeaa,preview-bg:#050505,border:#aaffaa,header:#99ff99' --header='ctrl+n: add new feed / ctrl+u: update selected feed / ctrl+r: reload results / ESC: exit' --query "'videos '.by_title"
		;;

	"")
		"$0" menu
		;;
	*)
		echo "Unknown command: '$cmd'"
		;;

esac
