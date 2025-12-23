-- =========================================
-- 추가 기능 및 RLS 정책 업데이트
-- =========================================

-- 사용자별 즐겨찾는 운동 테이블
CREATE TABLE IF NOT EXISTS user_favorite_exercises (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES user_profiles(id) ON DELETE CASCADE,
    exercise_id INTEGER REFERENCES exercises(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, exercise_id)
);

-- 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_user_favorite_exercises_user ON user_favorite_exercises(user_id);
CREATE INDEX IF NOT EXISTS idx_user_favorite_exercises_exercise ON user_favorite_exercises(exercise_id);

-- RLS 정책 설정
ALTER TABLE user_favorite_exercises ENABLE ROW LEVEL SECURITY;

-- 사용자별 즐겨찾기 정책 (개발 환경 지원)
CREATE POLICY user_favorite_exercises_select_policy
ON user_favorite_exercises FOR SELECT
USING (
    (auth.uid() = user_id) OR
    (auth.uid() IS NULL AND user_id IS NOT NULL)
);

CREATE POLICY user_favorite_exercises_insert_policy
ON user_favorite_exercises FOR INSERT
WITH CHECK (
    (auth.uid() = user_id) OR
    (auth.uid() IS NULL AND user_id IS NOT NULL)
);

CREATE POLICY user_favorite_exercises_update_policy
ON user_favorite_exercises FOR UPDATE
USING (
    (auth.uid() = user_id) OR
    (auth.uid() IS NULL AND user_id IS NOT NULL)
)
WITH CHECK (
    (auth.uid() = user_id) OR
    (auth.uid() IS NULL AND user_id IS NOT NULL)
);

CREATE POLICY user_favorite_exercises_delete_policy
ON user_favorite_exercises FOR DELETE
USING (
    (auth.uid() = user_id) OR
    (auth.uid() IS NULL AND user_id IS NOT NULL)
);

-- =========================================
-- 추가 RLS 정책 업데이트 (개발 환경 지원)
-- =========================================

-- running_sessions 정책 업데이트 (개발 환경에서 auth.uid() null 허용)
DROP POLICY IF EXISTS running_sessions_policy ON running_sessions;

CREATE POLICY running_sessions_select_policy
ON running_sessions FOR SELECT
USING (
    (auth.uid() = user_id) OR
    (auth.uid() IS NULL AND user_id IS NOT NULL)
);

CREATE POLICY running_sessions_insert_policy
ON running_sessions FOR INSERT
WITH CHECK (
    (auth.uid() = user_id) OR
    (auth.uid() IS NULL AND user_id IS NOT NULL)
);

CREATE POLICY running_sessions_update_policy
ON running_sessions FOR UPDATE
USING (
    (auth.uid() = user_id) OR
    (auth.uid() IS NULL AND user_id IS NOT NULL)
)
WITH CHECK (
    (auth.uid() = user_id) OR
    (auth.uid() IS NULL AND user_id IS NOT NULL)
);

CREATE POLICY running_sessions_delete_policy
ON running_sessions FOR DELETE
USING (
    (auth.uid() = user_id) OR
    (auth.uid() IS NULL AND user_id IS NOT NULL)
);

-- =========================================
-- 기능 추가 완료
-- =========================================
