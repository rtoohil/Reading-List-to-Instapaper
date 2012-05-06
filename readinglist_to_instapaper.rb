#!/usr/bin/env ruby

require 'rubygems'
require 'net/https'
require 'uri'
require 'ruby_gntp'
require 'nokogiri-plist'
require 'date'

# Our last run
# Setting this to epoch time in case this is our first time
# or we don't have a last run file
lastrun = Time.at(0).to_s

# Our last run file
# Store it on dropbox if you want to have it sync across computers
lastrun_file = "~/.readinglist_instapaper_run"

# If our timestamp file exists, read it in
if (File.exists? File.expand_path(lastrun_file)) 
  lastrun = File.open(File.expand_path(lastrun_file), 'rb').read
end

# The real last run, which will either be epoch time
# or the content of the last run file
lastrun_dt = DateTime.parse(lastrun)

# Instapaper API stuff
instapaper = 'www.instapaper.com'
insta_user = 'YOUR_INSTAPAPER_USER'
insta_pass = 'YOUR_INSTAPAPER_PASS'

# My Array of Links to send to Instapaper
links = Array.new

# Open the binary Bookmarks plist and convert to xml, read it in
input = %x[/usr/bin/plutil -convert xml1 -o - ~/Library/Safari/Bookmarks.plist]

# Let's parse the plist and find the elements we care about
# There's probably a better way to do this, but I'm stupid at Ruby
# This also seems ripe for refactoring, but I'm lazy
plist = Nokogiri::PList(input)

if plist.include? 'Children'
  plist['Children'].each do |child|
    child.keys.each do |ck|
      if child[ck].is_a? Array
        child[ck].each do |list|
          if list.include? 'ReadingList'
            datefetched = list['ReadingList']['DateLastFetched']
            if (datefetched > lastrun_dt) 
              links << URI::escape(list['URLString'])
            end
          end
        end
      end
    end
  end
end



# Let's loop through our links and add them to instapaper
links.each do |url|
  http = Net::HTTP.new(instapaper, 443)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_PEER
  query_string = "/api/add?url=#{url}"
  request = Net::HTTP::Get.new(query_string)
  request.basic_auth(insta_user, insta_pass)
  response = http.request(request)

  # Throw up a growl message 
  # The icon stuff doesn't work. Not sure why yet
  if ( response.code == '201' )
    GNTP.notify({
      :app_name => "Instapaper",
      :title    => "Added to Instapaper", 
      :text     => "Successfully added #{url}",
      :icon     => "http://www.instapaper.com/apple-touch-icon.png",
    })
  else
    GNTP.notify({
      :app_name => "Instapaper",
      :title    => "Error Adding to Instapaper", 
      :text     => "Could not add #{url}",
      :icon     => "http://www.instapaper.com/apple-touch-icon.png",
    })
  end 
end

# Let's write our successful run out
# Only write out when we have links, so that we don't save a file every
# time a bookmark changes
if ( links.length > 0 ) 
  File.open(File.expand_path(lastrun_file), 'w') {|f| f.write(DateTime.now.to_s) }
end
