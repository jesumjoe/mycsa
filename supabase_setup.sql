-- ==========================================
-- 1. Create Announcements Table
-- ==========================================
create table if not exists public.announcements (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  description text,
  type text check (type in ('Event', 'Requirement')),
  is_global boolean default false,
  target_campus text,
  image_url text,
  author_uid uuid references public.users(id),
  created_at timestamptz default now()
);

-- ==========================================
-- 2. Enable Security (RLS)
-- ==========================================
alter table public.announcements enable row level security;

-- Policy: Everyone can View announcements
create policy "Everyone can view announcements"
on public.announcements for select
using (true);

-- Policy: Only Authorized Roles can Post
-- (Checks if the user has a valid role in the public.users table)
create policy "Admins can insert announcements"
on public.announcements for insert
with check (
  exists (
    select 1 from public.users
    where id = auth.uid()
    and role in ('OverallHead', 'CampusHead', 'CohortRep', 'Faculty')
  )
);

-- ==========================================
-- 3. Storage Policies (Run after creating 'posters' bucket)
-- ==========================================
-- Note: Create a bucket named 'posters' in the dashboard first!

-- Allow public read access to posters
create policy "Public Access to Posters"
on storage.objects for select
using ( bucket_id = 'posters' );

-- Allow authenticated users to upload posters
create policy "Authenticated Users can upload Posters"
on storage.objects for insert
with check (
  bucket_id = 'posters' 
  and auth.role() = 'authenticated'
);
