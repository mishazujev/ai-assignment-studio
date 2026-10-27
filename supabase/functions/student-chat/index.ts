import { askOpenAI, corsHeaders, reply, requireUser } from "../_shared/ai.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  try {
    const { client, user } = await requireUser(request);
    const body = await request.json();
    const assignmentId = String(body.assignmentId ?? "");
    const content = String(body.message ?? "").trim();
    if (!assignmentId || !content || content.length > 1500) return reply({ error: "Provide an assignment and a message under 1,500 characters." }, 400);

    const { data: assignment, error: assignmentError } = await client.from("assignments")
      .select("id,title,topic,instructions").eq("id", assignmentId).single();
    if (assignmentError || !assignment) return reply({ error: "Assignment not found or you are not a group member." }, 404);

    let { data: conversation } = await client.from("conversations").select("id")
      .eq("assignment_id", assignmentId).eq("user_id", user.id).maybeSingle();
    if (!conversation) {
      const created = await client.from("conversations").insert({ assignment_id: assignmentId, user_id: user.id }).select("id").single();
      if (created.error) return reply({ error: created.error.message }, 400);
      conversation = created.data;
    }
    const savedUserMessage = await client.from("messages").insert({ conversation_id: conversation.id, user_id: user.id, role: "user", content });
    if (savedUserMessage.error) return reply({ error: savedUserMessage.error.message }, 400);

    const { data: history, error: historyError } = await client.from("messages").select("role,content")
      .eq("conversation_id", conversation.id).eq("user_id", user.id)
      .order("created_at", { ascending: true }).limit(30);
    if (historyError) return reply({ error: historyError.message }, 400);
    const system = "You are a thoughtful Socratic classroom coach for secondary-school students. Help the learner explore ideas and understand the assignment. Ask concise, useful questions; point out possible perspectives and trade-offs. Do not write their final group answer or fabricate facts. Do not request sensitive personal information. Keep language age-appropriate. Assignment: " + JSON.stringify(assignment);
    const answer = await askOpenAI(system, history ?? []);
    const savedAssistantMessage = await client.from("messages").insert({ conversation_id: conversation.id, user_id: user.id, role: "assistant", content: answer });
    if (savedAssistantMessage.error) return reply({ error: savedAssistantMessage.error.message }, 400);
    return reply({ conversationId: conversation.id, answer });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Request failed";
    return reply({ error: message }, message === "Sign in is required" ? 401 : 500);
  }
});
