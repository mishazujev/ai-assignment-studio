# Common Ground

An early interface prototype for group assignments with private, individual AI conversations and one shared group response.

## Live prototype

<https://mishazujev.github.io/ai-assignment-studio/>

The public page is still a browser-only demonstration. Sign-in, chat, drafts, group collaboration, and submissions are not connected to real accounts yet. Do not use it with real student information.

## Backend foundation

The Supabase migration and Edge Functions now outline authenticated classroom records, private student conversations, group drafts and submissions, and a teacher-only AI review. They are not deployed or called by the public site yet. Follow [Real accounts setup](docs/REAL_ACCOUNTS_SETUP.md) to prepare Supabase and OpenAI.

The OpenAI API key is designed to stay in Supabase Edge Function secrets. Student chats are separate per student and assignment; the teacher review endpoint reads a submitted group response and saves a separate suggested review/revision.

## Run the current prototype

Open `index.html` in a browser. It has no build step or dependencies. The code in `supabase/` is backend scaffolding and requires a Supabase project before deployment.

## Deployment

Pushing to `main` runs the GitHub Pages workflow in `.github/workflows/pages.yml`.
