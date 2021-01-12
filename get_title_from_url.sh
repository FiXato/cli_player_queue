#!/usr/bin/env bash
# (C) 2021, Filip H.F. "FiXato" Slagter, contact.fixato.org
set -o nounset -o pipefail
url="${1:-""}"
[[ "$url" == "" ]] && echo "Please specify the media URL as first parameter" && exit 1

. "$(dirname "$(readlink -f "$0")")/functions.sh"

# SAVEME: jq query for returning either the current stream title, or the last video title:
# title="$(echo "$json" | jq -r '.data.user as $user | if $user.stream != null then ($user.stream | "[\(.type)] \($user.displayName) - \(.title) [\(.game.name)]") elif $user.videos != null then ($user.videos.edges[0].node | "\($user.displayName) - \(.title) [\(.game.name)] - \(.createdAt) - 🆔\(.id)") else "" end')"

if [[ "$url" == https://twitch.tv* ]] || [[ "$url" == https://www.twitch.tv* ]]; then
	video_id="$(echo $url | grep -oP '/videos/\K[0-9]+')"
	error_code=$?
	if (( $error_code == 0 )); then
		curl_twitch "https://api.twitch.tv/kraken/videos/${video_id}" | jq '"\(.channel.display_name) \(.title) [\(.game)] - \(.recorded_at)"' && exit 0
	else
		channel="$(echo $url | grep -oP '/\K[^/]+$')"
		error_code=$?
		if (( $error_code == 0 )); then
			json="$(curl_twitch --request POST --data "$(echo '{}' | jq --rawfile query query.gql '{"query": $query}' | sed 's/$username/'$channel'/')" https://gql.twitch.tv/gql | jq '.')"
			stream_title="$(echo "$json" | jq -r '.data.user as $user | if $user.stream != null then ($user.stream | "[\(.type)] \($user.displayName) - \(.title) [\(.game.name)]") else "" end')"
			[[ "$stream_title" == "" ]] && echo "$(debug_prefix)[3] Stream for $channel is offline" >&2 && exit 3 #Not Live
			echo "$stream_title"
			#curl --location --silent --show-error -H 'Accept: application/vnd.twitchtv.v5+json' "https://api.twitch.tv/kraken/channels/${channel_id}/videos?client_id=${TWITCH_CLIENT_ID}" | jq '.' && exit 0 #'"\(.channel.display_name) [\(.game)] \(.title) - \(.recorded_at)"' && exit 0
		else
			echo "Unsupported Twitch URL, for now" && exit 2
		fi
	fi
else
	video_id="$(echo $url | grep -oP 'v=\K([^&? ]+)')"
	error_code=$?
	if (( $error_code == 0 )); then
		html_source="$(curl -A "Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/81.0" -H "Content-Type: text/html; charset=utf-8" --silent "${INVIDIOUS_INSTANCE_URL}/watch?v=${video_id}")" # proxy through an Invidious instance to avoid Google's bot detection, captchas and tracking
		#TODO: add error checking
		video_title="$(echo "$html_source" | grep -oP '<title>\K([^<]+)' | sed 's/ - Invidious$//')"
		channel_name="$(echo "$html_source" | grep -oP '<span id="channel-name">\K[^<]+')"
		output_title="$channel_name -  $video_title"
		#output_title="$(html2utf8 "$output_title")"
	else
		html="$(curl --location --silent "$1")"
		error_code=$?
		if (( $error_code == 0 )); then
			html_title="$(echo "$html" | grep -oP '<title>\K([^<]+)')"
			error_code=$?
			(( $error_code == 0 )) && html_title="$(html2utf8 "$html_title")"
	  fi
		if (( $error_code == 0 )); then
			output_title="$html_title"
		else
			echo "UNKNOWN TITLE" && exit 1
		fi
	fi
	echo "$output_title"
fi
