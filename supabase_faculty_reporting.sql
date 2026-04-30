-- ==========================================
-- 1. Create Report Deadlines Table
-- ==========================================
create table if not exists public.report_deadlines (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  due_date timestamptz not null,
  campus_id text not null,
  created_by uuid references public.users(id),
  created_at timestamptz default now()
);

-- ==========================================
-- 2. Create Reports Table
-- ==========================================
create table if not exists public.reports (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  description text,
  link text,
  campus_id text,
  status text default 'Submitted' check (status in ('Submitted', 'Reviewed')),
  created_at timestamptz default now(),
  author_id uuid references public.users(id),
  deadline_id uuid references public.report_deadlines(id) on delete set null
);

-- ==========================================
-- 3. Enable Security (RLS)
-- ==========================================
alter table public.report_deadlines enable row level security;
alter table public.reports enable row level security;

-- ==========================================
-- 4. Policies for Report Deadlines
-- ==========================================

-- Faculty can ALL on their deadlines (same campus)
create policy "Faculty can manage deadlines"
on public.report_deadlines
using (
  exists (
    select 1 from public.users
    where id = auth.uid()
    and role = 'Faculty'
    and "campusId" = public.report_deadlines.campus_id
  )
);

-- Reps and Heads can VIEW deadlines for their campus
create policy "Reps and Heads can view deadlines"
on public.report_deadlines for select
using (
  exists (
    select 1 from public.users
    where id = auth.uid()
    and role in ('CohortRep', 'CampusHead', 'OverallHead')
    and "campusId" = public.report_deadlines.campus_id
  )
);

-- ==========================================
-- 5. Policies for Reports
-- ==========================================

-- Reps and Heads can INSERT reports (linked to their auth id)
create policy "Reps and Heads can submit reports"
on public.reports for insert
with check (
  auth.uid() = author_id
);

-- Authors can VIEW their own reports
create policy "Authors can view own reports"
on public.reports for select
using (
  auth.uid() = author_id
);

-- Faculty can VIEW reports for their campus
create policy "Faculty can view campus reports"
on public.reports for select
using (
  exists (
    select 1 from public.users
    where id = auth.uid()
    and role = 'Faculty'
    and "campusId" = public.reports.campus_id
  )
);

-- Faculty can UPDATE status of reports (Review)
create policy "Faculty can review reports"
on public.reports for update
using (
  exists (
    select 1 from public.users
    where id = auth.uid()
    and role = 'Faculty'
    and "campusId" = public.reports.campus_id
  )
);
