#!/usr/bin/env bash
# (C) 2021, Filip H.F. "FiXato" Slagter, contact.fixato.org
TWITCH_CLIENT_ID=${TWITCH_CLIENT_ID:-kimne78kx3ncx6brgo4mv6wki5h1ko} # Not mine, found it on https://thomassen.sh/twitch-api-endpoints/

function script_real_path() {
	echo "$(readlink -f "$0")"
}

function path_to_script() {
	echo "$(dirname "$(script_real_path)")"
}

function debug_prefix() {
	[[ ${DEBUG:-""} != "" ]] && echo "[$(script_real_path)] " || echo ""
}

function capture_video_title() {
	video_title="$($(path_to_script)/get_title_from_url.sh "$1")"
	error_code=$?
	(( $error_code > 0 )) && echo "$(debug_prefix)[$error_code] Error retrieving title for '$1'" >&2 && exit $error_code
	echo "$video_title"
}

function html2utf8 {
	hash recode > /dev/null 2>&1 && (echo "$1" | recode html..utf8 2>/dev/null || echo "Error recoding: $1") || echo "$1"
}

function curl_twitch {
	curl --location --silent --show-error -H 'Accept: application/vnd.twitchtv.v5+json' -H "Client-ID: ${TWITCH_CLIENT_ID}" "$@"
}

function add_most_recent_youtube_videos_for_user_to_history_file {
	# TODO: get channel id for username
	curl --silent https://www.youtube.com/feeds/videos.xml?channel_id="$(curl --silent https://yewtu.be/channel/$1 | pup 'input[name="q"] attr{value}' | grep -oP 'channel:\K(\S+)')" | pup 'link[href^="https://www.youtube.com/watch"] attr{href}' | xargs -I {} bash -c 'echo "$0 # $(./get_title_from_url.sh $0)"' {} > ~/.config/play_video_subscriptions-$1.log
}
