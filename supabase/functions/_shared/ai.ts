import { createClient } from "npm:@supabase/supabase-js@2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, apikey, content-type, x-client-info",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

export function reply(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function userClient(request: Request) {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_ANON_KEY") ??
    (() => {
      const keys = Deno.env.get("SUPABASE_PUBLISHABLE_KEYS");
      return keys ? JSON.parse(keys).default : undefined;
    })();
  if (!url || !key) throw new Error("Supabase function configuration is missing");
  return createClient(url, key, {
    global: { headers: { Authorization: request.headers.get("Authorization") ?? "" } },
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

export async function askOpenAI(instructions: string, input: Array<{ role: string; content: string }>) {
  const apiKey = Deno.env.get("OPENAI_API_KEY");
  const model = Deno.env.get("OPENAI_MODEL");
  if (!apiKey || !model) throw new Error("Set OPENAI_API_KEY and OPENAI_MODEL in Supabase function secrets");
  const response = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json" },
    body: JSON.stringify({ model, instructions, input, store: false }),
  });
  const data = await response.json();
  if (!response.ok) throw new Error(data?.error?.message ?? "The AI service request failed");
  const text = (data.output ?? []).flatMap((item: { content?: Array<{ type: string; text?: string }> }) => item.content ?? [])
    .filter((item: { type: string }) => item.type === "output_text")
    .map((item: { text?: string }) => item.text ?? "").join("\n").trim();
  if (!text) throw new Error("The AI service returned an empty response");
  return text;
}

export async function requireUser(request: Request) {
  const client = userClient(request);
  const { data, error } = await client.auth.getUser();
  if (error || !data.user) throw new Error("Sign in is required");
  return { client, user: data.user };
}
