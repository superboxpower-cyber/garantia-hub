alter table public.warranty_customers add column if not exists country_code text;
alter table public.warranty_customers add column if not exists country_name text;
alter table public.warranty_customers add column if not exists country_flag text;
alter table public.warranty_customers add column if not exists language text;
