create extension if not exists pgcrypto;

create table if not exists public.warranty_customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  whatsapp text,
  email text,
  document_ref text,
  notes text,
  created_at timestamptz not null default now()
);

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
  created_at timestamptz not null default now()
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
  created_at timestamptz not null default now()
);

create table if not exists public.warranty_replacements (
  id uuid primary key default gen_random_uuid(),
  sale_id uuid not null references public.warranty_sales(id) on delete cascade,
  replacement_account_id uuid not null references public.warranty_accounts(id),
  replaced_at date not null,
  reason text,
  notes text,
  created_at timestamptz not null default now()
);

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

comment on table public.warranty_customers is 'Projeto isolado de controle de garantias - clientes';
comment on table public.warranty_accounts is 'Projeto isolado de controle de garantias - contas vendidas/reposicoes';
comment on table public.warranty_sales is 'Projeto isolado de controle de garantias - compra original';
comment on table public.warranty_replacements is 'Projeto isolado de controle de garantias - reposicoes dentro da garantia original';
