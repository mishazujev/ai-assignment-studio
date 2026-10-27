-- Common Ground: authenticated classroom data with private student conversations.
create extension if not exists pgcrypto with schema extensions;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default 'Student',
  role text not null default 'student' check (role in ('student', 'teacher')),
  created_at timestamptz not null default now()
);

create or replace function public.create_profile_for_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name, role)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''), 'Student'),
    'student'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.create_profile_for_new_user();

create table public.assignments (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.profiles(id),
  title text not null,
  topic text not null,
  instructions text not null,
  due_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.groups (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  name text not null,
  created_at timestamptz not null default now(),
  unique (id, assignment_id)
);

create table public.group_invites (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null references public.groups(id) on delete cascade,
  code_hash text not null unique,
  expires_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

create table public.conversations (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid not null references public.assignments(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (assignment_id, user_id)
);

create table public.messages (
  id bigint generated always as identity primary key,
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null check (role in ('user', 'assistant')),
  content text not null check (length(content) <= 8000),
  created_at timestamptz not null default now()
);

create table public.group_drafts (
  group_id uuid primary key references public.groups(id) on delete cascade,
  content text not null default '',
  updated_by uuid not null references public.profiles(id),
  updated_at timestamptz not null default now()
);

create table public.submissions (
  id uuid primary key default gen_random_uuid(),
  group_id uuid not null unique references public.groups(id) on delete cascade,
  content text not null,
  submitted_by uuid not null references public.profiles(id),
  submitted_at timestamptz not null default now()
);

create table public.ai_reviews (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null unique references public.submissions(id) on delete cascade,
  teacher_id uuid not null references public.profiles(id),
  review_text text not null,
  created_at timestamptz not null default now()
);

create index messages_conversation_created_idx on public.messages (conversation_id, created_at);
create index group_members_user_idx on public.group_members (user_id, group_id);

create or replace function public.is_group_member(target_group uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.group_members gm
    where gm.group_id = target_group and gm.user_id = (select auth.uid())
  );
$$;

create or replace function public.owns_assignment(target_assignment uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.assignments a
    join public.profiles p on p.id = a.teacher_id and p.role = 'teacher'
    where a.id = target_assignment and a.teacher_id = (select auth.uid())
  );
$$;

create or replace function public.is_assignment_member(target_assignment uuid)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.groups g
    join public.group_members gm on gm.group_id = g.id
    where g.assignment_id = target_assignment and gm.user_id = (select auth.uid())
  );
$$;

create or replace function public.create_group_invite(target_group uuid, expires_in_days integer default 14)
returns text language plpgsql security definer set search_path = '' as $$
declare
  assignment_owner uuid;
  raw_code text;
begin
  select a.teacher_id into assignment_owner
  from public.groups g join public.assignments a on a.id = g.assignment_id
  where g.id = target_group;
  if assignment_owner is null or assignment_owner <> (select auth.uid()) then
    raise exception 'Only the assignment teacher can create an invite';
  end if;
  raw_code := upper(substr(encode(extensions.gen_random_bytes(8), 'hex'), 1, 16));
  insert into public.group_invites (group_id, code_hash, expires_at)
  values (target_group, encode(extensions.digest(raw_code, 'sha256'), 'hex'),
    case when expires_in_days > 0 then now() + make_interval(days => expires_in_days) else null end);
  return raw_code;
end;
$$;

create or replace function public.join_group_with_code(invite_code text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  target_group uuid;
begin
  if (select auth.uid()) is null then raise exception 'Sign in first'; end if;
  select gi.group_id into target_group
  from public.group_invites gi
  where gi.code_hash = encode(extensions.digest(upper(trim(invite_code)), 'sha256'), 'hex')
    and (gi.expires_at is null or gi.expires_at > now())
  limit 1;
  if target_group is null then raise exception 'Invite code is invalid or expired'; end if;
  insert into public.group_members (group_id, user_id)
  values (target_group, (select auth.uid())) on conflict do nothing;
  return target_group;
end;
$$;

alter table public.profiles enable row level security;
alter table public.assignments enable row level security;
alter table public.groups enable row level security;
alter table public.group_invites enable row level security;
alter table public.group_members enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.group_drafts enable row level security;
alter table public.submissions enable row level security;
alter table public.ai_reviews enable row level security;

create policy "profiles read own or classmates" on public.profiles for select to authenticated
using (
  id = (select auth.uid()) or exists (
    select 1 from public.group_members mine
    join public.group_members theirs on theirs.group_id = mine.group_id
    where mine.user_id = (select auth.uid()) and theirs.user_id = profiles.id
  ) or exists (
    select 1 from public.group_members gm join public.groups g on g.id = gm.group_id
    join public.assignments a on a.id = g.assignment_id
    where gm.user_id = profiles.id and a.teacher_id = (select auth.uid())
  )
);
create policy "users update own display name" on public.profiles for update to authenticated
using (id = (select auth.uid())) with check (id = (select auth.uid()) and role in ('student', 'teacher'));

create policy "assignment members and owner read" on public.assignments for select to authenticated
using (teacher_id = (select auth.uid()) or public.is_assignment_member(id));
create policy "teacher creates assignments" on public.assignments for insert to authenticated
with check (teacher_id = (select auth.uid()) and exists (select 1 from public.profiles p where p.id = (select auth.uid()) and p.role = 'teacher'));
create policy "teacher updates assignments" on public.assignments for update to authenticated
using (public.owns_assignment(id)) with check (public.owns_assignment(id));

create policy "assignment users read groups" on public.groups for select to authenticated
using (public.is_group_member(id) or public.owns_assignment(assignment_id));
create policy "teacher manages groups" on public.groups for all to authenticated
using (public.owns_assignment(assignment_id)) with check (public.owns_assignment(assignment_id));
create policy "invite hidden from browser" on public.group_invites for select to authenticated using (false);
create policy "group members read memberships" on public.group_members for select to authenticated
using (user_id = (select auth.uid()) or public.is_group_member(group_id) or exists (
  select 1 from public.groups g where g.id = group_id and public.owns_assignment(g.assignment_id)
));

create policy "students read own conversation" on public.conversations for select to authenticated
using (user_id = (select auth.uid()));
create policy "students create own conversation" on public.conversations for insert to authenticated
with check (user_id = (select auth.uid()) and public.is_assignment_member(assignment_id));
create policy "messages stay with owner" on public.messages for select to authenticated
using (user_id = (select auth.uid()) and exists (
  select 1 from public.conversations c where c.id = conversation_id and c.user_id = (select auth.uid())
));
create policy "students write own conversation messages" on public.messages for insert to authenticated
with check (user_id = (select auth.uid()) and exists (
  select 1 from public.conversations c where c.id = conversation_id and c.user_id = (select auth.uid())
));

create policy "group reads draft" on public.group_drafts for select to authenticated
using (public.is_group_member(group_id) or exists (
  select 1 from public.groups g where g.id = group_id and public.owns_assignment(g.assignment_id)
));
create policy "group members edit draft" on public.group_drafts for insert to authenticated
with check (public.is_group_member(group_id) and updated_by = (select auth.uid()));
create policy "group members update draft" on public.group_drafts for update to authenticated
using (public.is_group_member(group_id)) with check (public.is_group_member(group_id) and updated_by = (select auth.uid()));

create policy "group and teacher read submission" on public.submissions for select to authenticated
using (public.is_group_member(group_id) or exists (
  select 1 from public.groups g where g.id = group_id and public.owns_assignment(g.assignment_id)
));
create policy "group members submit" on public.submissions for insert to authenticated
with check (public.is_group_member(group_id) and submitted_by = (select auth.uid()));
create policy "group members update submission" on public.submissions for update to authenticated
using (public.is_group_member(group_id)) with check (public.is_group_member(group_id) and submitted_by = (select auth.uid()));

create policy "teacher reads and writes own reviews" on public.ai_reviews for all to authenticated
using (teacher_id = (select auth.uid()) and exists (
  select 1 from public.submissions s join public.groups g on g.id = s.group_id
  where s.id = submission_id and public.owns_assignment(g.assignment_id)
)) with check (teacher_id = (select auth.uid()) and exists (
  select 1 from public.submissions s join public.groups g on g.id = s.group_id
  where s.id = submission_id and public.owns_assignment(g.assignment_id)
));

revoke all on public.group_invites from anon, authenticated;
revoke insert, delete on public.group_members from anon, authenticated;
revoke update on public.profiles from anon, authenticated;
grant update (display_name) on public.profiles to authenticated;
grant execute on function public.join_group_with_code(text) to authenticated;
grant execute on function public.create_group_invite(uuid, integer) to authenticated;
