import { supabase } from "../config/supabase.js";
const COLS = "id,name,slug,description,short_description,category,subcategory,price,original_price,thumbnail_url,preview_url,features,technologies,is_featured,stock_status";
export const listProducts = async (category) => { let q = supabase.from("products").select(COLS).order("created_at"); if (category) q = q.eq("category", category); const { data, error } = await q; if (error) throw error; return data; };
export const getProduct = async slug => { const { data, error } = await supabase.from("products").select(COLS + ",product_images(image_url,display_order)").eq("slug", slug).single(); if (error) throw error; return data; };
export const searchProducts = async term => { const { data, error } = await supabase.from("products").select(COLS).or(`name.ilike.%${term.replace(/[%,]/g, "")}%,description.ilike.%${term.replace(/[%,]/g, "")}%`); if (error) throw error; return data; };
