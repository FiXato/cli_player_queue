#!/usr/bin/env bash
# (C) 2021, Filip H.F. "FiXato" Slagter, contact.fixato.org
set -o nounset -o pipefail
INVIDIOUS_INSTANCE_URL=${INVIDIOUS_INSTANCE_URL:-https://yewtu.be}
url="${1:-""}"
[[ "$url" == "" ]] && echo "Please specify the media URL as first parameter" && exit 1
video_id="$(echo $url | grep -oP 'v=\K([^&? ]+)')"
error_code=$?
function html2utf8 {
	hash recode > /dev/null 2>&1 && (echo "$1" | recode html..utf8 2>/dev/null || echo "Error recoding: $1") || echo "$1"
}
if (( $error_code == 0 )); then
	html_source="$(curl --silent "${INVIDIOUS_INSTANCE_URL}/watch?v=${video_id}")" # proxy through an Invidious instance to avoid Google's bot detection, captchas and tracking
	#TODO: add error checking
	video_title="$(echo "$html_source" | grep -oP '<title>\K([^<]+)' | sed 's/ - Invidious$//')"
	channel_name="$(echo "$html_source" | grep -oP '<span id="channel-name">\K[^<]+')"
	output_title="$channel_name -  $video_title"
	output_title="$(html2utf8 "$output_title")"
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
