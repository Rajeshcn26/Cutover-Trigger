# GitHub Cutover Command Handler

This Ruby script automates the process of handling `/cutover <SNOW-ID>` comments on GitHub issues. It validates the comment format, creates a label using the provided SNOW ID, and adds the label to the associated GitHub issue.

---

## ✨ Features

- Supports execution via GitHub Actions and local CLI.
- Validates `/cutover <SNOW-ID>` comment format.
- Automatically creates a label using the SNOW ID.
- Applies the label to the corresponding GitHub issue.
- Reacts with ❌ and posts guidance if the command format is invalid.
- Debug-friendly logs for transparency and troubleshooting.

---

## 🔧 Requirements

- Ruby 2.5+ installed.
- GitHub Personal Access Token (PAT) with `repo` scope.
- For GitHub Actions, GitHub automatically provides the `GITHUB_TOKEN`.

---

## 🚀 Usage

### ✅ Local Execution (Test Mode)

```
export GITHUB_TOKEN=ghp_your_pat_here
export GITHUB_REPOSITORY=your-org/your-repo

ruby cutover.rb \
  --comment "$(echo -n '/cutover INC9876543' | base64)" \
  --body "$(echo -n 'example content' | base64)" \
  --issue-id 5 \
  --real
```

<img width="457" height="224" alt="image" src="https://github.com/user-attachments/assets/73b9ec6e-cc01-4e53-94e2-213dcd60706a" />
