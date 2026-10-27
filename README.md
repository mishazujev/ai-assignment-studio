# Common Ground

An early interface prototype for group assignments with private, individual AI conversations and one shared group response.

## Run the prototype

Open `index.html` in a browser, or serve this folder with any static file server. The prototype has no build step or dependencies.

## What is clickable

- Switch between a student workspace and teacher review.
- Switch among four separate sample student conversations.
- Add a thought to the shared group draft, edit it, and submit it.
- Open a group response in teacher review and copy it for later AI evaluation.

## Current boundary

This is a front-end demonstration. Sign-in, student identity, chat history, group editing, submission storage, and AI responses are simulated in the browser. The role switch is for preview only and is not access control.

## Next implementation step

Connect a real authentication and data service before using with students. A suitable next version would use Supabase Auth and Postgres with row-level policies for student accounts, individual conversation ownership, group membership, shared drafts, submissions, and teacher access. Put AI calls behind a server endpoint, with the model instructed to coach through questions rather than write the assignment. Store only the final group submission for teacher review by default; make any chat review policy explicit to students and teachers.

Suggested core records:

- `assignments`: teacher, class, topic, instructions, due date, status.
- `groups` and `group_members`: assignment groups and their logged-in members.
- `conversations` and `messages`: one private conversation per student and assignment.
- `group_drafts`: one shared response per group, with revision timestamps.
- `submissions`: final response, submitter, and submission time.

## GitHub

The local GitHub CLI is installed, but its saved GitHub token is invalid. Sign in with `gh auth login`, then create and push a repository from this folder with:

```powershell
gh repo create ai-assignment-studio --public --source . --remote origin --push
```

Choose `--private` instead if the prototype should not be public.
