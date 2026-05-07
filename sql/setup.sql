create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.warranty_customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  whatsapp text,
  email text,
  document_ref text,
  country_code text,
  country_name text,
  country_flag text,
  language text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.warranty_customers add column if not exists country_code text;
alter table public.warranty_customers add column if not exists country_name text;
alter table public.warranty_customers add column if not exists country_flag text;
alter table public.warranty_customers add column if not exists language text;

create table if not exists public.warranty_accounts (
  id uuid primary key default gen_random_uuid(),
  label text,
  login text,
  password text,
  provider text,
  acquisition_cost numeric(12,2) default 0,
  acquired_at date,
  status text not null default 'available' check (status in ('available','sold','in_warranty','replaced','blocked')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.warranty_sales (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.warranty_customers(id) on delete cascade,
  initial_account_id uuid not null references public.warranty_accounts(id),
  sold_at date not null,
  warranty_days integer not null default 30 check (warranty_days > 0 and warranty_days <= 365),
  sale_price numeric(12,2) default 0,
  status text not null default 'active' check (status in ('active','expired','cancelled')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.warranty_replacements (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.warranty_sales(id) on delete cascade,
  replacement_account_id uuid not null references public.warranty_accounts(id),
  replaced_at date not null,
  reason text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_warranty_customers_whatsapp on public.warranty_customers (whatsapp);
create index if not exists idx_warranty_customers_email on public.warranty_customers (email);
create index if not exists idx_warranty_accounts_status on public.warranty_accounts (status);
create index if not exists idx_warranty_accounts_provider on public.warranty_accounts (provider);
create index if not exists idx_warranty_sales_customer_id on public.warranty_sales (customer_id);
create index if not exists idx_warranty_sales_sold_at on public.warranty_sales (sold_at desc);
create index if not exists idx_warranty_replacements_sale_id on public.warranty_replacements (sale_id);
create index if not exists idx_warranty_replacements_replaced_at on public.warranty_replacements (replaced_at desc);

create or replace trigger trg_warranty_customers_updated_at
before update on public.warranty_customers
for each row execute function public.set_updated_at();

create or replace trigger trg_warranty_accounts_updated_at
before update on public.warranty_accounts
for each row execute function public.set_updated_at();

create or replace trigger trg_warranty_sales_updated_at
before update on public.warranty_sales
for each row execute function public.set_updated_at();

create or replace trigger trg_warranty_replacements_updated_at
before update on public.warranty_replacements
for each row execute function public.set_updated_at();

create or replace view public.warranty_sales_overview as
select
  s.id,
  s.customer_id,
  c.name as customer_name,
  c.whatsapp,
  c.email,
  s.initial_account_id,
  s.sold_at,
  s.warranty_days,
  (s.sold_at + make_interval(days => s.warranty_days))::date as warranty_until,
  s.sale_price,
  s.status,
  coalesce(r.replacements_count, 0) as replacements_count,
  coalesce(r.current_account_id, s.initial_account_id) as current_account_id,
  (select a.login from public.warranty_accounts a where a.id = coalesce(r.current_account_id, s.initial_account_id)) as current_account_login
from public.warranty_sales s
join public.warranty_customers c on c.id = s.customer_id
left join lateral (
  select
    count(*)::int as replacements_count,
    (array_agg(replacement_account_id order by replaced_at desc, created_at desc))[1] as current_account_id
  from public.warranty_replacements wr
  where wr.sale_id = s.id
) r on true;

alter table public.warranty_customers enable row level security;
alter table public.warranty_accounts enable row level security;
alter table public.warranty_sales enable row level security;
alter table public.warranty_replacements enable row level security;

do $$ begin
  create policy "warranty_customers_public_rw" on public.warranty_customers for all using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "warranty_accounts_public_rw" on public.warranty_accounts for all using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "warranty_sales_public_rw" on public.warranty_sales for all using (true) with check (true);
exception when duplicate_object then null; end $$;
do $$ begin
  create policy "warranty_replacements_public_rw" on public.warranty_replacements for all using (true) with check (true);
exception when duplicate_object then null; end $$;

grant select, insert, update, delete on public.warranty_customers to anon, authenticated;
grant select, insert, update, delete on public.warranty_accounts to anon, authenticated;
grant select, insert, update, delete on public.warranty_sales to anon, authenticated;
grant select, insert, update, delete on public.warranty_replacements to anon, authenticated;
grant select on public.warranty_sales_overview to anon, authenticated;

comment on table public.warranty_customers is 'Projeto isolado de controle de garantias - clientes';
comment on table public.warranty_accounts is 'Projeto isolado de controle de garantias - contas vendidas/reposicoes';
comment on table public.warranty_sales is 'Projeto isolado de controle de garantias - compra original';
comment on table public.warranty_replacements is 'Projeto isolado de controle de garantias - reposicoes dentro da garantia original';
