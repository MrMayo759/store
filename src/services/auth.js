import { supabase } from "../config/supabase.js";
export const signUp = (email, password, name) => supabase.auth.signUp({ email, password, options: { data: { full_name: name }, emailRedirectTo: location.origin + "/auth.html" } });
export const signIn = (email, password) => supabase.auth.signInWithPassword({ email, password });
export const signOut = () => supabase.auth.signOut();
export const forgotPassword = email => supabase.auth.resetPasswordForEmail(email, { redirectTo: location.origin + "/auth.html" });
export const updatePassword = password => supabase.auth.updateUser({ password });
export const getUser = async () => (await supabase.auth.getSession()).data.session?.user || null;
export const onAuth = cb => supabase.auth.onAuthStateChange(cb);
