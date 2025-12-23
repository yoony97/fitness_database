-- =========================================
-- 피트니스 앱 통합 데이터베이스 스키마
-- =========================================
-- 통합: auth + 메인 스키마 + 목표 + 통계함수
-- ALTER 변경사항 모두 반영 완료
-- =========================================

-- 확장 기능 활성화
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";  -- 텍스트 검색 최적화

-- =========================================
-- 1. 사용자 관리 (User Management)
-- =========================================

-- 사용자 프로필 (auth.users와 1:1 관계)
CREATE TABLE IF NOT EXISTS public.user_profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT UNIQUE,
    full_name TEXT,
    avatar_url TEXT,
    bio TEXT,
    birth_date DATE,
    gender TEXT CHECK (gender IN ('male', 'female', 'other')),
    height INTEGER, -- cm
    weight FLOAT,   -- kg
    muscle_mass FLOAT, -- kg (신체 구성)
    body_fat_percentage FLOAT, -- % (신체 구성)
    activity_level TEXT CHECK (activity_level IN ('sedentary', 'lightly_active', 'moderately_active', 'very_active')),
    fitness_goal TEXT CHECK (fitness_goal IN ('weight_loss', 'muscle_gain', 'maintenance', 'endurance')),
    timezone TEXT DEFAULT 'Asia/Seoul',
    has_completed_onboarding BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 사용자 설정
CREATE TABLE IF NOT EXISTS public.user_preferences (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    theme TEXT DEFAULT 'system' CHECK (theme IN ('light', 'dark', 'system')),
    language TEXT DEFAULT 'ko' CHECK (language IN ('ko', 'en')),
    measurement_system TEXT DEFAULT 'metric' CHECK (measurement_system IN ('metric', 'imperial')),
    notifications_enabled BOOLEAN DEFAULT true,
    workout_reminders BOOLEAN DEFAULT true,
    diet_reminders BOOLEAN DEFAULT true,
    running_audio_cues BOOLEAN DEFAULT true,
    privacy_profile TEXT DEFAULT 'public' CHECK (privacy_profile IN ('public', 'friends', 'private')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id)
);

-- 사용자 목표 설정
CREATE TABLE user_goals (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,

    -- 일일 목표
    daily_calorie_goal INTEGER NOT NULL DEFAULT 2000,
    daily_steps_goal INTEGER NOT NULL DEFAULT 8000,
    daily_water_goal INTEGER NOT NULL DEFAULT 8, -- 잔 단위 (1잔 = 250ml)
    daily_workout_time_goal INTEGER NOT NULL DEFAULT 30, -- 분 단위

    -- 주간 목표
    weekly_workout_goal INTEGER NOT NULL DEFAULT 3, -- 주간 운동 횟수

    -- 체중 관리
    weight DECIMAL(5,2), -- 현재 체중 (kg)
    target_weight DECIMAL(5,2), -- 목표 체중 (kg)
    body_fat_percentage DECIMAL(4,1), -- 현재 체지방률 (%)
    target_body_fat_percentage DECIMAL(4,1), -- 목표 체지방률 (%)

    -- 사용자 특성
    activity_level TEXT NOT NULL DEFAULT 'lightly_active'
        CHECK (activity_level IN ('sedentary', 'lightly_active', 'moderately_active', 'very_active')),
    fitness_goal TEXT NOT NULL DEFAULT 'maintenance'
        CHECK (fitness_goal IN ('weight_loss', 'muscle_gain', 'maintenance', 'endurance')),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE(user_id)
);

-- =========================================
-- 2. 운동 관리 (Workout Management)
-- =========================================

-- 운동 카테고리
CREATE TABLE exercise_categories (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    color TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 운동 정보 (ALTER 변경사항 반영: icon_url, met_value, tips, common_mistakes, variations)
CREATE TABLE exercises (
    id SERIAL PRIMARY KEY,
    category_id INTEGER REFERENCES exercise_categories(id),
    name TEXT NOT NULL,
    description TEXT,
    muscle_groups TEXT[], -- 배열로 여러 근육군 저장
    equipment TEXT,
    difficulty_level TEXT CHECK (difficulty_level IN ('beginner', 'intermediate', 'advanced')),
    instructions TEXT,
    video_url TEXT,
    icon_url TEXT, -- image_url에서 변경
    thumbnail_url TEXT,
    met_value NUMERIC(4,1), -- calories_per_minute에서 변경 (MET 기반)
    is_cardio BOOLEAN DEFAULT false,
    tips TEXT[], -- 운동 팁 배열
    common_mistakes TEXT[], -- 흔한 실수 배열
    variations TEXT[], -- 변형 동작 배열
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON COLUMN exercises.icon_url IS 'URL for exercise icon image (48x48px recommended)';
COMMENT ON COLUMN exercises.met_value IS 'MET (Metabolic Equivalent of Task) value for calorie calculation. Calories = MET × weight(kg) × duration(min) / 60';
COMMENT ON COLUMN exercises.tips IS '운동 팁 배열';
COMMENT ON COLUMN exercises.common_mistakes IS '흔한 실수 배열';
COMMENT ON COLUMN exercises.variations IS '변형 동작 배열';

-- 운동 루틴
CREATE TABLE workout_routines (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    is_public BOOLEAN DEFAULT false,
    category TEXT CHECK (category IN ('strength', 'cardio', 'flexibility', 'mixed')),
    difficulty_level TEXT CHECK (difficulty_level IN ('beginner', 'intermediate', 'advanced')),
    estimated_duration INTEGER, -- 분
    total_exercises INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 루틴별 운동 구성
CREATE TABLE routine_exercises (
    id SERIAL PRIMARY KEY,
    routine_id INTEGER REFERENCES workout_routines(id) ON DELETE CASCADE,
    exercise_id INTEGER REFERENCES exercises(id),
    order_index INTEGER NOT NULL,
    sets INTEGER,
    reps INTEGER,
    duration INTEGER, -- 초
    rest_time INTEGER, -- 초
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 운동 세션 (is_completed 추가)
CREATE TABLE workout_sessions (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    routine_id INTEGER REFERENCES workout_routines(id),
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    total_duration INTEGER, -- 초
    calories_burned INTEGER,
    notes TEXT,
    mood TEXT CHECK (mood IN ('great', 'good', 'okay', 'tired', 'exhausted')),
    perceived_effort INTEGER CHECK (perceived_effort BETWEEN 1 AND 10),
    is_completed BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 운동별 실행 기록
CREATE TABLE exercise_logs (
    id SERIAL PRIMARY KEY,
    session_id INTEGER REFERENCES workout_sessions(id) ON DELETE CASCADE,
    exercise_id INTEGER REFERENCES exercises(id),
    sets_completed INTEGER,
    reps_completed INTEGER[],
    weight_used FLOAT[],
    duration INTEGER, -- 초
    distance FLOAT, -- km (유산소 운동용)
    heart_rate INTEGER,
    notes TEXT,
    completed_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 공유 루틴 시스템
CREATE TABLE shared_routines (
    id SERIAL PRIMARY KEY,
    routine_id INTEGER REFERENCES workout_routines(id),
    user_id UUID REFERENCES user_profiles(id),
    title TEXT NOT NULL,
    description TEXT,
    category TEXT CHECK (category IN ('strength', 'cardio', 'flexibility', 'mixed', 'beginner', 'intermediate', 'advanced')),
    tags TEXT[],
    thumbnail_url TEXT,
    is_public BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,
    difficulty_level TEXT CHECK (difficulty_level IN ('beginner', 'intermediate', 'advanced')),
    estimated_duration INTEGER,
    equipment_required TEXT[],
    target_muscle_groups TEXT[],
    calories_burned_estimate INTEGER,
    download_count INTEGER DEFAULT 0,
    like_count INTEGER DEFAULT 0,
    review_count INTEGER DEFAULT 0,
    average_rating FLOAT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 공유 루틴 리뷰
CREATE TABLE shared_routine_reviews (
    id SERIAL PRIMARY KEY,
    shared_routine_id INTEGER REFERENCES shared_routines(id) ON DELETE CASCADE,
    user_id UUID REFERENCES user_profiles(id),
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),
    title TEXT,
    comment TEXT,
    difficulty_feedback TEXT CHECK (difficulty_feedback IN ('too_easy', 'just_right', 'too_hard')),
    effectiveness_rating INTEGER CHECK (effectiveness_rating BETWEEN 1 AND 5),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(shared_routine_id, user_id)
);

-- 공유 루틴 상호작용
CREATE TABLE shared_routine_interactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    shared_routine_id INTEGER REFERENCES shared_routines(id) ON DELETE CASCADE,
    user_id UUID REFERENCES user_profiles(id),
    interaction_type TEXT CHECK (interaction_type IN ('like', 'bookmark', 'download')),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(shared_routine_id, user_id, interaction_type)
);

-- =========================================
-- 3. 러닝 추적 (Running Tracking)
-- =========================================

-- GPS 좌표
CREATE TABLE gps_coordinates (
    id SERIAL PRIMARY KEY,
    latitude FLOAT NOT NULL,
    longitude FLOAT NOT NULL,
    altitude FLOAT,
    timestamp TIMESTAMPTZ NOT NULL,
    accuracy FLOAT,
    speed FLOAT, -- m/s
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 러닝 루트
CREATE TABLE running_routes (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id),
    name TEXT,
    description TEXT,
    total_distance FLOAT NOT NULL, -- km
    elevation_gain FLOAT, -- meters
    difficulty_level TEXT CHECK (difficulty_level IN ('easy', 'moderate', 'hard')),
    route_type TEXT CHECK (route_type IN ('loop', 'out_and_back', 'point_to_point')),
    gps_coordinates INTEGER[], -- GPS 좌표 ID 배열
    is_public BOOLEAN DEFAULT false,
    like_count INTEGER DEFAULT 0,
    use_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 러닝 세션 (gps_data를 JSONB로 변경)
CREATE TABLE running_sessions (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    route_id INTEGER REFERENCES running_routes(id),
    workout_type TEXT CHECK (workout_type IN ('easy_run', 'interval', 'tempo', 'long_run', 'race', 'recovery')),
    started_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    total_duration INTEGER, -- 초
    distance FLOAT NOT NULL, -- km
    avg_pace FLOAT, -- minutes per km
    best_pace FLOAT, -- fastest km pace
    calories_burned INTEGER,
    avg_heart_rate INTEGER,
    max_heart_rate INTEGER,
    elevation_gain FLOAT, -- meters
    cadence INTEGER, -- steps per minute
    weather_condition TEXT,
    temperature FLOAT, -- celsius
    humidity FLOAT, -- percentage
    feeling TEXT CHECK (feeling IN ('terrible', 'poor', 'okay', 'good', 'great')),
    perceived_effort INTEGER CHECK (perceived_effort BETWEEN 1 AND 10),
    notes TEXT,
    gps_data JSONB DEFAULT '[]'::jsonb, -- GPS 좌표 데이터 (위도, 경도, 고도, 타임스탬프 등을 포함하는 JSON 배열)
    split_times FLOAT[], -- pace for each km
    is_race BOOLEAN DEFAULT false,
    race_name TEXT,
    placement INTEGER,
    total_participants INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

COMMENT ON COLUMN running_sessions.gps_data IS 'GPS 좌표 데이터 (위도, 경도, 고도, 타임스탬프 등을 포함하는 JSON 배열)';

-- 페이스 구간
CREATE TABLE pace_segments (
    id SERIAL PRIMARY KEY,
    session_id INTEGER REFERENCES running_sessions(id) ON DELETE CASCADE,
    segment_index INTEGER NOT NULL,
    start_time TIMESTAMPTZ NOT NULL,
    end_time TIMESTAMPTZ NOT NULL,
    distance FLOAT NOT NULL, -- km
    pace FLOAT NOT NULL, -- minutes per km
    elevation_change FLOAT, -- meters
    heart_rate_avg INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 러닝 계획
CREATE TABLE running_plans (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    coach_name TEXT,
    duration_weeks INTEGER NOT NULL,
    target_race_distance FLOAT, -- km (5K, 10K, Half Marathon, Marathon)
    difficulty_level TEXT CHECK (difficulty_level IN ('beginner', 'intermediate', 'advanced')),
    runs_per_week INTEGER NOT NULL,
    plan_type TEXT CHECK (plan_type IN ('race_prep', 'base_building', 'speed', 'maintenance')),
    is_premium BOOLEAN DEFAULT false,
    image_url TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 러닝 운동 (계획별)
CREATE TABLE running_workouts (
    id SERIAL PRIMARY KEY,
    plan_id INTEGER REFERENCES running_plans(id) ON DELETE CASCADE,
    week_number INTEGER NOT NULL,
    day_number INTEGER CHECK (day_number BETWEEN 1 AND 7), -- 1-7 (Monday-Sunday)
    workout_name TEXT,
    workout_type TEXT CHECK (workout_type IN ('easy_run', 'interval', 'tempo', 'long_run', 'rest', 'cross_training')),
    description TEXT,
    target_distance FLOAT, -- km
    target_duration INTEGER, -- minutes
    target_pace TEXT, -- "easy pace", "10K pace", etc.
    instructions TEXT,
    audio_cues TEXT[],
    order_index INTEGER NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 사용자별 러닝 계획 진행도
CREATE TABLE user_running_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    plan_id INTEGER REFERENCES running_plans(id),
    started_at DATE NOT NULL,
    current_week INTEGER DEFAULT 1,
    is_active BOOLEAN DEFAULT true,
    completion_percentage FLOAT DEFAULT 0.0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, plan_id)
);

-- 러닝 운동 완료 기록
CREATE TABLE user_workout_completions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_plan_id UUID REFERENCES user_running_plans(id) ON DELETE CASCADE,
    workout_id INTEGER REFERENCES running_workouts(id),
    session_id INTEGER REFERENCES running_sessions(id),
    completed_at TIMESTAMPTZ NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_plan_id, workout_id)
);

-- 러닝화 관리
CREATE TABLE running_shoes (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    brand TEXT NOT NULL,
    model TEXT NOT NULL,
    purchase_date DATE,
    total_distance FLOAT DEFAULT 0.0, -- km
    max_distance FLOAT DEFAULT 500.0, -- km (교체 시기)
    is_active BOOLEAN DEFAULT true,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 세션별 러닝화 사용 기록
CREATE TABLE session_shoes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id INTEGER REFERENCES running_sessions(id) ON DELETE CASCADE,
    shoe_id INTEGER REFERENCES running_shoes(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(session_id, shoe_id)
);

-- =========================================
-- 4. 식단 관리 (Diet Management)
-- =========================================

-- 음식 카테고리
CREATE TABLE food_categories (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    icon TEXT,
    color TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 음식 정보
CREATE TABLE foods (
    id SERIAL PRIMARY KEY,
    category_id INTEGER REFERENCES food_categories(id),
    name TEXT NOT NULL,
    brand TEXT,
    barcode TEXT,
    serving_size FLOAT NOT NULL,
    serving_unit TEXT NOT NULL,
    calories FLOAT NOT NULL,
    protein FLOAT NOT NULL,
    carbs FLOAT NOT NULL,
    fat FLOAT NOT NULL,
    fiber FLOAT,
    sugar FLOAT,
    sodium FLOAT,
    is_verified BOOLEAN DEFAULT false,
    created_by UUID REFERENCES user_profiles(id),
    search_vector tsvector, -- 전문 검색용
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 식사 타입
CREATE TABLE meal_types (
    id SERIAL PRIMARY KEY,
    name TEXT NOT NULL CHECK (name IN ('breakfast', 'lunch', 'dinner', 'snack')),
    typical_time TIME,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 식사 기록
CREATE TABLE meal_logs (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    meal_type_id INTEGER REFERENCES meal_types(id),
    logged_at TIMESTAMPTZ NOT NULL,
    notes TEXT,
    total_calories FLOAT,
    total_protein FLOAT,
    total_carbs FLOAT,
    total_fat FLOAT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 식사별 음식 항목
CREATE TABLE meal_food_items (
    id SERIAL PRIMARY KEY,
    meal_log_id INTEGER REFERENCES meal_logs(id) ON DELETE CASCADE,
    food_id INTEGER REFERENCES foods(id),
    quantity FLOAT NOT NULL,
    unit TEXT NOT NULL,
    calories_consumed FLOAT NOT NULL,
    protein_consumed FLOAT NOT NULL,
    carbs_consumed FLOAT NOT NULL,
    fat_consumed FLOAT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 영양 목표
CREATE TABLE nutrition_goals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    daily_calories FLOAT NOT NULL,
    daily_protein FLOAT NOT NULL,
    daily_carbs FLOAT NOT NULL,
    daily_fat FLOAT NOT NULL,
    daily_water FLOAT DEFAULT 2000, -- ml
    goal_type TEXT DEFAULT 'maintenance' CHECK (goal_type IN ('weight_loss', 'weight_gain', 'maintenance', 'muscle_gain')),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, is_active) -- 활성 목표는 하나만
);

-- 물 섭취 기록
CREATE TABLE water_intake_logs (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    amount FLOAT NOT NULL, -- ml
    logged_at TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 사용자별 즐겨찾는 음식
CREATE TABLE user_favorite_foods (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    food_id INTEGER REFERENCES foods(id),
    frequency_count INTEGER DEFAULT 1,
    last_used TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, food_id)
);

-- =========================================
-- 5. 동기부여 시스템 (Motivation System)
-- =========================================

-- 일일 활동 추적
CREATE TABLE daily_activities (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    activity_date DATE NOT NULL,
    workout_completed BOOLEAN DEFAULT false,
    running_completed BOOLEAN DEFAULT false,
    diet_logged BOOLEAN DEFAULT false,
    water_goal_met BOOLEAN DEFAULT false,
    steps_goal_met BOOLEAN DEFAULT false,
    sleep_logged BOOLEAN DEFAULT false,
    workout_count INTEGER DEFAULT 0,
    running_distance FLOAT DEFAULT 0, -- km
    calories_burned FLOAT DEFAULT 0,
    calories_consumed FLOAT DEFAULT 0,
    water_intake FLOAT DEFAULT 0, -- ml
    steps_count INTEGER DEFAULT 0,
    sleep_hours FLOAT DEFAULT 0,
    mood_rating INTEGER CHECK (mood_rating BETWEEN 1 AND 5),
    energy_level INTEGER CHECK (energy_level BETWEEN 1 AND 5),
    notes TEXT,
    streak_workout INTEGER DEFAULT 0,
    streak_running INTEGER DEFAULT 0,
    streak_diet INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, activity_date)
);

-- 개인 기록
CREATE TABLE personal_records (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    record_type TEXT NOT NULL, -- max_weight, fastest_5k, longest_run, max_reps
    exercise_name TEXT,
    value FLOAT NOT NULL,
    unit TEXT NOT NULL,
    date_achieved DATE NOT NULL,
    session_id INTEGER, -- workout_sessions 또는 running_sessions와 연결
    session_type TEXT CHECK (session_type IN ('workout', 'running')),
    notes TEXT,
    is_verified BOOLEAN DEFAULT false,
    previous_record FLOAT,
    improvement FLOAT,
    improvement_percentage FLOAT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 목표 설정
CREATE TABLE goals (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT CHECK (category IN ('weight', 'strength', 'endurance', 'nutrition', 'habit')),
    target_value FLOAT NOT NULL,
    target_unit TEXT NOT NULL,
    target_date DATE NOT NULL,
    current_value FLOAT DEFAULT 0,
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'completed', 'paused', 'cancelled')),
    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 목표 진행 기록
CREATE TABLE goal_progress (
    id SERIAL PRIMARY KEY,
    goal_id INTEGER REFERENCES goals(id) ON DELETE CASCADE,
    progress_date DATE NOT NULL,
    value FLOAT NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(goal_id, progress_date)
);

-- 진행 상황 마일스톤
CREATE TABLE progress_milestones (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    milestone_type TEXT NOT NULL, -- total_distance, weight_lost, workouts_completed
    title TEXT NOT NULL,
    description TEXT,
    target_value FLOAT NOT NULL,
    current_value FLOAT DEFAULT 0,
    unit TEXT NOT NULL,
    category TEXT CHECK (category IN ('fitness', 'nutrition', 'running', 'strength')),
    is_achieved BOOLEAN DEFAULT false,
    achieved_at TIMESTAMPTZ,
    badge_icon TEXT,
    celebration_message TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 습관 추적
CREATE TABLE habit_trackers (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    habit_name TEXT NOT NULL,
    habit_type TEXT CHECK (habit_type IN ('exercise', 'nutrition', 'lifestyle', 'sleep')),
    target_frequency INTEGER NOT NULL, -- times per week
    current_streak INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    total_completions INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 습관 완료 기록
CREATE TABLE habit_completions (
    id SERIAL PRIMARY KEY,
    habit_id INTEGER REFERENCES habit_trackers(id) ON DELETE CASCADE,
    completion_date DATE NOT NULL,
    is_completed BOOLEAN NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(habit_id, completion_date)
);

-- 성취 시스템
CREATE TABLE achievements (
    id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    description TEXT,
    category TEXT CHECK (category IN ('workout', 'running', 'diet', 'streak', 'milestone')),
    icon TEXT,
    badge_color TEXT,
    unlock_condition TEXT NOT NULL, -- JSON으로 조건 저장
    points_reward INTEGER DEFAULT 10,
    is_hidden BOOLEAN DEFAULT false, -- 숨겨진 성취
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 사용자별 성취 달성
CREATE TABLE user_achievements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    achievement_id INTEGER REFERENCES achievements(id),
    achieved_at TIMESTAMPTZ NOT NULL,
    progress_value FLOAT, -- 달성 당시 수치
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, achievement_id)
);

-- 진행 상황 사진
CREATE TABLE progress_photos (
    id SERIAL PRIMARY KEY,
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    thumbnail_url TEXT,
    photo_type TEXT CHECK (photo_type IN ('front', 'side', 'back', 'custom')),
    weight FLOAT, -- kg
    body_fat_percentage FLOAT,
    notes TEXT,
    is_public BOOLEAN DEFAULT false,
    taken_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- =========================================
-- 6. 위젯 시스템 (Widget System)
-- =========================================

-- 위젯 정의
CREATE TABLE widget_definitions (
    id SERIAL PRIMARY KEY,
    widget_type TEXT UNIQUE NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT CHECK (category IN ('stats', 'workout', 'running', 'diet', 'goals', 'social')),
    spec_type TEXT CHECK (spec_type IN ('SMALL', 'MEDIUM_VERTICAL', 'MEDIUM_HORIZONTAL', 'LARGE')),
    default_size_cols INTEGER NOT NULL,
    default_size_rows INTEGER NOT NULL,
    min_cols INTEGER DEFAULT 1,
    min_rows INTEGER DEFAULT 1,
    max_cols INTEGER DEFAULT 2,
    max_rows INTEGER DEFAULT 2,
    icon TEXT,
    preview_image TEXT,
    is_premium BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 사용자별 위젯 배치
CREATE TABLE user_widgets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    widget_type TEXT REFERENCES widget_definitions(widget_type),
    position_page INTEGER DEFAULT 0,
    position_row INTEGER NOT NULL,
    position_col INTEGER NOT NULL,
    size_cols INTEGER NOT NULL,
    size_rows INTEGER NOT NULL,
    z_index INTEGER DEFAULT 1,
    is_pinned BOOLEAN DEFAULT false,
    is_enabled BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, widget_type) -- 사용자당 위젯 타입별 하나씩
);

-- 위젯 설정
CREATE TABLE widget_configurations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_widget_id UUID REFERENCES user_widgets(id) ON DELETE CASCADE,
    config_key TEXT NOT NULL,
    config_value TEXT, -- JSON 형태로 저장
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_widget_id, config_key)
);

-- =========================================
-- 7. 성능 최적화 테이블
-- =========================================

-- 일일 통계 캐시 (위젯 성능 최적화용)
CREATE TABLE daily_stats_cache (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    stat_date DATE NOT NULL,
    total_calories_consumed FLOAT DEFAULT 0,
    total_calories_burned FLOAT DEFAULT 0,
    total_steps INTEGER DEFAULT 0,
    total_distance FLOAT DEFAULT 0, -- km
    total_water FLOAT DEFAULT 0, -- ml
    workout_count INTEGER DEFAULT 0,
    running_count INTEGER DEFAULT 0,
    workout_duration INTEGER DEFAULT 0, -- 분
    running_duration INTEGER DEFAULT 0, -- 분
    avg_heart_rate INTEGER,
    sleep_hours FLOAT,
    weight FLOAT, -- kg
    mood_score FLOAT,
    energy_score FLOAT,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, stat_date)
);

-- 주간 통계 캐시
CREATE TABLE weekly_stats_cache (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    week_start_date DATE NOT NULL, -- 주의 시작일 (월요일)
    total_workouts INTEGER DEFAULT 0,
    total_running_sessions INTEGER DEFAULT 0,
    total_calories_burned FLOAT DEFAULT 0,
    total_distance FLOAT DEFAULT 0, -- km
    avg_pace FLOAT, -- min/km
    best_pace FLOAT, -- min/km
    total_workout_time INTEGER DEFAULT 0, -- 분
    streak_days INTEGER DEFAULT 0,
    goals_completed INTEGER DEFAULT 0,
    last_updated TIMESTAMPTZ DEFAULT NOW(),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, week_start_date)
);

-- =========================================
-- 8. 인덱스 생성
-- =========================================

-- 사용자 관련
CREATE INDEX idx_user_goals_user_id ON user_goals(user_id);
CREATE INDEX idx_user_profiles_onboarding_status ON user_profiles(has_completed_onboarding);

-- 운동 관련
CREATE INDEX idx_workout_sessions_user_date ON workout_sessions(user_id, started_at);
CREATE INDEX idx_exercise_logs_session ON exercise_logs(session_id);
CREATE INDEX idx_exercises_muscle_groups ON exercises USING gin(muscle_groups);
CREATE INDEX idx_shared_routines_category ON shared_routines(category, is_public);

-- 러닝 관련
CREATE INDEX idx_running_sessions_user_date ON running_sessions(user_id, started_at);
CREATE INDEX idx_running_sessions_gps_data_gin ON running_sessions USING GIN (gps_data);
CREATE INDEX idx_gps_coordinates_timestamp ON gps_coordinates(timestamp);
CREATE INDEX idx_pace_segments_session ON pace_segments(session_id);

-- 식단 관련
CREATE INDEX idx_meal_logs_user_date ON meal_logs(user_id, logged_at);
CREATE INDEX idx_foods_search ON foods USING gin(search_vector);
CREATE INDEX idx_foods_name_brand ON foods USING gin((name || ' ' || COALESCE(brand, '')) gin_trgm_ops);
CREATE INDEX idx_meal_food_items_meal ON meal_food_items(meal_log_id);

-- 동기부여 관련
CREATE INDEX idx_daily_activities_user_date ON daily_activities(user_id, activity_date);
CREATE INDEX idx_personal_records_user_type ON personal_records(user_id, record_type);
CREATE INDEX idx_goals_user_status ON goals(user_id, status);

-- 위젯 관련
CREATE INDEX idx_user_widgets_user_enabled ON user_widgets(user_id, is_enabled);
CREATE INDEX idx_user_widgets_position ON user_widgets(user_id, position_page, position_row, position_col);

-- 캐시 테이블
CREATE INDEX idx_daily_stats_cache_user_date ON daily_stats_cache(user_id, stat_date);
CREATE INDEX idx_weekly_stats_cache_user_week ON weekly_stats_cache(user_id, week_start_date);

-- =========================================
-- 9. 트리거 및 함수
-- =========================================

-- updated_at 자동 업데이트 함수
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- updated_at 트리거 생성
CREATE TRIGGER update_user_profiles_updated_at BEFORE UPDATE ON user_profiles FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_preferences_updated_at BEFORE UPDATE ON user_preferences FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_goals_updated_at BEFORE UPDATE ON user_goals FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_workout_routines_updated_at BEFORE UPDATE ON workout_routines FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_workout_sessions_updated_at BEFORE UPDATE ON workout_sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_running_sessions_updated_at BEFORE UPDATE ON running_sessions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_foods_updated_at BEFORE UPDATE ON foods FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_widgets_updated_at BEFORE UPDATE ON user_widgets FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- 음식 검색 벡터 업데이트 트리거
CREATE OR REPLACE FUNCTION update_food_search_vector()
RETURNS TRIGGER AS $$
BEGIN
    NEW.search_vector = to_tsvector('korean', NEW.name || ' ' || COALESCE(NEW.brand, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_foods_search_vector
BEFORE INSERT OR UPDATE ON foods
FOR EACH ROW EXECUTE FUNCTION update_food_search_vector();

-- 사용자 프로필 자동 생성 트리거 (최신 버전)
CREATE OR REPLACE FUNCTION create_user_profile()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_profiles (
    id,
    username,
    full_name,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    COALESCE(
      NEW.raw_user_meta_data->>'username',
      'user_' || substr(NEW.id::text, 1, 8)
    ),
    COALESCE(
      NEW.raw_user_meta_data->>'full_name',
      'User'
    ),
    NOW(),
    NOW()
  )
  ON CONFLICT (id) DO NOTHING;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to create user profile for %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_user_profile();

-- 사용자 설정 자동 생성 트리거 (최신 버전)
CREATE OR REPLACE FUNCTION create_user_preferences()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_preferences (
    user_id,
    theme,
    language,
    measurement_system,
    notifications_enabled,
    workout_reminders,
    diet_reminders,
    running_audio_cues,
    privacy_profile,
    created_at,
    updated_at
  )
  VALUES (
    NEW.id,
    'system',
    'ko',
    'metric',
    true,
    true,
    true,
    true,
    'public',
    NOW(),
    NOW()
  )
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Failed to create user preferences for %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

CREATE TRIGGER on_user_profile_created
  AFTER INSERT ON user_profiles
  FOR EACH ROW
  EXECUTE FUNCTION create_user_preferences();

-- =========================================
-- 10. 운동 통계 함수
-- =========================================

-- 사용자의 운동 통계를 계산하는 함수
CREATE OR REPLACE FUNCTION get_workout_stats(user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
    weekly_workouts INTEGER := 0;
    total_calories FLOAT := 0;
    avg_duration FLOAT := 0;
    current_streak INTEGER := 0;
    week_start DATE;
    total_duration INTEGER := 0;
    workout_count INTEGER := 0;
BEGIN
    -- 이번 주 시작일 계산 (월요일)
    week_start := CURRENT_DATE - (EXTRACT(DOW FROM CURRENT_DATE) - 1)::INTEGER;

    -- 이번 주 운동 데이터 조회
    SELECT
        COUNT(*) as workout_count,
        COALESCE(SUM(ws.calories_burned), 0) as total_calories,
        COALESCE(SUM(ws.total_duration), 0) as total_duration
    INTO workout_count, total_calories, total_duration
    FROM workout_sessions ws
    WHERE ws.user_id = get_workout_stats.user_id
        AND ws.is_completed = true
        AND ws.started_at >= week_start
        AND ws.started_at < week_start + INTERVAL '7 days';

    weekly_workouts := workout_count;

    -- 평균 운동 시간 계산 (분 단위)
    IF workout_count > 0 THEN
        avg_duration := (total_duration / 60.0) / workout_count;
    ELSE
        avg_duration := 0;
    END IF;

    -- 연속 운동 일수 계산
    WITH daily_workouts AS (
        SELECT DISTINCT DATE(ws.started_at) as workout_date
        FROM workout_sessions ws
        WHERE ws.user_id = get_workout_stats.user_id
            AND ws.is_completed = true
        ORDER BY workout_date DESC
    ),
    streak_calc AS (
        SELECT
            workout_date,
            workout_date - ROW_NUMBER() OVER (ORDER BY workout_date DESC)::INTEGER as streak_group
        FROM daily_workouts
        WHERE workout_date <= CURRENT_DATE
    )
    SELECT COUNT(*)
    INTO current_streak
    FROM streak_calc
    WHERE streak_group = (
        SELECT streak_group
        FROM streak_calc
        WHERE workout_date = CURRENT_DATE
        LIMIT 1
    );

    -- 오늘 운동하지 않았다면 스트릭 계산을 다시 함
    IF current_streak = 0 THEN
        WITH daily_workouts AS (
            SELECT DISTINCT DATE(ws.started_at) as workout_date
            FROM workout_sessions ws
            WHERE ws.user_id = get_workout_stats.user_id
                AND ws.is_completed = true
            ORDER BY workout_date DESC
        ),
        consecutive_days AS (
            SELECT
                workout_date,
                LAG(workout_date) OVER (ORDER BY workout_date DESC) as prev_date
            FROM daily_workouts
        )
        SELECT COUNT(*)
        INTO current_streak
        FROM consecutive_days
        WHERE workout_date = CURRENT_DATE - 1
            AND (prev_date IS NULL OR prev_date = workout_date - 1);
    END IF;

    -- JSON 결과 생성
    result := json_build_object(
        'weeklyWorkouts', weekly_workouts,
        'totalCalories', ROUND(total_calories::NUMERIC, 0),
        'avgDuration', ROUND(avg_duration::NUMERIC, 1),
        'streak', COALESCE(current_streak, 0),
        'totalDuration', ROUND((total_duration / 60.0)::NUMERIC, 0) -- 총 운동시간(분)
    );

    RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_workout_stats(UUID) TO authenticated;
COMMENT ON FUNCTION get_workout_stats(UUID) IS '사용자의 주간 운동 통계를 반환하는 함수';

-- 주간 운동 데이터를 가져오는 함수
CREATE OR REPLACE FUNCTION get_weekly_workout_data(user_id UUID)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    result JSON;
    week_start DATE;
    weekly_data JSON[];
    day_data JSON;
    current_day DATE;
    day_korean TEXT;
    exercised BOOLEAN;
    minutes INTEGER;
    calories INTEGER;
BEGIN
    -- 이번 주 시작일 계산 (월요일)
    week_start := CURRENT_DATE - (EXTRACT(DOW FROM CURRENT_DATE) - 1)::INTEGER;

    -- 요일별 데이터 생성
    FOR i IN 0..6 LOOP
        current_day := week_start + i;

        -- 요일명 생성
        CASE EXTRACT(DOW FROM current_day)
            WHEN 1 THEN day_korean := '월';
            WHEN 2 THEN day_korean := '화';
            WHEN 3 THEN day_korean := '수';
            WHEN 4 THEN day_korean := '목';
            WHEN 5 THEN day_korean := '금';
            WHEN 6 THEN day_korean := '토';
            WHEN 0 THEN day_korean := '일';
        END CASE;

        -- 해당 날짜의 운동 데이터 조회
        SELECT
            CASE WHEN COUNT(*) > 0 THEN true ELSE false END as exercised,
            COALESCE(SUM(ws.total_duration) / 60, 0) as minutes,
            COALESCE(SUM(ws.calories_burned), 0) as calories
        INTO exercised, minutes, calories
        FROM workout_sessions ws
        WHERE ws.user_id = get_weekly_workout_data.user_id
            AND ws.is_completed = true
            AND DATE(ws.started_at) = current_day;

        -- 일별 데이터 JSON 생성
        day_data := json_build_object(
            'day', day_korean,
            'exercised', exercised,
            'minutes', minutes,
            'calories', calories
        );

        weekly_data := array_append(weekly_data, day_data);
    END LOOP;

    -- 최종 결과 반환
    result := array_to_json(weekly_data);

    RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION get_weekly_workout_data(UUID) TO authenticated;
COMMENT ON FUNCTION get_weekly_workout_data(UUID) IS '사용자의 주간 운동 데이터를 요일별로 반환하는 함수';

-- =========================================
-- 11. Row Level Security (RLS) 정책
-- =========================================

ALTER TABLE user_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_routines ENABLE ROW LEVEL SECURITY;
ALTER TABLE workout_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE exercise_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE running_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_food_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE personal_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE habit_trackers ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_widgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_stats_cache ENABLE ROW LEVEL SECURITY;

-- user_profiles 정책 (최신 버전)
CREATE POLICY "Users can select own profile"
ON user_profiles FOR SELECT
USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
ON user_profiles FOR INSERT
WITH CHECK (auth.uid() = id OR auth.uid() IS NULL);

CREATE POLICY "Users can update own profile"
ON user_profiles FOR UPDATE
USING (auth.uid() = id);

CREATE POLICY "Users can delete own profile"
ON user_profiles FOR DELETE
USING (auth.uid() = id);

-- user_preferences 정책 (최신 버전)
CREATE POLICY "Users can select own preferences"
ON user_preferences FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own preferences"
ON user_preferences FOR INSERT
WITH CHECK (auth.uid() = user_id OR auth.uid() IS NULL);

CREATE POLICY "Users can update own preferences"
ON user_preferences FOR UPDATE
USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own preferences"
ON user_preferences FOR DELETE
USING (auth.uid() = user_id);

-- user_goals 정책
CREATE POLICY "Users can view own goals" ON user_goals
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own goals" ON user_goals
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own goals" ON user_goals
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own goals" ON user_goals
    FOR DELETE USING (auth.uid() = user_id);

-- 운동 관련 정책
CREATE POLICY workout_routines_policy ON workout_routines FOR ALL USING (auth.uid() = user_id);
CREATE POLICY workout_sessions_policy ON workout_sessions FOR ALL USING (auth.uid() = user_id);

-- exercise_logs RLS (최신 버전)
DROP POLICY IF EXISTS exercise_logs_policy ON exercise_logs;
CREATE POLICY exercise_logs_select_policy ON exercise_logs FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM workout_sessions ws
        WHERE ws.id = exercise_logs.session_id
        AND ws.user_id = auth.uid()
    )
);

CREATE POLICY exercise_logs_insert_policy ON exercise_logs FOR INSERT
WITH CHECK (
    EXISTS (
        SELECT 1 FROM workout_sessions ws
        WHERE ws.id = exercise_logs.session_id
        AND ws.user_id = auth.uid()
    )
);

CREATE POLICY exercise_logs_update_policy ON exercise_logs FOR UPDATE
USING (
    EXISTS (
        SELECT 1 FROM workout_sessions ws
        WHERE ws.id = exercise_logs.session_id
        AND ws.user_id = auth.uid()
    )
);

CREATE POLICY exercise_logs_delete_policy ON exercise_logs FOR DELETE
USING (
    EXISTS (
        SELECT 1 FROM workout_sessions ws
        WHERE ws.id = exercise_logs.session_id
        AND ws.user_id = auth.uid()
    )
);

-- 러닝 관련 정책
CREATE POLICY running_sessions_policy ON running_sessions FOR ALL USING (auth.uid() = user_id);

-- 식단 관련 정책
CREATE POLICY meal_logs_policy ON meal_logs FOR ALL USING (auth.uid() = user_id);
CREATE POLICY meal_food_items_policy ON meal_food_items FOR ALL USING (
    EXISTS (SELECT 1 FROM meal_logs ml WHERE ml.id = meal_log_id AND ml.user_id = auth.uid())
);

-- 동기부여 관련 정책
CREATE POLICY daily_activities_policy ON daily_activities FOR ALL USING (auth.uid() = user_id);
CREATE POLICY personal_records_policy ON personal_records FOR ALL USING (auth.uid() = user_id);
CREATE POLICY goals_policy ON goals FOR ALL USING (auth.uid() = user_id);
CREATE POLICY habit_trackers_policy ON habit_trackers FOR ALL USING (auth.uid() = user_id);

-- 위젯 관련 정책
CREATE POLICY user_widgets_policy ON user_widgets FOR ALL USING (auth.uid() = user_id);

-- 캐시 관련 정책
CREATE POLICY daily_stats_cache_policy ON daily_stats_cache FOR ALL USING (auth.uid() = user_id);

-- 공개 데이터 읽기 정책
CREATE POLICY exercises_read_policy ON exercises FOR SELECT USING (true);
CREATE POLICY food_categories_read_policy ON food_categories FOR SELECT USING (true);
CREATE POLICY foods_read_policy ON foods FOR SELECT USING (true);
CREATE POLICY running_plans_read_policy ON running_plans FOR SELECT USING (true);

-- 공개 루틴 정책
DROP POLICY IF EXISTS shared_routines_read_policy ON shared_routines;
CREATE POLICY "Public can view public shared routines"
ON shared_routines FOR SELECT
USING (is_public = true);

CREATE POLICY "Users can manage own shared routines"
ON shared_routines FOR ALL
USING (auth.uid() = user_id);

-- 공개 운동 루틴 읽기 정책 (is_public = true인 경우)
DROP POLICY IF EXISTS workout_routines_read_public ON workout_routines;
CREATE POLICY "Public can view public routines"
ON workout_routines FOR SELECT
USING (is_public = true OR auth.uid() = user_id);

-- =========================================
-- 12. 뷰 생성 (자주 사용되는 조인 쿼리)
-- =========================================

-- 사용자 대시보드용 뷰
CREATE VIEW user_dashboard_stats AS
SELECT
    u.id as user_id,
    u.username,
    u.full_name,
    (SELECT COUNT(*) FROM workout_sessions ws WHERE ws.user_id = u.id AND ws.started_at >= CURRENT_DATE - INTERVAL '7 days') as workouts_this_week,
    (SELECT COUNT(*) FROM running_sessions rs WHERE rs.user_id = u.id AND rs.started_at >= CURRENT_DATE - INTERVAL '7 days') as runs_this_week,
    (SELECT SUM(distance) FROM running_sessions rs WHERE rs.user_id = u.id AND rs.started_at >= CURRENT_DATE - INTERVAL '7 days') as total_distance_week,
    (SELECT AVG(calories_consumed) FROM daily_activities da WHERE da.user_id = u.id AND da.activity_date >= CURRENT_DATE - INTERVAL '7 days') as avg_calories_week
FROM user_profiles u;

-- 운동 통계 뷰
CREATE VIEW workout_stats_summary AS
SELECT
    user_id,
    COUNT(*) as total_sessions,
    SUM(total_duration) as total_minutes,
    SUM(calories_burned) as total_calories,
    AVG(total_duration) as avg_duration,
    MAX(started_at) as last_workout
FROM workout_sessions
WHERE is_completed = true
GROUP BY user_id;

-- 러닝 통계 뷰
CREATE VIEW running_stats_summary AS
SELECT
    user_id,
    COUNT(*) as total_runs,
    SUM(distance) as total_distance,
    SUM(total_duration) as total_minutes,
    AVG(avg_pace) as overall_avg_pace,
    MIN(best_pace) as personal_best_pace,
    MAX(started_at) as last_run
FROM running_sessions
WHERE completed_at IS NOT NULL
GROUP BY user_id;

-- =========================================
-- 스키마 생성 완료
-- =========================================

COMMENT ON COLUMN user_profiles.has_completed_onboarding IS
'Indicates whether the user has completed the initial onboarding flow. Used to prevent re-showing onboarding on login.';
