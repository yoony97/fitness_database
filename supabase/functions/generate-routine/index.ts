
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface RequestData {
    user_id: string;
    target_muscle_groups?: string[];
    duration_minutes?: number;
    goal?: string;
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

        const body: RequestData = await req.json();
        const { user_id, target_muscle_groups, duration_minutes = 60, goal = "muscle_building" } = body;

        console.log(`[GenerateRoutine] Request started for user: ${user_id}`);
        console.log(`[GenerateRoutine] Params: targets=${target_muscle_groups}, duration=${duration_minutes}, goal=${goal}`);

        if (!user_id) throw new Error("Missing user_id");

        // 1. Fetch User Data
        const { data: equipmentData, error: equipError } = await supabase
            .from("user_equipment")
            .select("equipment_type")
            .eq("user_id", user_id)
            .eq("is_available", true);

        if (equipError) console.error("[GenerateRoutine] Equipment fetch error:", equipError);

        const availableEquipment = equipmentData?.map(e => e.equipment_type) || [];
        if (availableEquipment.length === 0) {
            console.log("[GenerateRoutine] No equipment registered. Falling back to body-weight.");
            availableEquipment.push("body-weight");
        }

        // 2. Select Exercises with Fallback
        const normalizedTargets = target_muscle_groups?.map(t => t.toLowerCase()) || [];
        const totalToSelect = Math.max(3, Math.floor(duration_minutes / 10));

        let { data: exercises, error: exerciseError } = await supabase.from("exercises")
            .select("*")
            .in("equipment", availableEquipment)
            .overlaps("muscle_groups", normalizedTargets);

        // Fallback A: If no exercises found with specific muscles, try searching just by equipment
        if (!exercises || exercises.length === 0) {
            console.log("[GenerateRoutine] No exercises found for specific muscles. Relaxing muscle filter.");
            const { data: fallbackEx } = await supabase.from("exercises")
                .select("*")
                .in("equipment", availableEquipment)
                .limit(20);
            exercises = fallbackEx;
        }

        // Fallback B: If STILL no exercises, pick anything
        if (!exercises || exercises.length === 0) {
            console.log("[GenerateRoutine] Still no exercises. Picking top 10 random exercises.");
            const { data: absoluteFallback } = await supabase.from("exercises")
                .select("*")
                .limit(10);
            exercises = absoluteFallback;
        }

        if (exerciseError) throw exerciseError;
        if (!exercises || exercises.length === 0) throw new Error("Exercises table seems empty");

        // 3. Selection Algorithm
        const selectedExercises = selectExercises(exercises, totalToSelect);
        console.log(`[GenerateRoutine] Selected ${selectedExercises.length} exercises.`);


        // 4. Construct Response matching WorkoutRoutine domain type
        const routineCategory = (goal === 'cardio' || goal === 'endurance') ? 'cardio' : 'strength';

        const routine = {
            name: `AI Generated ${goal} Workout`,
            description: `Focus on ${target_muscle_groups?.join(", ") || "Full Body"}`,
            estimatedDuration: duration_minutes,
            category: routineCategory,
            difficultyLevel: 'intermediate', // Default to intermediate for now
            isPublic: false,
            isFavorite: false,
            exercises: selectedExercises.map((ex, index) => ({
                exerciseId: ex.id,
                orderIndex: index,
                sets: 3,
                reps: 10,
                restTime: 60,
                notes: (ex.tips_ko && ex.tips_ko.length > 0) ? ex.tips_ko[0] : "",
                exercise: {
                    exerciseId: ex.id,
                    name: ex.exercise_name,
                    nameKo: ex.exercise_name_ko,
                    video: ex.video_path,
                    thumbnail: ex.thumbnail_path,
                    icon: ex.icon_path,

                    // Essential fields for ExerciseMinimal/Exercise
                    primaryMuscle: ex.primary_muscle || 'full-body',
                    type: ex.type || 'strength',
                    difficultyLevel: ex.difficulty_level?.toLowerCase() || 'intermediate'
                }
            }))
        };

        return new Response(JSON.stringify(routine), {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });

    } catch (error) {
        const errMsg = error instanceof Error ? error.message : String(error);
        console.error("[GenerateRoutine] Fatal Error:", errMsg);
        return new Response(JSON.stringify({ error: errMsg }), {
            status: 400,
            headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
    }
});

function selectExercises(allExercises: any[], count: number) {
    const compounds = allExercises.filter(e => e.mechanics === 'compound');
    const isolations = allExercises.filter(e => e.mechanics !== 'compound');

    const result: any[] = [];
    compounds.sort((a, b) => (b.popularity_score || 0) - (a.popularity_score || 0));
    isolations.sort((a, b) => (b.popularity_score || 0) - (a.popularity_score || 0));

    const mainCount = Math.min(compounds.length, Math.max(1, Math.floor(count * 0.4)));
    result.push(...compounds.slice(0, mainCount));

    const remaining = count - result.length;
    result.push(...isolations.slice(0, remaining));

    if (result.length < count) {
        const usedIds = new Set(result.map(r => r.id));
        const others = allExercises.filter(e => !usedIds.has(e.id));
        result.push(...others.slice(0, count - result.length));
    }

    return result.sort((a, b) => {
        if (a.mechanics === 'compound' && b.mechanics !== 'compound') return -1;
        if (a.mechanics !== 'compound' && b.mechanics === 'compound') return 1;
        return 0;
    });
}
