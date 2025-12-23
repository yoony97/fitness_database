
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        const supabase = createClient(
            Deno.env.get("SUPABASE_URL") ?? "",
            Deno.env.get("SUPABASE_ANON_KEY") ?? ""
        );

        const { user_id, exercise_id, target_reps = 10 } = await req.json();

        if (!user_id || !exercise_id) {
            throw new Error("Missing user_id or exercise_id");
        }

        // 1. Fetch User 1RM
        // The one_rep_max column is likely JSONB: { "Bench Press": 100, "Squat": 140 }
        // OR we need to fetch the exercise name first to look it up.
        // Let's fetch exercise name + user profile.

        // Fetch Exercise Name
        const { data: exerciseData } = await supabase
            .from("exercises")
            .select("exercise_name, equipment")
            .eq("id", exercise_id)
            .single();

        if (!exerciseData) throw new Error("Exercise not found");

        const exerciseName = exerciseData.exercise_name;
        const equipment = exerciseData.equipment;

        // Fetch User Profile
        const { data: userData } = await supabase
            .from("user_profiles")
            .select("one_rep_max")
            .eq("id", user_id)
            .single();

        let estimated1RM = 0;
        let method = "none"; // '1rm_data', 'recent_log', 'default'

        // Strategy A: Check explicit 1RM data
        if (userData?.one_rep_max && userData.one_rep_max[exerciseName]) {
            estimated1RM = Number(userData.one_rep_max[exerciseName]);
            method = "known_1rm";
        }

        // Strategy B: If no 1RM, look at recent logs to estimate it
        if (!estimated1RM) {
            // Fetch last 5 logs for this exercise, ordered by newest
            const { data: logs } = await supabase
                .from("exercise_logs")
                .select("weight_used, reps_completed")
                .eq("user_id", user_id)
                .eq("exercise_id", exercise_id)
                .order("created_at", { ascending: false })
                .limit(5);

            if (logs && logs.length > 0) {
                // Calculate best e1RM from logs
                let bestE1RM = 0;
                for (const log of logs) {
                    // arrays of sets. Pick best set.
                    if (Array.isArray(log.weight_used) && Array.isArray(log.reps_completed)) {
                        for (let i = 0; i < log.weight_used.length; i++) {
                            const w = Number(log.weight_used[i]);
                            const r = Number(log.reps_completed[i]);
                            if (w > 0 && r > 0) {
                                // Epley Formula: 1RM = w * (1 + 0.0333 * r)
                                const e1rm = w * (1 + 0.0333 * r);
                                if (e1rm > bestE1RM) bestE1RM = e1rm;
                            }
                        }
                    }
                }
                if (bestE1RM > 0) {
                    estimated1RM = bestE1RM;
                    method = "estimated_from_history";
                }
            }
        }

        let recommendedWeight = 0;

        if (equipment === 'body-weight') {
            recommendedWeight = 0;
            method = "bodyweight_default";
        } else if (estimated1RM > 0) {
            // Inverse Epley: Weight = 1RM / (1 + 0.0333 * target_reps)
            // We usually target RPE 8-9, so maybe take 90% of that max theoretical rep weight?
            // Let's stick to simple formula first.
            recommendedWeight = estimated1RM / (1 + 0.0333 * target_reps);

            // Round to nearest 2.5kg (or lbs check later)
            recommendedWeight = Math.round(recommendedWeight / 2.5) * 2.5;
        } else {
            // Fallback for absolute beginner on this exercise
            recommendedWeight = 20; // Empty bar default? Or return null to let UI prompt user
            method = "default_beginner";
        }

        return new Response(JSON.stringify({
            recommended_weight: recommendedWeight,
            target_reps: target_reps,
            estimated_1rm: estimated1RM,
            calculation_method: method
        }), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }
});
