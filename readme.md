# rss-kindle-ruby

Personal project for parsing web serial content and sending to kindle.

## Dependencies:
### gems
* nokogiri
* open-uri
* mail

### external programs
* calibre

# Using this script

* Edit feeds.tsv for your preferred feeds. Note that the name you add in the field to the tsv is cosmetic only - feed will reference its name as assigned by feed creator for most things.
* You may need to write custom classes in rss_checker.rb for parsing webpage content - will default to loading entire page
* run rss_checker.rb