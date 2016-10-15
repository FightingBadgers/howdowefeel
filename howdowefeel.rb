require 'rubygems'
require 'twitter'
require 'csv'
require_relative 'lib/sentimental'

def process_tweet(analyzer, tweet, topics)
  if tweet.is_a?(Twitter::Tweet)
    begin
      # Let's filter out the bandwagon and ignore retweets.
      if !tweet.retweet?
        prefix = topics.empty? ? Date.today : "#{Date.today}_#{topics.join('-')}"
        CSV.open("#{prefix}_sentiments.csv", "a") do |csv|
          csv << [
            Time.now.to_s,
            analyzer.score(tweet.text),
            analyzer.sentiment(tweet.text),
            tweet.text
          ]
        end

        puts 'Tweet processed'
      end
    rescue Twitter::Error::TooManyRequests => error
      # Handle Twitter rate limiting.
      sleep error.rate_limit.reset_in + 1
      retry
    end
  end
end

##
# Change these values with your keys and access tokens to connect to the Twitter API.
stream_client = Twitter::Streaming::Client.new do |config|
  config.consumer_key        = [YOUR_CONSUMER_KEY]
  config.consumer_secret     = [YOUR_CONSUMER_SECRET]
  config.access_token        = [YOUR_ACCESS_TOKEN]
  config.access_token_secret = [YOUR_ACCESS_TOKEN_SECRET]
end

##
# Set up the sentiment analysis library.
analyzer = Sentimental.new
analyzer.load_defaults

##
# Get list of topics to search for in the Twiter stream from command line arguments.
# USAGE: ruby twitter.rb topic1 topic2 etc.
topics = ARGV[0..ARGV.size - 1]

if topics.empty?
  # No topic given, just take random samples from Twitter stream.
  stream_client.sample do |tweet|
    process_tweet(analyzer, tweet, topics)
  end
else
  # Join topics and use as filter for Twitter stream.
  stream_client.filter(track: topics.join(',')) do |tweet|
    process_tweet(analyzer, tweet, topics)
  end
end
