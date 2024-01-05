name: Commit Notification

on:
  push:
    branches:
      - development
  pull_request:
    types:
      - closed

jobs:
  notify-commit:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: .github/notion-versions
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4
      - uses: dart-lang/setup-dart@v1

      - name: Get PR Details
        id: pr_details
        run: echo "::set-output name=author::${{ github.event.pull_request.user.login }}::set-output name=title::${{ github.event.pull_request.title }}::set-output name=date::${{ github.event.pull_request.updated_at }}"

      - name: Send Commit Notification to Notion
        run: dart .github/notion-versions/merge-info.dart
        env:
          ACTION: MERGE
          COMMIT_MESSAGE: ${{ github.event.head_commit.message }}
          PR_AUTHOR: ${{ steps.pr_details.outputs.author }}
          PR_TITLE: ${{ steps.pr_details.outputs.title }}
          PR_DATE: ${{ steps.pr_details.outputs.date }}
