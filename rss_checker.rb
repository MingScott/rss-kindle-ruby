require "nokogiri"
require "open-uri"
require "csv"
require "ostruct"

class Feed
	def initialize(url)
		@doc = Nokogiri::XML(open(url)).css("channel").first
	end

	def name
		@doc.css("title").first.content
	end

	def item
		@doc.css("item")
	end

	def titles
		titles = Array.new
		self.item.css("title").each { |title| titles << title.content }
		titles
	end

	def urls
		links = Array.new
		self.item.css("link").each { |link| links << link.content }
		links
	end

	def dates
		dates = Array.new
		self.item.css("pubDate").each { |date| dates << date.content }
	end

	def to_h
		Hash[self.titles.zip(self.urls)]
	end

	def to_struct
		feed_struct = Struct.new(:titles,:urls, :dates, :name)
		feed_struct.new(self.titles, self.urls, self.dates, self.name)
	end
end

class Chapter
	def initialize(url)
		@doc = Nokogiri::HTML(open(url))
	end
	def to_s
		puts @doc.to_s
	end
	def doc
		@doc
	end
end

class PgteChapter < Chapter
	def title
		@doc.css('h1.entry-title').first.content
	end
	def text
		@doc.css('div.entry-content').first.css('p')
	end
end

class WardChapter < Chapter
	def title
		@doc.css('h1.entry-title').first.content
	end

	def text
		content = @doc.css('div.entry-content').first.css('p')
		content[1..content.length-2]
	end
end

class RRChapter < Chapter
	def title
		@doc.css('h1').first.content
	end
	def text
		chapter = @doc.css("div.chapter-inner.chapter-content").first
		chapter_content = chapter.to_s
		chapter.css("table").each { |table| chapter_content = chapter_content.gsub(table.to_s,table.css("p").to_s) }
		Nokogiri::HTML(chapter_content)
	end
end

class FeedList
	def initialize(tsv)
		@feeds = CSV.read(tsv, { :col_sep => "\t" })
	end
	def to_h
		@feeds.to_h
	end
	def to_a
		@feeds
	end
end

feedlist = FeedList.new('/home/ming/Projects/RSSrb/feeds.tsv').to_h

class FeedChecker < FeedList
	def initialize(tsv)
		@feeds = CSV.read(tsv, { :col_sep => "\t" })
		@feed_struct = Struct.new(:titles,:urls,:name)
	end

	def get
		feeds = Array.new
		self.to_h.keys.each do |title|
			feeds << Feed.new(self.to_h[title]).to_struct
		end
		feeds
	end
	def newfeeds (oldfeeds)
		feeds = self.get
		@newfeeds = Array.new
		for ii in 0..feeds.length-1
			url = feeds[ii].urls  - oldfeeds[ii].urls
			title = feeds[ii].titles - oldfeeds[ii].titles
			@newfeeds[ii] = unless url == []
				@feed_struct.new(title,url,feeds[ii].name)
			else
				[]
			end
		end
		@newfeeds
	end
end

feeds = FeedChecker.new('/home/ming/Projects/RSSrb/feeds.tsv')
mangled = feeds.get
mangled[0]["titles"] = mangled[0]["titles"][1..mangled[0]["titles"].length-1]
mangled[0]["urls"] = mangled[0]["urls"][1..mangled[0]["urls"].length-1]
puts feeds.newfeeds(mangled)[0]["titles"]

