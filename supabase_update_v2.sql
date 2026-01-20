-- 1. Add Deadline to Announcements
alter table public.announcements 
add column if not exists deadline timestamptz;

-- 2. Create Responses Table (Chat-lite)
create table if not exists public.requirement_responses (
  id uuid default gen_random_uuid() primary key,
  announcement_id uuid references public.announcements(id) on delete cascade,
  user_id uuid references public.users(id),
  status text default 'Available',
  message text,
  created_at timestamptz default now()
);

-- 3. Security Policies for Responses
alter table public.requirement_responses enable row level security;

-- Volunteers: Can INSERT their own response
create policy "Volunteers can respond"
on public.requirement_responses for insert
with check ( auth.uid() = user_id );

-- Admins: Can VIEW all responses
create policy "Admins can view responses"
on public.requirement_responses for select
using (
  exists (
    select 1 from public.users
    where id = auth.uid()
    and role in ('OverallHead', 'CampusHead', 'CohortRep', 'Faculty')
  )
);

-- Users: Can VIEW their own responses
create policy "Users can view own responses"
on public.requirement_responses for select
using ( auth.uid() = user_id );
