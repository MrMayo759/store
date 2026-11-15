// Mayo Store · Supabase client (browser).
// Paste your PUBLIC project URL + publishable/anon key. Safe to ship: Row Level Security protects the data.
// NEVER paste the service_role / secret key here.
import { createClient } from "https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.45.4/+esm";

export const SUPABASE_URL = "https://omnokjqkwpsdolrokdiz.supabase.co";
export const SUPABASE_KEY = "sb_publishable_EEYKRD9YDsqLxV0QxS5GYg_bITIQg4J";

export const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
});

// Run `await testConnection()` from the browser console to verify setup.
export async function testConnection() {
  const { data, error } = await supabase.from("products").select("name, price").limit(3);
  if (error) { console.error("Supabase error:", error.message); return false; }
  console.log("Connected. Sample products:", data);
  return true;
}
