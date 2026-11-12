# AI Assignment Studio

A static assignment companion for a live group app-building workshop with Lovable. It includes a student brief, prompt scaffold, group roles, build checklist, hand-in template, teacher run sheet, 80-minute facilitation plan, rubric, and fallback activities.

## Live assignment

Open the published assignment page or open `index.html` directly in a browser. The student and teacher views work without a server, build step, or API key. Students use Lovable for the shared app project; this page stores only the local brief, checkboxes, and project link in that browser's `localStorage`.

The project link and checklists do not sync between group members or devices. Collect the final project link and reflection in your normal classroom/LMS submission channel. The page is a workshop guide, not a student account or gradebook system.

## Before using it with a class

1. Review Lovable's current plan, collaboration, publishing, age, and account terms for your students and school.
2. Confirm Lovable sign-in and project editing work on school devices and networks.
3. Decide how groups will submit project links and reflections.
4. Tell students to use fictional/sample data and never enter personal information, credentials, or secret API keys.
5. Try the activity once and adjust the timing to the class.

See [the live assignment guide](docs/LIVE_ASSIGNMENT_GUIDE.md) for facilitator instructions and [the backend note](docs/REAL_ACCOUNTS_SETUP.md) for the unconnected Supabase scaffold.

## Deploy

Pushing to `main` runs the GitHub Pages workflow in `.github/workflows/pages.yml`. There is no application build step.

## Backend status

The `supabase/` directory contains an earlier classroom-data and AI-coaching scaffold. The current static assignment page does not connect to it, and the session does not need it. Do not use the scaffold with real student accounts or information until its schema, authorization policies, deployment, and browser integration have been reviewed and completed.
