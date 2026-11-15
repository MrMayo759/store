-- Mayo Store · Migration 003 · secure checkout, coupon check, notifications, realtime

-- Coupon preview for the cart (does not consume the coupon)
create or replace function public.validate_coupon(p_code text, p_subtotal numeric)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare c public.coupons; d numeric;
begin
  select * into c from coupons where code = upper(trim(p_code));
  if not found or not c.is_active or (c.expires_at is not null and c.expires_at < now())
     or (c.usage_limit is not null and c.used_count >= c.usage_limit) then
    return jsonb_build_object('valid', false, 'message', 'Invalid or expired coupon');
  end if;
  if p_subtotal < c.minimum_order then
    return jsonb_build_object('valid', false, 'message', 'Minimum order is $' || c.minimum_order);
  end if;
  d := case c.discount_type when 'percent' then round(p_subtotal * c.discount_value / 100, 2) else c.discount_value end;
  return jsonb_build_object('valid', true, 'discount', least(d, p_subtotal), 'message', 'Coupon applied');
end $$;

-- Secure checkout: the browser sends ONLY product ids + quantities.
-- Prices, coupon, totals and payment status are all decided here, atomically.
create or replace function public.create_order(
  p_items jsonb, p_coupon text default null, p_payment_method text default null,
  p_payment_reference text default null, p_notes text default null, p_idempotency_key text default null
) returns table (order_id uuid, order_number text, total numeric)
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid(); v_expected int; v_found int; v_bad int;
  v_sub numeric; v_disc numeric := 0; v_code text; c public.coupons; v_order public.orders;
begin
  if uid is null then raise exception 'Please sign in to place an order'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 20 then
    raise exception 'Invalid cart'; end if;

  -- duplicate protection: same key returns the original order
  if p_idempotency_key is not null then
    select * into v_order from orders o where o.user_id = uid and o.idempotency_key = p_idempotency_key;
    if found then return query select v_order.id, v_order.order_number, v_order.total; return; end if;
  end if;

  -- rate limit
  if (select count(*) from orders o where o.user_id = uid and o.created_at > now() - interval '1 hour') >= 10 then
    raise exception 'Too many orders. Please try again later.'; end if;

  create temporary table _cart on commit drop as
    select x.product_id, sum(x.quantity)::int as qty
    from jsonb_to_recordset(p_items) as x(product_id uuid, quantity int) group by x.product_id;

  select count(*) into v_expected from _cart;
  select count(*), count(*) filter (where c2.qty < 1 or c2.qty > 10), sum(p.price * c2.qty)
    into v_found, v_bad, v_sub
    from _cart c2 join products p on p.id = c2.product_id and p.is_active and p.stock_status <> 'out_of_stock';
  if v_found <> v_expected then raise exception 'One or more products are unavailable'; end if;
  if v_bad > 0 then raise exception 'Invalid quantity (1-10 per product)'; end if;

  if p_payment_method is not null and not exists (select 1 from payment_methods where code = p_payment_method and is_active) then
    raise exception 'Invalid payment method'; end if;

  if p_coupon is not null and trim(p_coupon) <> '' then
    select * into c from coupons where code = upper(trim(p_coupon)) for update;
    if not found or not c.is_active or (c.expires_at is not null and c.expires_at < now())
       or (c.usage_limit is not null and c.used_count >= c.usage_limit) or v_sub < c.minimum_order then
      raise exception 'Coupon is not valid for this order'; end if;
    v_disc := least(case c.discount_type when 'percent' then round(v_sub * c.discount_value / 100, 2) else c.discount_value end, v_sub);
    v_code := c.code;
    update coupons set used_count = used_count + 1 where id = c.id;
  end if;

  insert into orders (user_id, subtotal, discount, total, coupon_code, payment_method, payment_reference,
                      payment_status, customer_notes, idempotency_key)
  values (uid, v_sub, v_disc, v_sub - v_disc, v_code, p_payment_method, left(p_payment_reference, 200),
          case when coalesce(trim(p_payment_reference), '') <> '' then 'pending' else 'unpaid' end,
          left(p_notes, 2000), p_idempotency_key)
  returning * into v_order;   -- payment_status is NEVER 'paid' here; only an admin can verify

  insert into order_items (order_id, product_id, product_name, unit_price, quantity, subtotal)
  select v_order.id, p.id, p.name, p.price, c2.qty, p.price * c2.qty
  from _cart c2 join products p on p.id = c2.product_id;

  insert into notifications (user_id, title, message)
  values (uid, 'Order received', 'Order ' || v_order.order_number || ' was created and is awaiting payment verification.');

  return query select v_order.id, v_order.order_number, v_order.total;
end $$;
revoke all on function public.create_order(jsonb,text,text,text,text,text) from public, anon;
grant execute on function public.create_order(jsonb,text,text,text,text,text) to authenticated;
revoke all on function public.validate_coupon(text,numeric) from public;
grant execute on function public.validate_coupon(text,numeric) to authenticated;

-- Customer attaches a payment reference later; status becomes 'pending' (never 'paid')
create or replace function public.submit_payment_reference(p_order uuid, p_reference text)
returns void language plpgsql security definer set search_path = public as $$
begin
  update orders set payment_reference = left(trim(p_reference), 200), payment_status = 'pending'
  where id = p_order and user_id = auth.uid() and payment_status in ('unpaid','pending') and status <> 'cancelled';
  if not found then raise exception 'Order not found or not payable'; end if;
end $$;
revoke all on function public.submit_payment_reference(uuid,text) from public, anon;
grant execute on function public.submit_payment_reference(uuid,text) to authenticated;

-- Notify customers when an admin changes their order / request
create or replace function public.notify_order_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.status is distinct from old.status then
    insert into notifications (user_id, title, message)
    values (new.user_id, 'Order update', 'Order ' || new.order_number || ' is now ' || new.status || '.');
  end if;
  if new.payment_status is distinct from old.payment_status and new.payment_status in ('paid','refunded') then
    insert into notifications (user_id, title, message)
    values (new.user_id, 'Payment update', 'Payment for order ' || new.order_number || ' was marked ' || new.payment_status || '.');
  end if;
  return new;
end $$;
create trigger trg_notify_order after update on public.orders for each row execute function public.notify_order_change();

create or replace function public.notify_request_change() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if new.user_id is not null and new.status is distinct from old.status then
    insert into notifications (user_id, title, message)
    values (new.user_id, 'Custom project update', 'Your ' || new.project_type || ' request is now ' || new.status || '.');
  end if;
  return new;
end $$;
create trigger trg_notify_request after update on public.custom_requests for each row execute function public.notify_request_change();

-- Spam limit on custom requests (5 per email per hour)
create or replace function public.limit_requests() returns trigger language plpgsql security definer set search_path = public as $$
begin
  if (select count(*) from custom_requests where lower(customer_email) = lower(new.customer_email) and created_at > now() - interval '1 hour') >= 5 then
    raise exception 'Too many requests. Please try again later.'; end if;
  return new;
end $$;
create trigger trg_limit_requests before insert on public.custom_requests for each row execute function public.limit_requests();

-- Realtime (RLS still applies: users only receive rows they may select; admins receive all)
alter publication supabase_realtime add table public.orders, public.notifications, public.custom_requests;
