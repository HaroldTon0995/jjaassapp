-- Supabase schema for inventory items with real-time sync
-- Run this in your Supabase SQL editor if table does not exist or to ensure all columns are present.

create table if not exists public.inventory (
  id text primary key,
  name text not null,
  category text not null default 'water',
  unit text not null default 'Gallons',
  price double precision not null default 0.0,
  stock double precision not null default 0.0,
  capacity double precision not null default 100.0,
  description text default '',
  is_refill boolean not null default false,
  is_active boolean default true,
  updated_at timestamptz not null default now()
);

-- Ensure columns exist if table was previously created with fewer columns
alter table public.inventory add column if not exists category text not null default 'water';
alter table public.inventory add column if not exists unit text not null default 'Gallons';
alter table public.inventory add column if not exists price double precision not null default 0.0;
alter table public.inventory add column if not exists stock double precision not null default 0.0;
alter table public.inventory add column if not exists capacity double precision not null default 100.0;
alter table public.inventory add column if not exists description text default '';
alter table public.inventory add column if not exists is_refill boolean not null default false;
alter table public.inventory add column if not exists is_active boolean default true;
alter table public.inventory add column if not exists updated_at timestamptz not null default now();

-- Row Level Security policies
alter table public.inventory enable row level security;

drop policy if exists "inventory read" on public.inventory;
drop policy if exists "inventory insert" on public.inventory;
drop policy if exists "inventory update" on public.inventory;
drop policy if exists "inventory delete" on public.inventory;

create policy "inventory read" on public.inventory for select using (true);
create policy "inventory insert" on public.inventory for insert with check (true);
create policy "inventory update" on public.inventory for update using (true);
create policy "inventory delete" on public.inventory for delete using (true);

-- Enable Supabase Realtime broadcast for inventory changes
alter publication supabase_realtime add table public.inventory;

