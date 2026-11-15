import { supabase } from "../config/supabase.js";
export { supabase };
export const $ = (s, r = document) => r.querySelector(s);
export const $$ = (s, r = document) => [...r.querySelectorAll(s)];
export { esc, fmt, date } from "../utils/format.js";
export function toast(m) { const t = document.createElement("div"); t.className = "toast"; t.textContent = m; document.body.append(t); setTimeout(() => t.remove(), 2800); }
export const user = async () => (await supabase.auth.getSession()).data.session?.user || null;
export async function need(page = "auth.html") { const u = await user(); if (!u) location.href = page + "?next=" + encodeURIComponent(location.pathname); return u; }
export async function isAdmin() { const u = await user(); if (!u) return false; const { data } = await supabase.from("user_roles").select("role").eq("user_id", u.id).eq("role", "admin"); return !!data?.length; }
export const ORDER_COLS = "id,order_number,subtotal,discount,total,coupon_code,status,payment_status,payment_method,payment_reference,customer_notes,created_at";
export async function checkout(items, o) {
  const { data, error } = await supabase.rpc("create_order", { p_items: items, p_coupon: o.coupon || null, p_payment_method: o.method || null, p_payment_reference: o.ref || null, p_notes: o.notes || null, p_idempotency_key: o.key });
  if (error) throw error; return data[0];
}
export function tabs(el, views, start) {
  const go = async k => { $$("button", el).forEach(b => b.classList.toggle("on", b.dataset.t === k)); const v = $("#v"); v.innerHTML = '<p class="mu">Loading…</p>'; try { await views[k](v); } catch (e) { v.innerHTML = `<p class="msg">${esc(e.message)}</p>`; } };
  el.onclick = e => e.target.dataset.t && go(e.target.dataset.t); go(start || Object.keys(views)[0]); return go;
}
