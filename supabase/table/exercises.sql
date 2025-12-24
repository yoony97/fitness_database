-- =============================================
-- Enum Type Definitions
-- =============================================

-- Difficulty Rating
DO $$ BEGIN
    CREATE TYPE public.difficulty_rating_enum AS ENUM ('easy', 'normal', 'hard', 'extreme');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Difficulty Level
DO $$ BEGIN
    CREATE TYPE public.difficulty_level_enum AS ENUM ('beginner', 'intermediate', 'advanced');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Tier
DO $$ BEGIN
    CREATE TYPE public.tier_enum AS ENUM ('A', 'B', 'C', 'D', 'E', 'F', 'G');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Mechanics
DO $$ BEGIN
    CREATE TYPE public.mechanics_enum AS ENUM ('compound', 'isolation', 'isometric', 'static', 'hybrid');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Force
DO $$ BEGIN
    CREATE TYPE public.force_enum AS ENUM ('push', 'pull', 'static', 'hybrid');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Target Region
DO $$ BEGIN
    CREATE TYPE public.target_region_enum AS ENUM ('upper', 'lower', 'core', 'full_body');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Resistance Profile
DO $$ BEGIN
    CREATE TYPE public.resistance_profile_enum AS ENUM ('shortened', 'mid_range', 'lengthened');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Stability Level
DO $$ BEGIN
    CREATE TYPE public.stability_level_enum AS ENUM ('low', 'moderate', 'high');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Exercise Type
DO $$ BEGIN
    CREATE TYPE public.exercise_type_enum AS ENUM ('strength', 'cardio', 'plyometrics', 'powerlifting', 'stretching', 'strongman', 'olympic_weightlifting');
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Movement Pattern
DO $$ BEGIN
    CREATE TYPE public.movement_pattern_enum AS ENUM (
        'anti_extension', 'anti_flexion', 'anti_rotation', 'calves_isolation',
        'hinge_pattern', 'horizontal_pull', 'horizontal_push', 'isolation',
        'isolation_arms', 'isolation_glutes', 'isolation_hips', 'isolation_legs',
        'isolation_shoulders', 'lunge_pattern', 'rotation', 'squat_pattern',
        'vertical_pull', 'vertical_push'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Equipment
DO $$ BEGIN
    CREATE TYPE public.equipment_enum AS ENUM (
        'accessory', 'ball', 'band', 'barbell', 'body-weight',
        'cable', 'dumbbell', 'kettlebell', 'machine', 'rope', 'suspension'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

-- Muscle Group
DO $$ BEGIN
    CREATE TYPE public.muscle_group_enum AS ENUM (
        'back', 'biceps', 'calves', 'chest', 'core', 'forearms',
        'glutes', 'hamstrings', 'hips', 'quads', 'shoulders', 'triceps'
    );
EXCEPTION WHEN duplicate_object THEN null; END $$;

create table public.exercises (
  id uuid not null,
  exercise_name text not null,
  exercise_name_ko text not null,
  label text null,
  difficulty_rating public.difficulty_rating_enum null,
  difficulty_level public.difficulty_level_enum null default 'intermediate'::difficulty_level_enum,
  tier public.tier_enum null default 'C'::tier_enum,
  popularity_score integer null default 50,
  mechanics public.mechanics_enum null,
  force public.force_enum null,
  target_region public.target_region_enum null,
  movement_pattern public.movement_pattern_enum null,
  resistance_profile public.resistance_profile_enum null,
  systemic_fatigue integer null default 3,
  muscle_group_bias text null,
  rep_range_suitability text[] null,
  equipment public.equipment_enum null,
  unilateral boolean null default false,
  stability_level public.stability_level_enum null default 'moderate'::stability_level_enum,
  type public.exercise_type_enum null default 'strength'::exercise_type_enum,
  is_cardio boolean null default false,
  primary_muscle public.muscle_group_enum not null,
  muscle_groups text[] null,
  description_ko text null,
  instructions_ko text[] null,
  tips_ko text[] null,
  common_mistakes_ko text[] null,
  safety_tips_ko text[] null,
  notes text null,
  video_path text null,
  keywords text[] null,
  like_count integer null default 0,
  created_at timestamp with time zone null default now(),
  updated_at timestamp with time zone null default now(),
  thumbnail_path text null,
  icon_path text null,
  constraint exercises_v2_pkey primary key (id),
  constraint exercises_v2_exercise_name_key unique (exercise_name),
  constraint exercises_v2_systemic_fatigue_check check (
    (
      (systemic_fatigue >= 1)
      and (systemic_fatigue <= 5)
    )
  )
) TABLESPACE pg_default;

create index IF not exists idx_ex_v2_exercise_name on public.exercises using btree (exercise_name) TABLESPACE pg_default;

create index IF not exists idx_ex_v2_keywords on public.exercises using gin (keywords) TABLESPACE pg_default;

create index IF not exists idx_ex_v2_difficulty on public.exercises using btree (difficulty_level) TABLESPACE pg_default;

create index IF not exists idx_ex_v2_type on public.exercises using btree (type) TABLESPACE pg_default;

create index IF not exists idx_ex_v2_equipment on public.exercises using btree (equipment) TABLESPACE pg_default;

create index IF not exists idx_ex_v2_primary_muscle on public.exercises using btree (primary_muscle) TABLESPACE pg_default;