require 'json'
require 'net/http'
require 'uri'
require 'optparse'
require 'base64'

puts "[DEBUG] Script started"

# Parse CLI options
options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: cutover.rb [options]"

  opts.on("--comment COMMENT", "Base64-encoded comment string") { |v| options[:comment] = v }
  opts.on("--body BODY", "Base64-encoded body string") { |v| options[:body] = v }
  opts.on("--issue-id ID", "Issue ID number") { |v| options[:issue_id] = v }
  opts.on("--real", "Force real GitHub API calls in local mode") { options[:real] = true }
end.parse!

# Determine mode
local_inputs = options[:comment] && options[:body] && options[:issue_id]
local_mode = local_inputs && !options[:real]

# Setup vars
if local_mode
  puts "[DEBUG] Running in local mode"
  comment_body = Base64.decode64(options[:comment]).strip
  comment_id = 123456789
  issue_number = options[:issue_id].to_i
  repo = ENV['GITHUB_REPOSITORY'] || 'dummy-org/dummy-repo'
  github_token = ENV['GITHUB_TOKEN'] || 'no-token-used'
elsif local_inputs && options[:real]
  puts "[DEBUG] Running in real mode with CLI inputs"
  comment_body = Base64.decode64(options[:comment]).strip
  comment_id = 123456789
  issue_number = options[:issue_id].to_i
  repo = ENV['GITHUB_REPOSITORY'] or abort("❌ GITHUB_REPOSITORY is required")
  github_token = ENV['GITHUB_TOKEN'] or abort("❌ GITHUB_TOKEN is required")
else
  puts "[DEBUG] Running in GitHub Actions mode"
  github_token = ENV['GITHUB_TOKEN']
  repo = ENV['GITHUB_REPOSITORY']
  event_path = ENV['GITHUB_EVENT_PATH']

  unless github_token && repo && event_path && File.exist?(event_path)
    abort("❌ Missing GitHub environment variables or event file.")
  end

  event = JSON.parse(File.read(event_path))
  comment_body = event.dig('comment', 'body')&.strip
  comment_id = event.dig('comment', 'id')
  issue_number = event.dig('issue', 'number')
end

puts "[DEBUG] Decoded comment body: #{comment_body}"
puts "[DEBUG] Issue number: #{issue_number}"
puts "[DEBUG] Comment ID: #{comment_id}"
puts "[DEBUG] Repository: #{repo}"

# Validate format
unless comment_body&.start_with?('/cutover')
  puts "No cutover command found in comment."
  exit 0
end

matches = comment_body.match(/^\/cutover\s+(\S+)/)

unless matches
  message = <<~MSG
    ❌ You have used an invalid cutover command format: `#{comment_body}`

    ✅ **Expected format:** `/cutover <SNOW-ID>` (e.g., `/cutover INC1234567`)
  MSG

  puts message

  unless local_mode
    # React with ❌
    reaction_uri = URI("https://api.github.com/repos/#{repo}/issues/comments/#{comment_id}/reactions")
    reaction_req = Net::HTTP::Post.new(reaction_uri)
    reaction_req['Authorization'] = "Bearer #{github_token}"
    reaction_req['Accept'] = "application/vnd.github.squirrel-girl-preview+json"
    reaction_req.body = { content: "x" }.to_json

    Net::HTTP.start(reaction_uri.hostname, reaction_uri.port, use_ssl: true) do |http|
      http.request(reaction_req)
    end

    # Comment with guidance
    comment_uri = URI("https://api.github.com/repos/#{repo}/issues/#{issue_number}/comments")
    comment_req = Net::HTTP::Post.new(comment_uri)
    comment_req['Authorization'] = "Bearer #{github_token}"
    comment_req['Accept'] = 'application/vnd.github+json'
    comment_req.body = { body: message }.to_json

    Net::HTTP.start(comment_uri.hostname, comment_uri.port, use_ssl: true) do |http|
      http.request(comment_req)
    end
  end

  exit 1
end

snow_id = matches[1]
puts "✅ Cutover requested with SNOW-ID: #{snow_id}"

if local_mode
  puts "🧪 Local mode: skipping GitHub API calls."
  exit 0
end

# === GitHub API logic ===

label_color = '002b36'

# Create label
create_label_uri = URI("https://api.github.com/repos/#{repo}/labels")
create_label_req = Net::HTTP::Post.new(create_label_uri)
create_label_req['Authorization'] = "Bearer #{github_token}"
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
  puts "ℹ️ Label '#{snow_id}' already exists."
elsif create_res.code.to_i.between?(200, 299)
  puts "✅ Label '#{snow_id}' created successfully."
else
  puts "❌ Failed to create label. Response: #{create_res.code} - #{create_res.body}"
  exit 1
end

# Apply label to issue
label_uri = URI("https://api.github.com/repos/#{repo}/issues/#{issue_number}/labels")
label_req = Net::HTTP::Post.new(label_uri)
label_req['Authorization'] = "Bearer #{github_token}"
label_req['Accept'] = 'application/vnd.github+json'
label_req.body = { labels: [snow_id] }.to_json

res = Net::HTTP.start(label_uri.hostname, label_uri.port, use_ssl: true) do |http|
  http.request(label_req)
end

if res.code.to_i.between?(200, 299)
  puts "✅ Label '#{snow_id}' added to issue ##{issue_number}"
else
  puts "❌ Failed to add label. Response: #{res.code} - #{res.body}"
  exit 1
end
