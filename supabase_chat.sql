-- 1. Conversations Table
create table if not exists public.conversations (
  id uuid default gen_random_uuid() primary key,
  updated_at timestamptz default now(),
  last_message text
);

-- 2. Participants Table (Junction)
create table if not exists public.participants (
  conversation_id uuid references public.conversations(id) on delete cascade,
  user_id uuid references public.users(id) on delete cascade,
  primary key (conversation_id, user_id)
);

-- 3. Messages Table
create table if not exists public.messages (
  id uuid default gen_random_uuid() primary key,
  conversation_id uuid references public.conversations(id) on delete cascade,
  sender_id uuid references public.users(id),
  content text not null,
  created_at timestamptz default now()
);

-- 4. Enable RLS
alter table public.conversations enable row level security;
alter table public.participants enable row level security;
alter table public.messages enable row level security;

-- POLICIES ---

-- Participants: View rows where they are the user
create policy "Users can view own participant rows"
on public.participants for select using (auth.uid() = user_id);

-- Conversations: View if you are a participant
create policy "Users can view conversations they are in"
on public.conversations for select
using (
  exists (
    select 1 from public.participants
    where conversation_id = id
    and user_id = auth.uid()
  )
);

-- Messages: View if you are a participant of the conversation
create policy "Users can view messages in their chats"
on public.messages for select
using (
  exists (
    select 1 from public.participants
    where conversation_id = messages.conversation_id
    and user_id = auth.uid()
  )
);

-- Messages: Insert if you are a participant
create policy "Users can send messages in their chats"
on public.messages for insert
with check (
  exists (
    select 1 from public.participants
    where conversation_id = messages.conversation_id
    and user_id = auth.uid()
  )
);

-- (Optional) Helper to create a conversation requires open permissions or specific function. 
-- For MVP, we'll allow Authenticated creation for now, keeping it simple.
create policy "Users can create conversations" on public.conversations for insert to authenticated with check(true);
create policy "Users can add participants" on public.participants for insert to authenticated with check(true);
