CREATE OR REPLACE FUNCTION public.get_session_with_routine_data(p_session_id integer, p_routine_id integer)
 RETURNS json
 LANGUAGE plpgsql
AS $function$
DECLARE
  v_result JSON;
BEGIN
  SELECT JSON_BUILD_OBJECT(
    'session', JSON_BUILD_OBJECT(
      'id', ws.id,
      'user_id', ws.user_id,
      'routine_id', ws.routine_id,
      'started_at', ws.started_at,
      'completed_at', ws.completed_at
    ),
    'routine_exercises', (
      SELECT JSON_AGG(
        JSON_BUILD_OBJECT(
          'id', re.id,
          'routine_id', re.routine_id,
          'exercise_id', re.exercise_id,
          'sets', re.sets,
          'reps', re.reps,
          'weight', re.weight,
          'duration', re.duration,
          'rest_time', re.rest_time,
          'order_index', re.order_index,
          'notes', re.notes,
          'exercise', (
            SELECT JSON_BUILD_OBJECT(
              'id', e.id,
              'exercise_name_ko', e.exercise_name_ko,
              'exercise_name', e.exercise_name,
              'primary_muscle', e.primary_muscle,
              'video_path', e.video_path,
              'thumbnail_path', e.thumbnail_path,
              'icon_path', e.icon_path
            )
            FROM exercises e
            WHERE e.id = re.exercise_id
          )
        ) ORDER BY re.order_index ASC
      )
      FROM routine_exercises re
      WHERE re.routine_id = p_routine_id
    ),
    'exercise_logs', (
      SELECT COALESCE(JSON_AGG(
        JSON_BUILD_OBJECT(
          'id', el.id,
          'session_id', el.session_id,
          'exercise_id', el.exercise_id,
          'sets_completed', el.sets_completed,
          'reps_completed', el.reps_completed,
          'weight_used', el.weight_used,
          'duration', el.duration,
          'notes', el.notes,
          'completed_at', el.completed_at
        ) ORDER BY el.completed_at ASC
      ), '[]'::JSON)
      FROM exercise_logs el
      WHERE el.session_id = p_session_id
    )
  )
  INTO v_result
  FROM workout_sessions ws
  WHERE ws.id = p_session_id;

  RETURN COALESCE(v_result, '{}'::JSON);
END;
$function$;
