-- ==========================================
-- Storage Setup for Report Documents
-- ==========================================

-- 1. Create the 'report_docs' bucket if it doesn't exist
-- Note: This is usually done in the Supabase Dashboard, but just in case:
insert into storage.buckets (id, name, public)
values ('report_docs', 'report_docs', true)
on conflict (id) do nothing;

-- 2. Allow Public Read Access to Report Docs
-- (So we can share/view the link easily)
create policy "Public Access to Report Docs"
on storage.objects for select
using ( bucket_id = 'report_docs' );

-- 3. Allow Authenticated Users to Upload Report Docs
create policy "Authenticated Users can upload Report Docs"
on storage.objects for insert
with check (
  bucket_id = 'report_docs' 
  and auth.role() = 'authenticated'
);

-- 4. Allow Users to Update their own uploaded docs (optional but good)
create policy "Users can update own Report Docs"
on storage.objects for update
using (
  bucket_id = 'report_docs' 
  and auth.uid() = owner
);

-- 5. Allow Users to Delete their own uploaded docs (optional)
create policy "Users can delete own Report Docs"
on storage.objects for delete
using (
  bucket_id = 'report_docs' 
  and auth.uid() = owner
);
