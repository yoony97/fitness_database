
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface RequestData {
    user_id: string;
    target_muscle_groups?: string[];
    duration_minutes?: number; // default 60
    goal?: string; // strength, muscle_building, endurance
}

serve(async (req) => {
    if (req.method === "OPTIONS") {
        return new Response("ok", { headers: corsHeaders });
    }

    try {
        const supabase = createClient(
            Deno.env.get("SUPABASE_URL") ?? "",
            Deno.env.get("SUPABASE_ANON_KEY") ?? ""
        );

        const { user_id, target_muscle_groups, duration_minutes = 60, goal = "muscle_building" }: RequestData = await req.json();

        if (!user_id) {
            throw new Error("Missing user_id");
        }

        // 1. Fetch User Data (Equipment, 1RM, History)
        // We'll fetch equipment first.
        const { data: equipmentData } = await supabase
            .from("user_equipment")
            .select("equipment_type")
            .eq("user_id", user_id)
            .eq("is_available", true);

        const availableEquipment = equipmentData?.map(e => e.equipment_type) || [];
        // If no equipment found, assume 'body-weight' at minimum
        if (availableEquipment.length === 0) availableEquipment.push("body-weight");

        // 2. Determine Structure based on goal & duration
        // Simple logic: Warmup -> 1-2 Main Compounds -> 2-3 Accessories -> 1 Core/Cardio
        const totalExercises = Math.floor(duration_minutes / 10); // roughly 10 mins per exercise including rest

        // 3. Select Exercises
        // Strategy: 
        // - Select Main Movement (Compound, High Fatigue) matching target muscles
        // - Select Accessories (Isolation, Lower Fatigue) matching target muscles

        // Normalize targets to lowercase to match DB data
        const normalizedTargets = target_muscle_groups?.map(t => t.toLowerCase()) || [];

        let query = supabase.from("exercises")
            .select("*")
            .in("equipment", availableEquipment);

        if (normalizedTargets.length > 0) {
            // Postgres array overlap (&&) is case-sensitive, so we use normalized list
            query = query.overlaps("muscle_groups", normalizedTargets);
        }

        const { data: exercises, error: exerciseError } = await query;

        if (exerciseError) throw exerciseError;

        // Filter logic (Algorithm)
        const selectedExercises = selectExercises(exercises || [], totalExercises, target_muscle_groups);

        // 4. Construct Routine Object
        const routine = {
            name: `AI Generated ${goal} Workout`,
            description: `Focus on ${target_muscle_groups?.join(", ") || "Full Body"}`,
            estimated_duration: duration_minutes,
            exercises: selectedExercises.map((ex, index) => ({
                exercise_id: ex.id,
                exercise_name: ex.exercise_name,
                exercise_name_ko: ex.exercise_name_ko,
                sets: 3, // Default, logic to improve later
                reps: 10,
                order_index: index,
                rest_time: 60,
                tips: ex.tips_ko?.[0] || ""
            }))
        };

        return new Response(JSON.stringify(routine), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });

    } catch (error) {
        return new Response(JSON.stringify({ error: error.message }), {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }
});

// Helper Algorithm Logic
function selectExercises(allExercises: any[], count: number, targets?: string[]) {
    // 1. Separate Compounds and Isolations
    const compounds = allExercises.filter(e => e.mechanics === 'compound');
    const isolations = allExercises.filter(e => e.mechanics === 'isolation');

    const result: any[] = [];

    // 2. Pick 1-2 Compounds (Priority)
    // Sort by popularity or tier
    compounds.sort((a, b) => (b.popularity_score || 0) - (a.popularity_score || 0));

    const mainCount = Math.min(2, Math.floor(count * 0.4)); // 40% are compounds
    for (let i = 0; i < mainCount; i++) {
        if (compounds.length > i) result.push(compounds[i]);
    }

    // 3. Filli with Isolations
    isolations.sort((a, b) => (b.popularity_score || 0) - (a.popularity_score || 0));

    const remainingCount = count - result.length;
    for (let i = 0; i < remainingCount; i++) {
        // Try to pick different movement patterns if possible, for now just simple pick
        if (isolations.length > i) result.push(isolations[i]);
    }

    // Fallback if not enough isolations, add more compounds
    if (result.length < count) {
        const moreCompounds = compounds.slice(mainCount, mainCount + (count - result.length));
        result.push(...moreCompounds);
    }

    return result;
}
