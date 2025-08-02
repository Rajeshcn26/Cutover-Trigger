# 🛠️ GitHub IssueOps: /cutover Command Automation

This repository implements an automated IssueOps workflow using GitHub Actions and a Ruby script to handle a custom `/cutover <SNOW-ID>` command in issue comments.

---

## 💡 Features

- ✅ Listens for GitHub issue comments starting with `/cutover`.
- 🧪 Validates the command format (expects `/cutover <SNOW-ID>`).
- 🔖 Automatically creates a GitHub label using the SNOW-ID and a specific color (`#002b36`).
- 📌 Applies the label to the issue that received the comment.
- ❌ If the format is invalid (e.g. just `/cutover`), it reacts with ❌ and replies with usage guidance.

---

## 🧑‍💻 How to Use

1. Go to any GitHub issue.
2. Post a comment in the format:

   ```bash
   /cutover INC1234567

3. The workflow will:
    - Create a label named `INC1234567` (with dark blue color).
    - Attach it to the issue.

    If the command is invalid, like:

    ```bash
    /cutover

Then:
- A ❌ reaction will be added to the comment.
- A response will be posted with the correct usage format.

## 🗂️ Project Structure
```bash
.github/
├── scripts/
│   └── process_cutover_command.rb   # Ruby script for command processing
└── workflows/
    └── cutover.yml                  # GitHub Actions workflow
