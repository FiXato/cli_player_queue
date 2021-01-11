def title_format:
	. | "\(.link) # 📅\(.publishedParsed) - \(.author.name) - \(.title)";

def sort_youtube_rss_by(key):
	.items|sort_by(key)[];

def sort_youtube_rss_by_title:
  . | sort_youtube_rss_by(.title);

def sort_youtube_rss_by_published:
  . | sort_youtube_rss_by(.publishedParsed);
