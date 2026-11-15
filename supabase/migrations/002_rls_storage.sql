-- Mayo Store · Migration 002 · admin check, Row Level Security, storage

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.user_roles where user_id = auth.uid() and role = 'admin');
$$;
revoke all on function public.is_admin() from public;
grant execute on function public.is_admin() to anon, authenticated;

alter table public.user_roles      enable row level security;
alter table public.profiles        enable row level security;
alter table public.products        enable row level security;
alter table public.product_images  enable row level security;
alter table public.coupons         enable row level security;
alter table public.payment_methods enable row level security;
alter table public.orders          enable row level security;
alter table public.order_items     enable row level security;
alter table public.custom_requests enable row level security;
alter table public.reviews         enable row level security;
alter table public.notifications   enable row level security;
alter table public.site_settings   enable row level security;

-- user_roles: a user may only READ their own role. Nobody can write via the API
-- (grant admin from the SQL editor only).
create policy roles_read_own on public.user_roles for select to authenticated using (user_id = auth.uid());

-- profiles
create policy profiles_select on public.profiles for select to authenticated using (id = auth.uid() or public.is_admin());
create policy profiles_update_own on public.profiles for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

-- products / images: public sees active only; admin manages everything
create policy products_public_read on public.products for select using (is_active or public.is_admin());
create policy products_admin_write on public.products for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy images_public_read on public.product_images for select
  using (exists (select 1 from public.products p where p.id = product_id and (p.is_active or public.is_admin())));
create policy images_admin_write on public.product_images for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- coupons: admin only (customers validate through validate_coupon(); codes cannot be scraped)
create policy coupons_admin on public.coupons for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- payment methods
create policy pm_public_read on public.payment_methods for select using (is_active or public.is_admin());
create policy pm_admin_write on public.payment_methods for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- orders: read own; ONLY create_order() can insert; only admins update (verify payment, status, notes)
create policy orders_select on public.orders for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy orders_admin_update on public.orders for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy order_items_select on public.order_items for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id and (o.user_id = auth.uid() or public.is_admin())));
revoke insert, delete on public.orders, public.order_items from authenticated, anon;
revoke update on public.order_items from authenticated, anon;
-- internal notes must never reach customers
-- (column REVOKE is a no-op while table-wide SELECT is granted, so grant an explicit column list instead)
revoke select on public.orders from authenticated, anon;
grant select (id, user_id, order_number, subtotal, discount, total, coupon_code, status, payment_status,
              payment_method, payment_reference, customer_notes, created_at, updated_at)
  on public.orders to authenticated;
create or replace function public.admin_order_notes(p_order uuid) returns text
language sql stable security definer set search_path = public as $$
  select case when public.is_admin() then internal_notes end from public.orders where id = p_order;
$$;
revoke all on function public.admin_order_notes(uuid) from public; grant execute on function public.admin_order_notes(uuid) to authenticated;

-- custom requests: anyone may submit (status forced to 'new'); owner reads own; admin manages
create policy requests_insert on public.custom_requests for insert to anon, authenticated
  with check (status = 'new' and quote_amount is null and admin_notes is null and (user_id is null or user_id = auth.uid()));
create policy requests_select on public.custom_requests for select to authenticated using (user_id = auth.uid() or public.is_admin());
create policy requests_admin_update on public.custom_requests for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy requests_admin_delete on public.custom_requests for delete to authenticated using (public.is_admin());
revoke select on public.custom_requests from authenticated, anon;
grant select (id, user_id, customer_name, customer_email, project_type, budget, description, status,
              quote_amount, created_at, updated_at) on public.custom_requests to authenticated;
create or replace function public.admin_request_notes(p_request uuid) returns text
language sql stable security definer set search_path = public as $$
  select case when public.is_admin() then admin_notes end from public.custom_requests where id = p_request;
$$;
revoke all on function public.admin_request_notes(uuid) from public;
grant execute on function public.admin_request_notes(uuid) to authenticated;

-- reviews: public reads approved; users submit their own (unapproved); admin moderates
create policy reviews_public_read on public.reviews for select using (is_approved or user_id = auth.uid() or public.is_admin());
create policy reviews_insert_own on public.reviews for insert to authenticated with check (user_id = auth.uid() and is_approved = false);
create policy reviews_admin on public.reviews for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy reviews_admin_delete on public.reviews for delete to authenticated using (public.is_admin());

-- notifications: own only; users may flip is_read only
create policy notif_select on public.notifications for select to authenticated using (user_id = auth.uid());
create policy notif_update on public.notifications for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy notif_admin_insert on public.notifications for insert to authenticated with check (public.is_admin());
revoke update on public.notifications from authenticated;
grant update (is_read) on public.notifications to authenticated;

-- site settings: public read (never store secrets here), admin write
create policy settings_read on public.site_settings for select using (true);
create policy settings_admin on public.site_settings for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- ===================== STORAGE =====================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types) values
 ('product-images','product-images', true,  5242880,  array['image/png','image/jpeg','image/webp']),
 ('user-avatars',  'user-avatars',   true,  2097152,  array['image/png','image/jpeg','image/webp']),
 ('custom-project-files','custom-project-files', false, 26214400, array['application/pdf','application/zip','image/png','image/jpeg','text/plain'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- product-images: world-readable, admin-only writes
create policy "product images read"   on storage.objects for select using (bucket_id = 'product-images');
create policy "product images admin"  on storage.objects for all to authenticated
  using (bucket_id = 'product-images' and public.is_admin()) with check (bucket_id = 'product-images' and public.is_admin());

-- user-avatars: each user owns the folder named after their uid
create policy "avatars read"   on storage.objects for select using (bucket_id = 'user-avatars');
create policy "avatars insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'user-avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars update" on storage.objects for update to authenticated
  using (bucket_id = 'user-avatars' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "avatars delete" on storage.objects for delete to authenticated
  using (bucket_id = 'user-avatars' and (storage.foldername(name))[1] = auth.uid()::text);

-- custom-project-files: private. Owner uploads/reads own folder (use signed URLs); admin reads all & deletes
create policy "project files read"   on storage.objects for select to authenticated
  using (bucket_id = 'custom-project-files' and ((storage.foldername(name))[1] = auth.uid()::text or public.is_admin()));
create policy "project files insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'custom-project-files' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "project files delete" on storage.objects for delete to authenticated
  using (bucket_id = 'custom-project-files' and public.is_admin());
