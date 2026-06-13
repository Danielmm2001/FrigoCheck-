alter table public.barcode_products
add column if not exists original_image_url text,
add column if not exists processed_image_url text,
add column if not exists image_storage_path text,
add column if not exists image_processing_status text default 'pending',
add column if not exists provider_source text,
add column if not exists is_verified boolean default false,
add column if not exists verified_by uuid references auth.users(id) on delete set null,
add column if not exists verified_at timestamptz,
add column if not exists confidence_score numeric(3,2) default 0.70,
add column if not exists last_lookup_at timestamptz;

grant select, insert, update, delete on public.barcode_products to service_role;

create index if not exists barcode_products_is_verified_idx
  on public.barcode_products (is_verified);

create index if not exists barcode_products_provider_source_idx
  on public.barcode_products (provider_source);

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  5242880,
  array['image/png', 'image/jpeg', 'image/webp']::text[]
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can read product images"
  on storage.objects;

create policy "Public can read product images"
on storage.objects
for select
using (bucket_id = 'product-images');

drop policy if exists "Service role can manage product images"
  on storage.objects;

create policy "Service role can manage product images"
on storage.objects
for all
using (bucket_id = 'product-images' and auth.role() = 'service_role')
with check (bucket_id = 'product-images' and auth.role() = 'service_role');

alter table public.barcode_products enable row level security;

drop policy if exists "Only service role can read barcode cache"
  on public.barcode_products;

create policy "Only service role can read barcode cache"
on public.barcode_products
for select
using (auth.role() = 'service_role');

drop policy if exists "Only service role can write barcode cache"
  on public.barcode_products;

create policy "Only service role can write barcode cache"
on public.barcode_products
for all
using (auth.role() = 'service_role')
with check (auth.role() = 'service_role');
