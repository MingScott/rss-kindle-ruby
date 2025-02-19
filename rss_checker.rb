#!/usr/bin/ruby

require "nokogiri"
require "open-uri"
require "csv"
require "json"
require "pp"
require "pathname"
require "fileutils"
require "mail"

class ChapterHandler
	def initialize(urls, names)
		@chaps = Array.new
		if not urls.empty?
			for ii in 0..urls.length-1
				link = urls[ii]
				sname = names[ii]
				if link.include?("practicalguidetoevil")
					@chaps << PgteChapter.new(link, sname)
				elsif link.include?("royalroad")
					@chaps << RRChapter.new(link, sname)
				elsif link.include?("parahumans")
					@chaps << WardChapter.new(link, sname)
				else
					@chaps << Chapter.new(link, sname)
				end
			end

		end
	end
	def titles
		out = Array.new
		@chaps.each {|chap| out << chap.title }
		out
	end
	def names
		out = Array.new
		@chaps.each {|chap| out << chap.name }
		out
	end
	def texts
		out = Array.new
		@chaps.each {|chap| out << chap.text }
		out
	end
	def writeall
		@chaps.each {|chap| chap.write }
	end
	def convertall
		@chaps.each { |chap| chap.convert }
	end
	def kindleall
		@chaps.each { |chap| chap.kindle }
	end # Add any new chapter classes for parsing new webpages to the logic here #edit the control flow in here if you make custom classes
end

class Chapter
	def initialize(url, name)
		@doc = Nokogiri::HTML(open(url))
		@name = name
	end
	def to_s
		puts @doc.to_s
	end
	def doc
		@doc
	end
	def name
		@name
	end
	def title
		@doc.css('h1').first.content
	end
	def author
		"Unknown"
	end
	def text
		@doc
	end
	def cleantitle
		(self.name + "_" + self.title).gsub(/\u00A0/, ' ').gsub(/\u2013/, '-').gsub(' ','_').gsub(':','_')
	end
	def write
		text = "<h2>" + self.name + "</h2>\n"
		text << "<i>" + Time.now.inspect + "</i>\n"
		text << "<h1>" + self.title + "</h1>\n"
		text << self.text.to_s
		File.new('data/html/' + self.cleantitle + '.html', 'w').syswrite text
	end
	def convert
		title = self.cleantitle
		`ebook-convert "data/html/#{title}.html" "data/mobi/#{title}.mobi" --title "#{@name + ": " + self.title}"  --authors "#{self.author}"`
	end
	def kindle
		title = self.cleantitle
		if File.exist?('data/mobi/' + title + '.mobi')
			KindleEmail.new.send_file('data/mobi/' + title + '.mobi')
		else
			puts "nope"
		end
	end
end

### Custom chapter handler classes

class PgteChapter < Chapter
	def title
		@doc.css('h1.entry-title').first.content
	end
	def text
		@doc.css('div.entry-content').first.css('p')
	end
	def author
		"ErraticErrata"
	end
end

class WardChapter < Chapter
	def title
		@doc.css('h1.entry-title').first.content
	end

	def text
		content = @doc.css('div.entry-content').first.css('p')
		content[1..content.length-1]
	end

	def author
		"Wildbow"
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

###

class KindleEmail
	def send_file(fname)
		gmx_options = { :address              => "mail.gmx.com",
                :port                 => 587,
                :user_name            => File.read('uname.txt'),
                :password             => File.read('password.txt'),
                :authentication       => 'plain',
                :enable_starttls_auto => true  }

		Mail.defaults do
			delivery_method :smtp, gmx_options
		end

		Mail.deliver do
		  to File.read('kindle_email.txt')
		  from File.read('uname.txt')
		  subject ' '
		  add_file fname
		end
	end
end

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
		dates
	end

	def to_a
		namearr = Array.new
		for ii in 0..self.titles.length-1
			namearr[ii] = self.name
		end
		arr = [self.titles, self.urls, self.dates, namearr]
		newarr = Array.new(self.titles.length) { Array.new(arr.length,0) }
		for x in 0..newarr.length-1
			for y in 0..arr.length-1
				newarr[x][y] = arr[y][x]
			end
		end
		newarr
	end

	def store(path)
		File.open(path,"w") do |f|
			f.write JSON.pretty_generate(self.to_a)
			f.close
		end
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

class FeedChecker < FeedList
	def initialize(tsv)
		@feeds = CSV.read(tsv, { :col_sep => "\t" })
		@feedarray = Array.new
		for ii in 0..@feeds.length-1
			@feedarray[ii] = Feed.new(@feeds[ii][1]).to_a
		end
	end
	def newfeeds (oldfeeds)
		newfeeds = Array.new
		for ii in 0..@feedarray.length-1
			newfeeds << @feedarray[ii] - oldfeeds[ii]
		end
		newfeeds
	end
	def to_a
		@feedarray
	end
	def to_h
		raise ArgumentError.new ("can't hash this, baby")
	end
	def store(path)
		File.open(path,"w") do |f|
			f.write JSON.pretty_generate(self.to_a)
			f.close
		end
	end
	def check(path)
		self.newfeeds(get_json(path))
	end
	def check_get_flat_urls(path)
		FlatFeedArray.new(self.check(path)).urls
	end
	def check_get_flat_names(path)
		FlatFeedArray.new(self.check(path)).names
	end
end

def get_json(path)
	JSON.parse(File.read(path))
end

def store_json(path, obj)
	File.open(path,"w") do |f|
		f.write JSON.pretty_generate(obj)
		f.close
	end
end

class FlatFeedArray
	def initialize(arr)
		@flatarray = Array.new(4){Array.new}
		for ii in 0..3
			arr.each do |x|
				x.each do |y|
					@flatarray[ii] << y[ii]
				end
			end
		end
	end
	def titles
		@flatarray[0]
	end
	def urls
		@flatarray[1]
	end
	def dates
		@flatarray[2]
	end
	def names
		@flatarray[3]
	end
	def to_a
		@flatarray
	end
end

def main
	puts "Initializing..."
	unless Pathname.new("data/html").exist? && Pathname.new("data/mobi").exist?
		puts "Building data directories..."
		FileUtils.mkdir_p "data/html"
		FileUtils.mkdir_p "data/mobi"
	end
	puts "====Feeds====="
	FeedList.new("feeds.tsv").to_a.each do |feed|
		puts feed
		puts ""
	end
	puts "=============="
	while true
		unless Pathname.new("feed_data.json").exist?
			FeedChecker.new("feeds.tsv").store("feed_data.json")
			puts "No pre-existing stored feeds, refreshing..."
		end
		if get_json("feed_data.json").length != FeedChecker.new("feeds.tsv").to_a.length
			FeedChecker.new("feeds.tsv").store("feed_data.json")
			puts "Length of stored feeds does not match list of feeds, refreshing..."
		end

		feeddat = FeedChecker.new("feeds.tsv")
		urls = feeddat.check_get_flat_urls("feed_data.json")
		names = feeddat.check_get_flat_names("feed_data.json")
		unless urls.empty?
			newchaps = ChapterHandler.new(urls,names)
			feeddat.store("feed_data.json")
			output = "------\n"
			output << Time.now.inspect + "\n"
			for ii in 0..newchaps.titles.length-1
            	output << newchaps.names[ii] + " - " + newchaps.titles[ii] + "\n"
            end
			output << "------\n"
			puts output
			newchaps.writeall
			puts "Writing..."
			newchaps.convertall
			puts "Converting..."
			newchaps.kindleall
			puts "Sending to kindle..."
			puts "Done."
			puts "======"
		end
		sleep 120
	end
end

main