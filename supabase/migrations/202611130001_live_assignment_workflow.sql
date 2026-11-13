-- Live assignment flow: published assignments, student-created groups, and teacher grading.
alter table public.assignments
  add column if not exists is_published boolean not null default true;

alter table public.group_drafts
  add column if not exists project_url text
  check (project_url is null or (length(project_url) <= 2048 and project_url like 'https://%'));

create or replace function public.create_profile_for_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, display_name, role)
  values (
    new.id,
    coalesce(
      nullif(trim(new.raw_user_meta_data ->> 'display_name'), ''),
      nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
      nullif(trim(new.raw_user_meta_data ->> 'name'), ''),
      'Student'
    ),
    'student'
  );
  return new;
end;
$$;

create policy "students read published assignments" on public.assignments
for select to authenticated
using (is_published = true);

create or replace function public.create_student_group(target_assignment uuid, group_name text)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  new_group uuid;
begin
  if (select auth.uid()) is null then raise exception 'Sign in first'; end if;
  if not exists (
    select 1 from public.assignments a
    where a.id = target_assignment and a.is_published = true
  ) then raise exception 'Assignment not found or not open'; end if;
  if length(trim(coalesce(group_name, ''))) < 1 or length(trim(group_name)) > 80 then
    raise exception 'Group name must be between 1 and 80 characters';
  end if;
  insert into public.groups (assignment_id, name)
  values (target_assignment, trim(group_name))
  returning id into new_group;
  insert into public.group_members (group_id, user_id)
  values (new_group, (select auth.uid()));
  insert into public.group_drafts (group_id, content, updated_by)
  values (new_group, '', (select auth.uid()));
  return new_group;
end;
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
  if assignment_owner is null or (
    assignment_owner <> (select auth.uid()) and not public.is_group_member(target_group)
  ) then
    raise exception 'Only a group member or the assignment teacher can create an invite';
  end if;
  raw_code := upper(substr(encode(extensions.gen_random_bytes(8), 'hex'), 1, 16));
  insert into public.group_invites (group_id, code_hash, expires_at)
  values (target_group, encode(extensions.digest(raw_code, 'sha256'), 'hex'),
    case when expires_in_days > 0 then now() + make_interval(days => expires_in_days) else null end);
  return raw_code;
end;
$$;

grant execute on function public.create_student_group(uuid, text) to authenticated;
grant execute on function public.create_group_invite(uuid, integer) to authenticated;

create table public.teacher_grades (
  id uuid primary key default gen_random_uuid(),
  submission_id uuid not null unique references public.submissions(id) on delete cascade,
  teacher_id uuid not null references public.profiles(id),
  score integer not null check (score between 0 and 100),
  feedback text not null default '' check (length(feedback) <= 8000),
  updated_at timestamptz not null default now()
);

create index teacher_grades_teacher_idx on public.teacher_grades (teacher_id, updated_at desc);
alter table public.teacher_grades enable row level security;

create policy "assignment teachers manage grades" on public.teacher_grades
for all to authenticated
using (
  teacher_id = (select auth.uid()) and exists (
    select 1 from public.submissions s
    join public.groups g on g.id = s.group_id
    where s.id = submission_id and public.owns_assignment(g.assignment_id)
  )
)
with check (
  teacher_id = (select auth.uid()) and exists (
    select 1 from public.submissions s
    join public.groups g on g.id = s.group_id
    where s.id = submission_id and public.owns_assignment(g.assignment_id)
  )
);

grant select, insert, update on public.teacher_grades to authenticated;
