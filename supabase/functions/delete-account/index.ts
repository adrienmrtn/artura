// Deletes the signed-in user's account (App Store rule: an app that creates accounts must let users delete them).
// The caller is identified by their own session token; user_progress is removed by the foreign key (on delete cascade).
Deno.serve(async (req: Request) => {
  if (req.method !== "POST") return new Response("method", { status: 405 });
  const url = Deno.env.get("SUPABASE_URL")!;
  const service = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const auth = req.headers.get("Authorization") ?? "";

  const me = await fetch(`${url}/auth/v1/user`, { headers: { Authorization: auth, apikey: service } });
  if (!me.ok) return Response.json({ ok: false, error: "unauthorized" }, { status: 401 });
  const { id } = await me.json();
  if (!id) return Response.json({ ok: false, error: "unauthorized" }, { status: 401 });

  const removed = await fetch(`${url}/auth/v1/admin/users/${id}`, {
    method: "DELETE",
    headers: { Authorization: `Bearer ${service}`, apikey: service },
  });
  if (!removed.ok) return Response.json({ ok: false, error: await removed.text() }, { status: 500 });
  return Response.json({ ok: true });
});
