CREATE OR REPLACE FUNCTION public.get_session_complete_summary(p_session_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_user_id UUID;
    v_prev_session_id INTEGER;
    v_current_volume NUMERIC := 0;
    v_prev_volume NUMERIC := 0;
    v_volume_diff NUMERIC := 0;
    v_duration INTEGER;
    v_calories INTEGER;
    v_started_at TIMESTAMPTZ;
    v_summary JSON;
    v_muscle_analysis JSON;
    v_highlights JSON;
    v_exercises JSON;
BEGIN
    -- 1. Get Session Info
    SELECT user_id, total_duration, calories_burned, started_at
    INTO v_user_id, v_duration, v_calories, v_started_at
    FROM workout_sessions
    WHERE id = p_session_id;

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Session not found';
    END IF;

    -- 2. Calculate Current Volume
    WITH expanded_logs AS (
        SELECT 
            unnest(el.weight_used) as weight,
            unnest(el.reps_completed) as reps
        FROM exercise_logs el
        WHERE el.session_id = p_session_id
    )
    SELECT COALESCE(SUM(weight * reps), 0)
    INTO v_current_volume
    FROM expanded_logs;

    -- 3. Find Previous Session & Volume
    SELECT id INTO v_prev_session_id
    FROM workout_sessions
    WHERE user_id = v_user_id
      AND completed_at < v_started_at
      AND is_completed = true
    ORDER BY completed_at DESC
    LIMIT 1;

    IF v_prev_session_id IS NOT NULL THEN
        WITH prev_expanded_logs AS (
            SELECT 
                unnest(el.weight_used) as weight,
                unnest(el.reps_completed) as reps
            FROM exercise_logs el
            WHERE el.session_id = v_prev_session_id
        )
        SELECT COALESCE(SUM(weight * reps), 0)
        INTO v_prev_volume
        FROM prev_expanded_logs;
        
        v_volume_diff := v_current_volume - v_prev_volume;
    ELSE
        v_volume_diff := 0;
    END IF;

    -- 4. Muscle Analysis
    WITH session_muscles AS (
        SELECT 
            e.primary_muscle::text as muscle_name,
            SUM(u.weight * u.reps) as muscle_volume
        FROM exercise_logs el
        JOIN exercises e ON el.exercise_id = e.id  -- Fixed: e.id (was e.exercise_id)
        CROSS JOIN LATERAL unnest(el.weight_used, el.reps_completed) as u(weight, reps)
        WHERE el.session_id = p_session_id
        GROUP BY e.primary_muscle
    ),
    total_vol AS (
        SELECT SUM(muscle_volume) as total FROM session_muscles
    )
    SELECT json_agg(json_build_object(
        'muscle', muscle_name,
        'volume', muscle_volume,
        'percentage', CASE WHEN total > 0 THEN ROUND(((muscle_volume / total) * 100)::numeric, 1) ELSE 0 END
    ))
    INTO v_muscle_analysis
    FROM session_muscles, total_vol;

    -- 5. Exercises & PRs
    WITH current_session_stats AS (
        SELECT 
            el.exercise_id,
            e.exercise_name_ko as name, -- Fixed: e.exercise_name_ko (was e.name_ko)
            MAX(u.weight) as max_weight,
            SUM(u.weight * u.reps) as total_volume,
            MAX(el.sets_completed) as sets_count
        FROM exercise_logs el
        JOIN exercises e ON el.exercise_id = e.id -- Fixed: e.id (was e.exercise_id)
        CROSS JOIN LATERAL unnest(el.weight_used, el.reps_completed) as u(weight, reps)
        WHERE el.session_id = p_session_id
        GROUP BY el.exercise_id, e.exercise_name_ko -- Fixed: e.exercise_name_ko
    ),
    previous_stats AS (
        SELECT 
            el.exercise_id,
            MAX(u.weight) as prev_max_weight
        FROM exercise_logs el
        JOIN workout_sessions ws ON el.session_id = ws.id
        CROSS JOIN LATERAL unnest(el.weight_used, el.reps_completed) as u(weight, reps)
        WHERE ws.user_id = v_user_id
          AND ws.completed_at < v_started_at
          AND ws.is_completed = true
          AND el.exercise_id IN (SELECT exercise_id FROM current_session_stats)
        GROUP BY el.exercise_id
    )
    SELECT json_agg(json_build_object(
        'name', css.name,
        'sets', css.sets_count,
        'best_weight', css.max_weight,
        'total_volume', css.total_volume,
        'is_pr', CASE WHEN css.max_weight > COALESCE(ps.prev_max_weight, 0) THEN true ELSE false END,
        'prev_best', COALESCE(ps.prev_max_weight, 0)
    ))
    INTO v_exercises
    FROM current_session_stats css
    LEFT JOIN previous_stats ps ON css.exercise_id = ps.exercise_id;

    -- 6. Highlights (PRs)
    SELECT json_agg(json_build_object(
        'type', 'PR',
        'exercise_name', elem->>'name',
        'prev_weight', elem->>'prev_best',
        'curr_weight', elem->>'best_weight'
    ))
    INTO v_highlights
    FROM json_array_elements(v_exercises) elem
    WHERE (elem->>'is_pr')::boolean = true;

    -- Construct Final JSON
    v_summary := json_build_object(
        'duration_minutes', ROUND(COALESCE(v_duration, 0) / 60.0),
        'total_volume_kg', v_current_volume,
        'volume_diff_kg', v_volume_diff,
        'burned_calories', COALESCE(v_calories, 0)
    );

    RETURN json_build_object(
        'summary', v_summary,
        'muscle_analysis', COALESCE(v_muscle_analysis, '[]'::json),
        'highlights', COALESCE(v_highlights, '[]'::json),
        'exercises', COALESCE(v_exercises, '[]'::json)
    );
END;
$function$;
