import { askOpenAI, corsHeaders, reply, requireUser } from "../_shared/ai.ts";

Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return reply({ error: "Method not allowed" }, 405);
  try {
    const { client, user } = await requireUser(request);
    const { data: profile, error: profileError } = await client.from("profiles").select("role").eq("id", user.id).single();
    if (profileError || profile?.role !== "teacher") return reply({ error: "Teacher access is required." }, 403);
    const body = await request.json();
    const submissionId = String(body.submissionId ?? "");
    if (!submissionId) return reply({ error: "A submission ID is required." }, 400);
    const { data: submission, error: submissionError } = await client.from("submissions")
      .select("id,content,group_id").eq("id", submissionId).single();
    if (submissionError || !submission) return reply({ error: "Submission not found or not available to this teacher." }, 404);
    const { data: group } = await client.from("groups").select("assignment_id,name").eq("id", submission.group_id).single();
    if (!group) return reply({ error: "Group not found." }, 404);
    const { data: assignment } = await client.from("assignments").select("title,topic,instructions")
      .eq("id", group.assignment_id).single();
    if (!assignment) return reply({ error: "Assignment not found." }, 404);

    const review = await askOpenAI(
      "You are assisting a teacher reviewing a student group assignment. Give balanced, age-appropriate feedback and a proposed revision that preserves the students' core ideas. Do not invent evidence or facts. Clearly label these sections: Strengths, Questions for the teacher, Suggested revision. The teacher will decide what to share or use.",
      [{ role: "user", content: JSON.stringify({ assignment, group: group.name, studentSubmission: submission.content }) }],
    );
    const { data: saved, error: saveError } = await client.from("ai_reviews").upsert({
      submission_id: submission.id,
      teacher_id: user.id,
      review_text: review,
    }, { onConflict: "submission_id" }).select("id,review_text,created_at").single();
    if (saveError) return reply({ error: saveError.message }, 400);
    return reply(saved);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Request failed";
    return reply({ error: message }, message === "Sign in is required" ? 401 : 500);
  }
});
