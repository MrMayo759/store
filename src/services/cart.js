const KEY = "mayo-cart";
export const loadCart = () => { try { const r = JSON.parse(localStorage.getItem(KEY) || "[]"); return Array.isArray(r) ? r.filter(x => x.id && x.q > 0) : []; } catch { return []; } };
export const saveCart = c => { try { localStorage.setItem(KEY, JSON.stringify(c)); } catch {} };
// Display-only total. The server recalculates everything in create_order().
export const cartTotal = (cart, products) => cart.reduce((a, x) => a + (products.find(p => p.id === x.id)?.p || 0) * x.q, 0);
export const toItems = cart => cart.map(x => ({ product_id: x.id, quantity: x.q }));
