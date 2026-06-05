alter table public.products
add column if not exists price numeric(10,2);

comment on column public.products.price is 'Estimated or extracted line price for the product saved from a receipt.';
