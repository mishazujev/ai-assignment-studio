# AI Assignment Studio

A small classroom app for teachers to publish assignments, students to sign in with Google, groups to share a working draft, and teachers to review and grade submissions.

## What the app does

- Google sign-in through Supabase Auth.
- Teacher assignment creation and publishing.
- Student group creation and invite-code joining.
- A private, per-student AI coaching conversation for each assignment.
- A shared group draft that saves to Supabase and refreshes for teammates.
- Group submission, teacher review, numeric grades, and written feedback.

## Setup required before the page works

This is a static GitHub Pages site backed by Supabase. See [the real accounts setup guide](docs/REAL_ACCOUNTS_SETUP.md) for Google OAuth, Supabase configuration, database migrations, function deployment, teacher promotion, and the browser publishable key. The page will not sign in while `supabase/public-config.js` still contains its placeholder values.

Use sample classroom content and review school policy before enabling student accounts. The OpenAI key and Supabase service-role key must remain server-side; only the Supabase publishable/anon key belongs in the browser config.

## Run locally

Open the GitHub Pages URL after configuring Supabase, or serve the repository over localhost (for example, `python -m http.server 8000`) and add that exact local URL to the Supabase Auth redirect allowlist. The page has no local build step.

## Deploy

Pushing to `main` runs the GitHub Pages workflow in `.github/workflows/pages.yml`.
