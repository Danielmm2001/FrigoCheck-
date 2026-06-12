create table if not exists public.barcode_products (
  barcode text primary key,
  name text not null,
  normalized_name text,
  brand text,
  category text,
  quantity numeric,
  unit text,
  storage_location text,
  estimated_expiry_days integer,
  expiry_confidence text default 'medium',
  image_url text,
  source text default 'frigocheck_cache',
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists barcode_products_normalized_name_idx
  on public.barcode_products (normalized_name);

create or replace function public.set_barcode_products_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists set_barcode_products_updated_at
  on public.barcode_products;

create trigger set_barcode_products_updated_at
before update on public.barcode_products
for each row
execute function public.set_barcode_products_updated_at();
