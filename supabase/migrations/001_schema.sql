-- Mayo Store · Migration 001 · tables, constraints, indexes, triggers
create extension if not exists pgcrypto;

create or replace function public.set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

-- ---------- roles (server-controlled; users can never write here) ----------
create table public.user_roles (
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('admin')),
  created_at timestamptz not null default now(),
  primary key (user_id, role)
);

-- ---------- profiles ----------
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text check (char_length(full_name) <= 120),
  username text unique check (username ~ '^[a-zA-Z0-9_]{3,30}$'),
  avatar_url text,
  email text,
  phone text check (char_length(phone) <= 30),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger trg_profiles_updated before update on public.profiles for each row execute function public.set_updated_at();

-- ---------- products ----------
create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(name) between 2 and 120),
  slug text not null unique check (slug ~ '^[a-z0-9-]+$'),
  description text,
  short_description text,
  category text not null check (category in ('website','discord_bot')),
  subcategory text,
  price numeric(10,2) not null check (price >= 0),
  original_price numeric(10,2) check (original_price is null or original_price >= price),
  thumbnail_url text,
  preview_url text,
  features jsonb not null default '[]'::jsonb,
  technologies jsonb not null default '[]'::jsonb,
  is_featured boolean not null default false,
  is_active boolean not null default true,
  stock_status text not null default 'in_stock' check (stock_status in ('in_stock','limited','out_of_stock')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.products (category, is_active);
create index on public.products using gin (to_tsvector('english', name || ' ' || coalesce(description,'')));
create trigger trg_products_updated before update on public.products for each row execute function public.set_updated_at();

create table public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  image_url text not null,
  display_order int not null default 0
);
create index on public.product_images (product_id, display_order);

-- ---------- coupons ----------
create table public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code = upper(code)),
  discount_type text not null check (discount_type in ('percent','fixed')),
  discount_value numeric(10,2) not null check (discount_value > 0),
  minimum_order numeric(10,2) not null default 0 check (minimum_order >= 0),
  usage_limit int check (usage_limit is null or usage_limit > 0),
  used_count int not null default 0 check (used_count >= 0),
  expires_at timestamptz,
  is_active boolean not null default true,
  check (discount_type <> 'percent' or discount_value <= 100)
);

-- ---------- manual payment configuration ----------
create table public.payment_methods (
  code text primary key,
  label text not null,
  instructions text,
  is_active boolean not null default true,
  sort_order int not null default 0
);

-- ---------- orders ----------
create sequence public.order_number_seq start 1001;
create table public.orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete restrict,
  order_number text not null unique default ('MAYO-' || nextval('public.order_number_seq')),
  subtotal numeric(10,2) not null check (subtotal >= 0),
  discount numeric(10,2) not null default 0 check (discount >= 0),
  total numeric(10,2) not null check (total >= 0),
  coupon_code text,
  status text not null default 'pending' check (status in ('pending','confirmed','processing','completed','cancelled')),
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid','pending','paid','refunded')),
  payment_method text references public.payment_methods(code),
  payment_reference text check (char_length(payment_reference) <= 200),
  customer_notes text check (char_length(customer_notes) <= 2000),
  internal_notes text,
  idempotency_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, idempotency_key),
  check (total = subtotal - discount)
);
create index on public.orders (user_id, created_at desc);
create index on public.orders (status, created_at desc);
create trigger trg_orders_updated before update on public.orders for each row execute function public.set_updated_at();

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  product_name text not null,           -- snapshot
  unit_price numeric(10,2) not null check (unit_price >= 0), -- snapshot
  quantity int not null check (quantity between 1 and 10),
  subtotal numeric(10,2) not null check (subtotal = unit_price * quantity)
);
create index on public.order_items (order_id);

-- ---------- custom requests ----------
create table public.custom_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  customer_name text not null check (char_length(customer_name) between 2 and 120),
  customer_email text not null check (customer_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  project_type text not null check (project_type in ('website','discord_bot','other')),
  budget text,
  description text not null check (char_length(description) between 10 and 5000),
  status text not null default 'new' check (status in ('new','reviewing','quoted','accepted','rejected','completed')),
  quote_amount numeric(10,2) check (quote_amount is null or quote_amount >= 0),
  admin_notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index on public.custom_requests (user_id, created_at desc);
create trigger trg_requests_updated before update on public.custom_requests for each row execute function public.set_updated_at();

-- ---------- reviews ----------
create table public.reviews (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  rating int not null check (rating between 1 and 5),
  review_text text check (char_length(review_text) <= 2000),
  is_approved boolean not null default false,
  created_at timestamptz not null default now(),
  unique (user_id, product_id)
);

-- ---------- notifications ----------
create table public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  message text not null,
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);
create index on public.notifications (user_id, is_read, created_at desc);

-- ---------- site settings ----------
create table public.site_settings (
  id uuid primary key default gen_random_uuid(),
  setting_key text not null unique,
  setting_value text,
  updated_at timestamptz not null default now()
);
create trigger trg_settings_updated before update on public.site_settings for each row execute function public.set_updated_at();

-- ---------- auto-create profile on signup ----------
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id, email, full_name)
  values (new.id, new.email, new.raw_user_meta_data->>'full_name')
  on conflict (id) do nothing;
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
