# Supabase and AI scaffold status

The current assignment page is a static workshop companion. It does not create user accounts, synchronize group drafts, collect submissions, or call an AI API. The live Lovable assignment does not require this backend.

The `supabase/` folder is an earlier foundation for authenticated classroom records, private student AI conversations, group drafts/submissions, and teacher-only AI review. It is not deployed or wired to `index.html`. Treat the database migration and edge functions as development scaffolding only; do not use them with real student records until they have been reviewed and completed.

## If you later want connected classroom accounts

You will need to:

1. Create and configure a Supabase project, and review the migration, role assignment, join-code flow, row-level security, and student-data retention requirements.
2. Store the OpenAI API key only in Supabase Edge Function secrets and configure API billing and usage limits. ChatGPT subscriptions and API billing are separate.
3. Deploy the migration and Edge Functions, then implement and review the browser client, authentication screens, group/assignment management, private chat history, draft synchronization, submission, and teacher review.
4. Test authorization and data isolation with separate teacher, student, and group accounts before entering real student data.

The existing `docs/` no longer describes a ready-to-deploy account setup. No Supabase URL/key or OpenAI secret is embedded in the site. Do not add a service-role key or OpenAI key to browser code or GitHub.
