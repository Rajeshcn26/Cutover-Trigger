require "octokit"

def comment_on_issue(client, repo, issue_number, message)
  client.add_comment(repo, issue_number, message)
end

def in_progress_run_count(client, repo, workflow_name)
  runs = client.workflow_runs(repo, workflow_name, status: "in_progress")
  count = runs.total_count
  puts "In-progress runs for #{workflow_name}: #{count}"
  count
end

def get_issues_with_label(client, repo, label)
  issues = client.list_issues(repo, labels: label)
  result = []

  issues.each do |issue|
    events = client.issue_timeline(repo, issue.number)

    label_event = events.find do |event|
      event.event == "labeled" && event.label.name == label
    end

    if label_event
      result << [issue.number, label, label_event.created_at]
    else
      result << [issue.number, label, issue.created_at]
    end
  end

  result
end

def sort_issues_by_date(issues)
  issues.sort_by { |issue| issue[2] }
end

def add_label_to_issue(client, repo, issue_number, label)
  client.add_labels_to_an_issue(repo, issue_number, [label])
  puts "Added label '#{label}' to issue ##{issue_number}"
rescue => e
  puts "Error adding label '#{label}' to issue ##{issue_number}: #{e.message}"
end

ACCESS_TOKEN = ENV["GITHUB_TOKEN"]
REPO = ENV["SIPHON_REPO"]
client = Octokit::Client.new(access_token: ACCESS_TOKEN)
in_progress_count = in_progress_run_count(client, REPO, "migration-queue.yml")
max = ENV["MAX"].to_i # Maximum number of issues to comment on

label = "queued"
issues = get_issues_with_label(client, REPO, label)
sorted_issues = sort_issues_by_date(issues)

sorted_issues.each do |issue_number, label, created_at|
  break if in_progress_count >= max

  issue_labels = client.issue(REPO, issue_number).labels.map(&:name)
  if issue_labels.include?("queue-in-progress")
    puts "Skipping issue ##{issue_number} as it already has 'queue-in-progress' label"
    next
  end

  add_label_to_issue(client, REPO, issue_number, "queue-in-progress")

  in_progress_count += 1
end
