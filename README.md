# Mayo Store · Supabase setup (Phase 1)

## 1. Create the Supabase project
1. Go to https://supabase.com → **New project** (pick a region near your customers, save the database password).
2. Wait ~2 minutes until the project is ready.

## 2. Run the database SQL (pick ONE way)
**A. Dashboard (easiest):** open **SQL Editor → New query**, then paste and **Run** these files in order:
1. `supabase/migrations/001_schema.sql`
2. `supabase/migrations/002_rls_storage.sql`
3. `supabase/migrations/003_functions_realtime.sql`
4. `supabase/seed.sql` (imports your 12 current products, payment methods, default settings)

**B. CLI:**
```bash
npm i -g supabase            # or: npx supabase ...
supabase login
supabase link --project-ref YOUR-PROJECT-REF
supabase db push             # runs migrations
# then run seed.sql once in the SQL Editor
```
Migration 002 also creates the 3 storage buckets (`product-images`, `user-avatars`, `custom-project-files`) with size/type limits and policies. Check **Storage** in the dashboard to confirm.

## 3. Connect the frontend
1. Dashboard → **Project Settings → API Keys** (or **API**). Copy the **Project URL** and the **publishable / anon** key.
2. Paste both into `src/config/supabase.js` (and optionally `.env`; copy `.env.example`).
3. **Never** use the `service_role` / secret key in any browser file.
4. Serve the site over HTTP (ES modules don't work from `file://`):
   ```bash
   cd mayo-store
   python3 -m http.server 5173     # or: npx serve .
   ```
   Open http://localhost:5173
5. Test: in the browser console run
   ```js
   (await import("/src/config/supabase.js")).testConnection()
   ```
   You should see 3 products logged.

## 4. Authentication settings
Dashboard → **Authentication**:
- **Providers → Email**: enabled. Keep **Confirm email** ON (email verification).
- **URL Configuration**: Site URL = `http://localhost:5173` for now; add your live domain and `http://localhost:5173/**` to **Redirect URLs** (needed for password reset and verification links).
- Emails: the built-in mailer is rate-limited; add custom SMTP (Authentication → SMTP) before launch.

## 5. Create your admin account
1. Register normally on the site (Phase 2 adds the pages) or **Authentication → Users → Add user**.
2. In the SQL Editor run (use your email):
   ```sql
   insert into public.user_roles (user_id, role)
   select id, 'admin' from auth.users where email = 'you@example.com';
   ```
Admin rights live only in `user_roles`, which no API user can write. There is no hardcoded login.

## What Phase 1 gives you
| Area | What was built |
|---|---|
| Schema | All requested tables plus `user_roles`, `payment_methods`; constraints on prices, quantities, ratings, coupons |
| Security | RLS on every table; admin check via `is_admin()`; internal notes hidden from customers |
| Checkout | `create_order()` RPC: server-side prices, stock/active checks, coupon validation, atomic order + items, idempotency key, rate limit; never marks an order paid |
| Payments | Manual methods; customer may add a reference (status → `pending`); only admins can set `paid` |
| Notifications | Triggers on order/request status changes; Realtime enabled on `orders`, `notifications`, `custom_requests` |
| Storage | 3 buckets with policies (avatars per-user folder, project files private/signed URLs) |

## Notes for later phases
- Query orders/requests with explicit column lists (not `select('*')`), because `internal_notes` / `admin_notes` are protected. Admins read them with `rpc('admin_order_notes')` / `rpc('admin_request_notes')`.
- Customer checkout call:
  `supabase.rpc('create_order', { p_items: [{product_id, quantity}], p_coupon, p_payment_method, p_payment_reference, p_notes, p_idempotency_key: crypto.randomUUID() })`
- Coupon preview: `supabase.rpc('validate_coupon', { p_code, p_subtotal })`.
- `site_settings` is publicly readable: never store secrets there.

## Next phases
2 Auth pages + profiles → 3 dynamic products → 4 cart/checkout wiring → 5 customer dashboard → 6 admin panel → 7 uploads/requests → 8 realtime UI → 9 security tests & deploy.

---
## Phase 2–9 build notes
- Pages: `auth.html` (sign in / register / forgot / reset), `dashboard.html` (overview, orders, profile+avatar, notifications), `admin/index.html` (overview, products+image upload, orders+payment verification, customers, requests, coupons, settings). `index.html` now loads live products, runs checkout through `create_order()`, and posts custom requests.
- Until you paste your keys into `src/config/supabase.js`, the storefront keeps its demo products and checkout shows a setup hint.
- Security test checklist: (1) as a normal user, `supabase.from('user_roles').insert(...)` must fail; (2) `update orders set payment_status='paid'` from a customer must fail; (3) `select internal_notes from orders` must fail; (4) open `/admin/` signed out or as a customer: access denied.
- Deploy: any static host (Netlify, Vercel, Cloudflare Pages); add the live URL to Auth → Redirect URLs.
