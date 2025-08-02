require 'json'
require 'net/http'
require 'uri'

# ENV inputs
GITHUB_TOKEN = ENV['GITHUB_TOKEN']
REPO = ENV['GITHUB_REPOSITORY']
EVENT_PATH = ENV['GITHUB_EVENT_PATH']

# Read GitHub event payload
event = JSON.parse(File.read(EVENT_PATH))
comment_body = event.dig('comment', 'body')&.strip
comment_id = event.dig('comment', 'id')
issue_number = event.dig('issue', 'number')

unless comment_body&.start_with?('/cutover')
  puts "No cutover command found in comment."
  exit 0
end

# Extract SNOW-ID from `/cutover <SNOW-ID>`
matches = comment_body.match(/^\/cutover\s+(\S+)/)

unless matches
  # Error message for invalid format
  message = <<~MSG
    ❌ You have used an invalid cutover command format: `#{comment_body}`

    ✅ **Expected format:** `/cutover <SNOW-ID>` (e.g., `/cutover INC1234567`)
  MSG

  puts message

  # React with ❌
  reaction_uri = URI("https://api.github.com/repos/#{REPO}/issues/comments/#{comment_id}/reactions")
  reaction_req = Net::HTTP::Post.new(reaction_uri)
  reaction_req['Authorization'] = "Bearer #{GITHUB_TOKEN}"
  reaction_req['Accept'] = "application/vnd.github.squirrel-girl-preview+json"
  reaction_req.body = { content: "x" }.to_json

  Net::HTTP.start(reaction_uri.hostname, reaction_uri.port, use_ssl: true) do |http|
    http.request(reaction_req)
  end

  # Post a comment with format guidance
  comment_uri = URI("https://api.github.com/repos/#{REPO}/issues/#{issue_number}/comments")
  comment_req = Net::HTTP::Post.new(comment_uri)
  comment_req['Authorization'] = "Bearer #{GITHUB_TOKEN}"
  comment_req['Accept'] = 'application/vnd.github+json'
  comment_req.body = { body: message }.to_json

  Net::HTTP.start(comment_uri.hostname, comment_uri.port, use_ssl: true) do |http|
    http.request(comment_req)
  end

  exit 1
end

snow_id = matches[1]
puts "Cutover requested with SNOW-ID: #{snow_id}"

# Define label color
label_color = '002b36'  # Dark blue (without the '#')

# Try to create the label first (idempotent)
create_label_uri = URI("https://api.github.com/repos/#{REPO}/labels")
create_label_req = Net::HTTP::Post.new(create_label_uri)
create_label_req['Authorization'] = "Bearer #{GITHUB_TOKEN}"
create_label_req['Accept'] = 'application/vnd.github+json'
create_label_req.body = {
  name: snow_id,
  color: label_color,
  description: "SNOW-ID Label"
}.to_json

create_res = Net::HTTP.start(create_label_uri.hostname, create_label_uri.port, use_ssl: true) do |http|
  http.request(create_label_req)
end

if create_res.code.to_i == 422
  puts "Label '#{snow_id}' already exists."
elsif create_res.code.to_i.between?(200, 299)
  puts "Label '#{snow_id}' created with color ##{label_color}"
else
  puts "Failed to create label. Response: #{create_res.code} - #{create_res.body}"
  exit 1
end

# Add the label to the issue
label_uri = URI("https://api.github.com/repos/#{REPO}/issues/#{issue_number}/labels")
label_req = Net::HTTP::Post.new(label_uri)
label_req['Authorization'] = "Bearer #{GITHUB_TOKEN}"
label_req['Accept'] = 'application/vnd.github+json'
label_req.body = { labels: [snow_id] }.to_json

res = Net::HTTP.start(label_uri.hostname, label_uri.port, use_ssl: true) do |http|
  http.request(label_req)
end

if res.code.to_i.between?(200, 299)
  puts "✅ Label '#{snow_id}' added successfully to issue ##{issue_number}"
else
  puts "❌ Failed to add label. Response: #{res.code} - #{res.body}"
  exit 1
end
