create extension if not exists "uuid-ossp";

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  avatar_url text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.receipts (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  store_name text,
  purchase_date date,
  total_amount numeric(10,2),
  image_url text,
  raw_text text,
  ai_response jsonb,
  created_at timestamptz default now()
);

create table if not exists public.products (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  receipt_id uuid references public.receipts(id) on delete set null,
  name text not null,
  normalized_name text,
  category text default 'other',
  quantity numeric default 1,
  unit text default 'ud',
  storage_location text default 'fridge',
  purchase_date date default current_date,
  estimated_expiry_date date,
  expiry_confidence text default 'medium',
  status text default 'active',
  notes text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.product_events (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  event_type text not null,
  event_date timestamptz default now(),
  metadata jsonb
);

create table if not exists public.notification_preferences (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  enabled boolean default true,
  daily_reminder_time time default '10:00',
  notify_days_before integer default 2,
  push_enabled boolean default true,
  email_enabled boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.user_stats_monthly (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  year integer not null,
  month integer not null,
  consumed_count integer default 0,
  wasted_count integer default 0,
  expired_count integer default 0,
  saved_estimated_amount numeric(10,2) default 0,
  streak_days integer default 0,
  score integer default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique(user_id, year, month)
);

create index if not exists idx_receipts_user_id on public.receipts(user_id);
create index if not exists idx_products_user_id on public.products(user_id);
create index if not exists idx_products_status on public.products(status);
create index if not exists idx_products_expiry_date on public.products(estimated_expiry_date);
create index if not exists idx_product_events_user_id on public.product_events(user_id);
create index if not exists idx_product_events_product_id on public.product_events(product_id);

alter table public.profiles enable row level security;
alter table public.receipts enable row level security;
alter table public.products enable row level security;
alter table public.product_events enable row level security;
alter table public.notification_preferences enable row level security;
alter table public.user_stats_monthly enable row level security;

create policy "Users can view own profile" on public.profiles
for select using (auth.uid() = id);

create policy "Users can update own profile" on public.profiles
for update using (auth.uid() = id);

create policy "Users can view own receipts" on public.receipts
for select using (auth.uid() = user_id);

create policy "Users can insert own receipts" on public.receipts
for insert with check (auth.uid() = user_id);

create policy "Users can update own receipts" on public.receipts
for update using (auth.uid() = user_id);

create policy "Users can delete own receipts" on public.receipts
for delete using (auth.uid() = user_id);

create policy "Users can view own products" on public.products
for select using (auth.uid() = user_id);

create policy "Users can insert own products" on public.products
for insert with check (auth.uid() = user_id);

create policy "Users can update own products" on public.products
for update using (auth.uid() = user_id);

create policy "Users can delete own products" on public.products
for delete using (auth.uid() = user_id);

create policy "Users can view own product events" on public.product_events
for select using (auth.uid() = user_id);

create policy "Users can insert own product events" on public.product_events
for insert with check (auth.uid() = user_id);

create policy "Users can view own notification preferences" on public.notification_preferences
for select using (auth.uid() = user_id);

create policy "Users can insert own notification preferences" on public.notification_preferences
for insert with check (auth.uid() = user_id);

create policy "Users can update own notification preferences" on public.notification_preferences
for update using (auth.uid() = user_id);

create policy "Users can view own monthly stats" on public.user_stats_monthly
for select using (auth.uid() = user_id);
