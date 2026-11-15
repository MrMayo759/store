import { supabase } from "../config/supabase.js";
export const ORDER_COLS = "id,order_number,subtotal,discount,total,coupon_code,status,payment_status,payment_method,payment_reference,customer_notes,created_at";
export const createOrder = async (items, o = {}) => { const { data, error } = await supabase.rpc("create_order", { p_items: items, p_coupon: o.coupon || null, p_payment_method: o.method || null, p_payment_reference: o.ref || null, p_notes: o.notes || null, p_idempotency_key: o.key || crypto.randomUUID() }); if (error) throw error; return data[0]; };
export const validateCoupon = async (code, subtotal) => (await supabase.rpc("validate_coupon", { p_code: code, p_subtotal: subtotal })).data;
export const myOrders = async () => { const { data, error } = await supabase.from("orders").select(ORDER_COLS + ",order_items(product_name,unit_price,quantity)").order("created_at", { ascending: false }); if (error) throw error; return data; };
export const submitReference = (order, reference) => supabase.rpc("submit_payment_reference", { p_order: order, p_reference: reference });
