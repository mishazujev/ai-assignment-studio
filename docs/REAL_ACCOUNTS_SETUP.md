# Set up real accounts and AI

The public GitHub Pages site is static. This backend foundation uses Supabase for accounts and classroom data, and the OpenAI Responses API for student coaching and teacher review. The OpenAI API key belongs only in Supabase Edge Function secrets; never add it to `index.html`, GitHub Pages, or a committed file.

## Accounts you need

1. Create a Supabase project at <https://supabase.com/dashboard>.
2. Create an OpenAI API project/key at <https://platform.openai.com/api-keys> and set up API billing if needed. ChatGPT subscription billing and API billing are separate.
3. In Supabase, set `OPENAI_API_KEY` and `OPENAI_MODEL` in **Edge Functions → Secrets**. Pick a text model available to your OpenAI API project; `gpt-5-mini` is a cost-efficient starting point. Set usage limits in the OpenAI project.
4. Share only the Supabase **Project URL** and **publishable key** with the developer wiring the browser client. Never share the secret/service-role key or OpenAI key in chat, source files, or GitHub.

## Backend install

Install the Supabase CLI, link the project, then apply the migration and deploy the functions:

```powershell
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
supabase functions deploy student-chat
supabase functions deploy review-submission
```

The Edge Functions verify the signed-in user's JWT, use row-level security for database access, and call the Responses API server-side. `student-chat` writes only to that student's private conversation. `review-submission` requires the teacher role and stores a separate AI review; it does not replace the students' submitted text.

## First teacher and assignment

Create a teacher account through Supabase Auth. The profile trigger creates new accounts as students by default. In the Supabase SQL Editor, promote only the teacher's account:

```sql
update public.profiles
set role = 'teacher'
where id = (select id from auth.users where email = 'teacher@example.com');
```

Create an assignment and one group per collaboration team from the SQL Editor, then create an invite code for each group while signed in as the teacher through the app's authenticated RPC. Student accounts can join using that code. The UI still needs its account and classroom screens wired to this backend before this setup is usable end to end.

## Current implementation boundary

The migration and Edge Functions are prepared, but the public page still shows the local-only prototype. It does not yet sign in, load Supabase data, or invoke these functions. The next code step is to replace the demo controls with sign-in, assignment/group loading, private chat history, group draft synchronization, submission, and teacher review buttons, then deploy the browser configuration. Do not use the current public page with real student information.
