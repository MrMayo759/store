export const esc = s => String(s ?? "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
export const fmt = n => "$" + Number(n || 0).toFixed(2);
export const date = d => new Date(d).toLocaleString();
export const isEmail = v => /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(v);
export const validImage = (f, max = 5242880) => /^image\/(png|jpeg|webp)$/.test(f.type) && f.size <= max;
