import { supabase } from "../config/supabase.js";
import { validImage } from "../utils/format.js";
export async function uploadPublic(bucket, path, file, max) { if (!validImage(file, max)) throw new Error("PNG/JPG/WebP only, within the size limit"); const { error } = await supabase.storage.from(bucket).upload(path, file, { upsert: true, contentType: file.type }); if (error) throw error; return supabase.storage.from(bucket).getPublicUrl(path).data.publicUrl; }
export const uploadAvatar = (uid, file) => uploadPublic("user-avatars", `${uid}/avatar.${file.type.split("/")[1]}`, file, 2097152);
export const uploadProductImage = (slug, file) => uploadPublic("product-images", `${slug}-${Date.now()}.${file.type.split("/")[1]}`, file, 5242880);
// Private project files: owner uploads into their own uid folder; read through short-lived signed URLs.
export async function uploadProjectFile(uid, file) { const path = `${uid}/${Date.now()}-${file.name.replace(/[^\w.-]/g, "_")}`; const { error } = await supabase.storage.from("custom-project-files").upload(path, file); if (error) throw error; return path; }
export const signedUrl = async path => (await supabase.storage.from("custom-project-files").createSignedUrl(path, 300)).data?.signedUrl;
