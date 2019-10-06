require "nokogiri"
require "open-uri"
require "csv"

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

	def to_h
		Hash[self.titles.zip(self.urls)]
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
	end

	def get
		feeds = Array.new
		self.to_h.keys.each do |title|
			feeds << Feed.new(self.to_h[title]).to_h
		end
		feeds
	end
	def newfeeds (oldfeeds)
		feeds = self.get
		@newfeeds = Array.new
		for ii in 0..feeds.length-1
			var = feeds[ii].keys - oldfeeds[ii].keys
			@newfeeds[ii] = unless var == []
				Hash[var.zip(feeds[ii].values_at(*var))]
			else
				[]
			end
		end
		@newfeeds
	end
end

feeds = FeedChecker.new('/home/ming/Projects/RSSrb/feeds.tsv')
mangled = feeds.get
mangled[0] = mangled[0].to_a[1..mangled[0].length-1].to_h
mangled[1] = mangled[1].to_a[1..mangled[1 ].length-1].to_h
puts feeds.newfeeds(mangled)