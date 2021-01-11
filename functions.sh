#!/usr/bin/env bash
# (C) 2021, Filip H.F. "FiXato" Slagter, contact.fixato.org
TWITCH_CLIENT_ID=${TWITCH_CLIENT_ID:-kimne78kx3ncx6brgo4mv6wki5h1ko} # Not mine, found it on https://thomassen.sh/twitch-api-endpoints/
JQ_YOUTUBE_TITLE_FORMAT='\(.link) # 📅\(.publishedParsed) - \(.author.name) - \(.title)'
PLAY_VIDEO_CONFIG_DIR="${PLAY_VIDEO_CONFIG_DIR:-"${XDG_CONFIG_HOME:-"${HOME}/.config"}/play_video"}"
PLAY_VIDEO_YOUTUBE_DIR="$PLAY_VIDEO_CONFIG_DIR/youtube"
PLAY_VIDEO_HISTORY_FILE=${PLAY_VIDEO_HISTORY_FILE:-$PLAY_VIDEO_CONFIG_DIR/play_video_history.log}

[ ! -f "$PLAY_VIDEO_CONFIG_DIR" ] && mkdir -p "$PLAY_VIDEO_CONFIG_DIR"

[ ! -f "$PLAY_VIDEO_HISTORY_FILE" ] && touch "$PLAY_VIDEO_HISTORY_FILE"

INVIDIOUS_INSTANCE_URL=${INVIDIOUS_INSTANCE_URL:-https://yewtu.be}
PLAYER="${PLAYER:-mpv --write-filename-in-watch-later-config}"

ERROR_MISSING_PARAMETER_NO=100
ERROR_MISSING_PARAMETER_MSG="You forgot to pass along a parameter: "
ERROR_RETRIEVING_TITLE_FOR_URL_MSG="Error retrieving title for URL: "
ERROR_RETRIEVING_RECENT_YOUTUBE_VIDEOS_FOR_USER_NO=101
ERROR_RETRIEVING_RECENT_YOUTUBE_VIDEOS_FOR_USER_MSG="Error retrieving recent youtube videos feed for user: "
ERROR_MERGING_YOUTUBE_VIDEO_FEEDS_FOR_USER_NO=102
ERROR_MERGING_YOUTUBE_VIDEO_FEEDS_FOR_USER_MSG="Error while trying to merge youtube video feeds for user: "
ERROR_MOVING_TEMP_FILE_NO=103
ERROR_MOVING_TEMP_FILE_MSG="Error overwriting existing file with temp file: "
ERROR_STORING_YOUTUBE_VIDEO_TITLES_NO=104
ERROR_STORING_YOUTUBE_VIDEO_TITLES_MSG="Error storing video titles from YouTube feed: "
ERROR_GETTING_YOUTUBE_DIR_FOR_USER_NO=105
ERROR_GETTING_YOUTUBE_DIR_FOR_USER_MSG="Error getting YouTube feeds dir for user: "

function script_real_path() {
	echo "$(readlink -f "$0")"
}

function path_to_script() {
	echo "$(dirname "$(script_real_path)")"
}

function debug_prefix() {
	[[ ${DEBUG:-""} != "" ]] && echo "[$(script_real_path)] " || echo ""
}

function error_msg {
	echo "$(debug_prefix)[${FUNCNAME[1]}] [$1] $2" >&2
}

function play_video {
	"$(path_to_script)/play_video.sh" $@
}

function capture_video_title() {
	url=${1:-""}
	[[ "$url" == "" ]] && error_msg $ERROR_MISSING_PARAMETER_NO "$ERROR_MISSING_PARAMETER_MSG \$1 (media url)" && exit $ERROR_MISSING_PARAMETER_NO

	video_title="$($(path_to_script)/get_title_from_url.sh "$1")"
	error_code=$?
	(( $error_code > 0 )) && error_msg $error_code "$ERROR_RETRIEVING_TITLE_FOR_URL_MSG '$1'" && exit $error_code
	printf '%s' "$video_title"
}

function html2utf8 {
	hash recode > /dev/null 2>&1 && (echo "$1" | recode html..utf8 2>/dev/null || echo "Error recoding: $1") || echo "$1"
}

function curl_twitch {
	curl --location --silent --show-error -H 'Accept: application/vnd.twitchtv.v5+json' -H "Client-ID: ${TWITCH_CLIENT_ID}" "$@"
}

function ensure_param {
	local _param_nr="${1:-""}"
	local _index=$(( $_param_nr + 2))
	local _param="${!_index}"
	local _desc="${2:-""}"

	[[ "$_param" != "" ]] && printf '%s' "$_param" || (error_msg $ERROR_MISSING_PARAMETER_NO "$ERROR_MISSING_PARAMETER_MSG \$$_param_nr ($_desc)"; exit $ERROR_MISSING_PARAMETER_NO)
}

function test_ensure_param {
	param_value="$(ensure_param 4 "param description" "$@")" || exit $?
	echo "param value: $param_value"
}

function store_channel_id_for_user {
	youtube_username="$(ensure_param 1 "youtube_username" "$@")" || exit $?
	youtube_channel_id="$(ensure_param 2 "youtube_channel_id" "$@")" || exit $?

	youtube_user_dir="$(youtube_dir_for_user "$youtube_username")" || exit $?
	channel_id_file="$youtube_user_dir/channel_id.txt"
	printf '%s' "$youtube_channel_id" > "$channel_id_file"
}

function channel_id_for_youtube_username {
	youtube_username="${1:-""}"
	[[ "$youtube_username" == "" ]] && error_msg $ERROR_MISSING_PARAMETER_NO "$ERROR_MISSING_PARAMETER_MSG \$1 (youtube_username)" && exit $ERROR_MISSING_PARAMETER_NO

	youtube_user_dir="$(youtube_dir_for_user "$youtube_username")" || exit $?
	channel_id_file="$youtube_user_dir/channel_id.txt"
	if [ -f "$channel_id_file" ]; then
		cat "$channel_id_file"
	else
		curl --silent "$INVIDIOUS_INSTANCE_URL/channel/$youtube_username" | pup 'input[name="q"] attr{value}' | grep -oP 'channel:\K(\S+)'
	fi
}

function youtube_channel_feed_url {
	youtube_username="${1:-""}"
	[[ "$youtube_username" == "" ]] && error_msg $ERROR_MISSING_PARAMETER_NO "$ERROR_MISSING_PARAMETER_MSG \$1 (youtube_username)" && exit $ERROR_MISSING_PARAMETER_NO

	printf '%s' "https://www.youtube.com/feeds/videos.xml?channel_id=$(channel_id_for_youtube_username "$youtube_username")"
}

function get_youtube_channel_feed_as_json {
	youtube_username="${1:-""}"
	[[ "$youtube_username" == "" ]] && error_msg $ERROR_MISSING_PARAMETER_NO "$ERROR_MISSING_PARAMETER_MSG \$1 (youtube_username)" && exit $ERROR_MISSING_PARAMETER_NO

	gofeed ParseURL "$(youtube_channel_feed_url "$youtube_username")"
}

function youtube_dir_for_user {
	youtube_username="${1:-""}"
	[[ "$youtube_username" == "" ]] && error_msg $ERROR_MISSING_PARAMETER_NO "$ERROR_MISSING_PARAMETER_MSG \$1 (youtube_username)" && exit $ERROR_MISSING_PARAMETER_NO

	#FIXME: filename sanitise. For now it should be safe though, as I manually enter the usernames.
	youtube_user_dir="$(printf '%s' "$PLAY_VIDEO_YOUTUBE_DIR/$youtube_username")" || (error_msg $ERROR_GETTING_YOUTUBE_DIR_FOR_USER_NO "$ERROR_GETTING_YOUTUBE_DIR_FOR_USER_MSG $youtube_username ($?)" && exit $ERROR_GETTING_YOUTUBE_DIR_FOR_USER_NO)
	[ ! -d "$youtube_user_dir" ] && (error_msg 0 "YouTube feeds dir for '$youtube_username' does not exist yet; trying to create" && mkdir -p "$youtube_user_dir" || (error_code=$? && error_msg $error_code "Error while creating YouTube feeds dir for '$youtube_username': '$youtube_user_dir'" && exit $error_code))
	printf '%s' "$youtube_user_dir"
}

function youtube_new_videos_feed_file_for_user {
	youtube_username="${1:-""}"
	[[ "$youtube_username" == "" ]] && error_msg $ERROR_MISSING_PARAMETER_NO "$ERROR_MISSING_PARAMETER_MSG \$1 (youtube_username)" && exit $ERROR_MISSING_PARAMETER_NO

	youtube_user_dir="$(youtube_dir_for_user "$youtube_username")" || exit $?
	printf '%s' "$youtube_user_dir/new.json"
}

function youtube_videos_feed_file_for_user {
	youtube_username="${1:-""}"
	[[ "$youtube_username" == "" ]] && error_msg $ERROR_MISSING_PARAMETER_NO "$ERROR_MISSING_PARAMETER_MSG \$1 (youtube_username)" && exit $ERROR_MISSING_PARAMETER_NO

	youtube_user_dir="$(youtube_dir_for_user "$youtube_username")" || exit $?
	printf '%s' "$youtube_user_dir/videos.json"
}

function youtube_new_videos_titles_file_for_user {
	youtube_username="${1:-""}"
	[[ "$youtube_username" == "" ]] && error_msg $ERROR_MISSING_PARAMETER_NO "$ERROR_MISSING_PARAMETER_MSG \$1 (youtube_username)" && exit $ERROR_MISSING_PARAMETER_NO

	youtube_user_dir="$(youtube_dir_for_user "$youtube_username")" || exit $?
	printf '%s' "$youtube_user_dir/new.txt"
}

function youtube_videos_titles_file_for_user {
	youtube_username="${1:-""}"
	[[ "$youtube_username" == "" ]] && error_msg $ERROR_MISSING_PARAMETER_NO "$ERROR_MISSING_PARAMETER_MSG \$1 (youtube_username)" && exit $ERROR_MISSING_PARAMETER_NO

	youtube_user_dir="$(youtube_dir_for_user "$youtube_username")" || exit $?
	printf '%s' "$youtube_user_dir/videos.txt"
}

function store_recent_youtube_feeds_for_user {
	youtube_username="${1:-""}"
	[[ "$youtube_username" == "" ]] && error_msg $ERROR_MISSING_PARAMETER_NO "$ERROR_MISSING_PARAMETER_MSG \$1 (youtube_username)" && exit $ERROR_MISSING_PARAMETER_NO

	new_feed_filename="$(youtube_new_videos_feed_file_for_user "$youtube_username")"
	get_youtube_channel_feed_as_json "$youtube_username" > "$new_feed_filename"
	error_code=$?
	(( $error_code > 0 )) && error_msg $ERROR_RETRIEVING_RECENT_YOUTUBE_VIDEOS_FOR_USER_NO "$ERROR_RETRIEVING_RECENT_YOUTUBE_VIDEOS_FOR_USER_MSG '$youtube_username' (process returned: $error_code)" && exit $ERROR_RETRIEVING_RECENT_YOUTUBE_VIDEOS_FOR_USER_NO

	feed_filename="$(youtube_videos_feed_file_for_user "$youtube_username")"
	[ ! -f "$feed_filename" ] && echo '{}' > "$feed_filename" && error_msg 0 "'$feed_filename' did not exist, so an empty one has been created" >&2
	temp_feed_filename="$(youtube_videos_feed_file_for_user "$youtube_username").temp"
	merge_youtube_feed_files "$new_feed_filename" "$feed_filename" > "$temp_feed_filename"
	error_code=$?
	(( $error_code > 0 )) && error_msg $ERROR_MERGING_YOUTUBE_VIDEO_FEEDS_FOR_USER_NO "$ERROR_MERGING_YOUTUBE_VIDEO_FEEDS_FOR_USER_MSG '$youtube_username' ($new_feed_filename + $feed_filename >  $temp_feed_filename) (process returned: $error_code)" && exit $ERROR_MERGING_YOUTUBE_VIDEO_FEEDS_FOR_USER_NO

	mv "$temp_feed_filename" "$feed_filename"
	error_code=$?
	(( $error_code > 0 )) && error_msg $ERROR_MOVING_TEMP_FILE_NO "$ERROR_MOVING_TEMP_FILE_MSG ("$temp_feed_filename" -> "$feed_filename") (process returned: $error_code)" && exit $ERROR_MOVING_TEMP_FILE_NO
	echo "Stored feed at $feed_filename" >&2
}

function store_youtube_video_titles {
	output_title_file="${2//.txt*/.by_title.txt}"
	output_date_file="${2//.txt*/.by_date.txt}"
	jq -r -L ./ 'include "functions"; sort_youtube_rss_by_title | title_format' "$1" > "$output_title_file" && \
		echo "Exported video titles from '$1' to '$output_title_file'" >&2 && \
		jq -r -L ./ 'include "functions"; sort_youtube_rss_by_published | title_format' "$1" > "$output_date_file" && \
		echo "Exported video titles from '$1' to '$output_date_file'" >&2
}

function store_recent_youtube_video_titles_for_user {
	youtube_username="${1:-""}"
	[[ "$youtube_username" == "" ]] && error_msg $ERROR_MISSING_PARAMETER_NO "$ERROR_MISSING_PARAMETER_MSG \$1 (youtube_username)" && exit $ERROR_MISSING_PARAMETER_NO
	echo "${FUNCNAME[0]}($youtube_username)" >&2


	store_recent_youtube_feeds_for_user "$youtube_username"
	input="$(youtube_videos_feed_file_for_user "$youtube_username")"
	output="$(youtube_videos_titles_file_for_user "$youtube_username")"
	store_youtube_video_titles "$input" "$output"
	error_code=$?
	(( $error_code > 0 )) && error_msg $ERROR_STORING_YOUTUBE_VIDEO_TITLES_NO "$ERROR_STORING_YOUTUBE_VIDEO_TITLES_MSG '$input' > '$output') (process returned: $error_code)" && exit $ERROR_STORING_YOUTUBE_VIDEO_TITLES_NO

	input="$(youtube_new_videos_feed_file_for_user "$youtube_username")"
	output="$(youtube_new_videos_titles_file_for_user "$youtube_username")"
	store_youtube_video_titles "$input" "$output"
	error_code=$?
	(( $error_code > 0 )) && error_msg $ERROR_STORING_YOUTUBE_VIDEO_TITLES_NO "$ERROR_STORING_YOUTUBE_VIDEO_TITLES_MSG '$input' > '$output') (process returned: $error_code)" && exit $ERROR_STORING_YOUTUBE_VIDEO_TITLES_NO
	echo "Exported video titles from '$input' to '$output'" >&2
}


function merge_json_files {
	jq -s '.[0] * .[1]' "$1" "$2"
}

function merge_youtube_feed_files {
	jq -s '.[0].items += .[1].items | .[0] | .items |= unique_by(.link)' "$1" "$2"
}
#sort_by_title
#jq -s '.[0] * .[1]' kikoskia.rss.*.json  | jq -r '.items|sort_by(.title)[] | "\(.link) # 📅\(.publishedParsed) - \(.author.name) - \(.title)"'
# MPV_SELECTION="$(cat kikoskia.rss.merged.20210109.json | jq -r '.items|sort_by(.title)[] | "\(.link) # 📅\(.publishedParsed) - \(.author.name) - \(.title)"' | fzf --no-sort --tac)" && pv ${MPV_SELECTION%% *}
#cat "$(grep -l ${MPV_SELECTION%% *} /mnt/c/Users/FiXato/scoop/apps/mpv-git/current/portable_config/watch_later/*)"
