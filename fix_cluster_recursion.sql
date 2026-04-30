-- =================================================================
-- FINAL ROBUST FIX FOR RECURSION (THE "NUCLEAR" OPTION)
-- =================================================================

-- 1. Ensure the Security Definer function exists (Bypasses RLS)
create or replace function public.is_admin()
returns boolean
language plpgsql
security definer
as $$
begin
  return exists (
    select 1 from public.users
    where id = auth.uid()
    and role in ('OverallHead', 'CampusHead', 'CohortRep', 'Faculty')
  );
end;
$$;

-- 2. Drop *ALL* policies on clusters and cluster_members to be safe
-- We loop through system catalog to delete them by table name, forcing a clean slate.

do $$
declare
  pol record;
begin
  for pol in select policyname, tablename from pg_policies where tablename in ('clusters', 'cluster_members') loop
    execute format('drop policy if exists %I on public.%I', pol.policyname, pol.tablename);
  end loop;
end $$;

-- 3. Re-Create Policies for CLUSTERS
-- Policy A: View clusters if I am the admin/creator
create policy "View clusters as admin"
on public.clusters for select
using ( admin_id = auth.uid() or public.is_admin() );

-- Policy B: View clusters if I am a member
-- This queries cluster_members. This is safe ONLY if cluster_members DOES NOT query clusters back.
create policy "View clusters as member"
on public.clusters for select
using (
  exists (
    select 1 from public.cluster_members
    where cluster_id = id
    and user_id = auth.uid()
  )
);

-- Policy C: Insert/Update for Admins
create policy "Manage clusters as admin"
on public.clusters for all
using ( public.is_admin() );

-- 4. Re-Create Policies for CLUSTER_MEMBERS
-- Policy A: View my own membership
-- This does NOT query clusters. It only checks my own ID. SAFE.
create policy "View own membership"
on public.cluster_members for select
using ( user_id = auth.uid() );

-- Policy B: Admins can view all members
-- This uses the function to bypass RLS. SAFE.
create policy "Admins view all members"
on public.cluster_members for select
using ( public.is_admin() );

-- Policy C: Admins manage members
create policy "Admins manage members"
on public.cluster_members for all
using ( public.is_admin() );

-- 5. Helper verification
comment on table public.clusters is 'Fixed Policies Applied';
