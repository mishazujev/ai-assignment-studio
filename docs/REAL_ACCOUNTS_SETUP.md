# Make the classroom app live

The page uses Supabase for Google sign-in and classroom data. Complete these steps before students use it.

## 1. Create a Supabase project

Create a project in the Supabase dashboard and note its project URL and publishable key (the legacy anon key is also accepted). These values are public browser configuration and protected by the database's row-level security. Never put the service-role key or OpenAI API key in this file.

Edit `supabase/public-config.js`:

```js
window.SUPABASE_CONFIG = {
  url: "https://YOUR_PROJECT_REF.supabase.co",
  anonKey: "YOUR_SUPABASE_PUBLISHABLE_OR_ANON_KEY"
};
```

The GitHub Pages URL is public, so the publishable key is expected to be visible. RLS is the security boundary.

## 2. Configure Google sign-in

1. In Google Cloud Console, create an OAuth client for a Web application.
2. Add the Supabase callback URL as an authorized redirect URI: `https://YOUR_PROJECT_REF.supabase.co/auth/v1/callback`.
3. Copy the Google client ID and client secret into **Supabase → Authentication → Sign In / Providers → Google** and enable the provider.
4. In **Supabase → Authentication → URL Configuration**, set the Site URL to `https://mishazujev.github.io/ai-assignment-studio/` and add it to the redirect URL allowlist. Add your local development URL too if needed.
5. Review Google OAuth consent-screen requirements, student age rules, and your school's policy for third-party accounts before asking students to sign in.

## 3. Apply the database migrations

Install the Supabase CLI, log in, link the project, then apply both migrations:

```sh
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

The migrations create profiles, assignments, groups and invite codes, private student conversations, shared drafts, submissions, AI review records, and teacher grades with row-level security.

## 4. Enable AI coaching

Create an OpenAI API key for a project with API billing enabled, then set it only in Supabase Edge Function secrets. ChatGPT subscription billing and API billing are separate.

```sh
supabase secrets set OPENAI_API_KEY=YOUR_OPENAI_API_KEY OPENAI_MODEL=gpt-5-mini
supabase functions deploy student-chat
```

Set usage limits in the OpenAI project. The teacher grading screen is manual; `review-submission` remains an optional AI review endpoint and is not used by the page.

## 5. Create the teacher account

1. Sign in once at the deployed site with the teacher's Google account. The profile trigger creates the account as a student by default.
2. In Supabase SQL Editor, promote that exact account:

```sql
update public.profiles
set role = 'teacher'
where id = (select id from auth.users where email = 'teacher@example.com');
```

3. Sign out and sign in again. The teacher workspace should show assignment creation and grading.

Students sign in with Google and are students by default. They can select a published assignment, create a group and share its invite code, or enter a teammate's code. Their AI chat is private; the group draft is shared and autosaved; a group can send the draft to the teacher for grading.

## 6. Publish the configured page and verify access

Commit the configured `supabase/public-config.js` and app changes to the branch GitHub Pages deploys, then confirm the Actions deployment succeeds. Test with one teacher account and two separate student accounts: publish an assignment, create/join a group, exchange AI messages, edit the shared draft from both accounts, submit, and save a teacher grade.

The page stores profile and classroom data in Supabase. Use fictional/sample data until the school has approved the account, privacy, and retention setup. Do not place real student data in a public app, and never share account passwords.
