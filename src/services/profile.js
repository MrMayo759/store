import { supabase } from "../config/supabase.js";
import { uploadAvatar } from "./storage.js";
export const getProfile = async uid => (await supabase.from("profiles").select("*").eq("id", uid).single()).data;
export const updateProfile = (uid, f) => supabase.from("profiles").update({ full_name: f.full_name || null, username: f.username || null, phone: f.phone || null }).eq("id", uid);
export async function setAvatar(uid, file) { const url = (await uploadAvatar(uid, file)) + "?t=" + Date.now(); await supabase.from("profiles").update({ avatar_url: url }).eq("id", uid); return url; }
