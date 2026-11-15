// Placeholder for a FUTURE payment provider (Stripe, PayPal, ...). Not active: returns 501 until you implement it.
// Rules when you do: verify the provider's webhook SIGNATURE first, keep secrets in `supabase secrets set`, and only then
// use the service-role client (server-side only) to set orders.payment_status = 'paid'. Never trust the browser.
Deno.serve(() => new Response(JSON.stringify({ error: "Payment provider not configured" }), { status: 501, headers: { "Content-Type": "application/json" } }));
