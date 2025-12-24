-- =========================================
-- User Exercise Preferences Table
-- 통합된 사용자 운동 선호도 관리 (즐겨찾기, 추천 빈도, 메모)
-- =========================================

CREATE TABLE IF NOT EXISTS user_exercise_preferences (
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    exercise_id UUID REFERENCES exercises(id) ON DELETE CASCADE,
    preference TEXT CHECK (preference IN ('more_often', 'less_often', 'excluded', 'neutral')) DEFAULT 'neutral',
    is_favorite BOOLEAN DEFAULT FALSE,
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    PRIMARY KEY (user_id, exercise_id)
);

-- 인덱스 추가
CREATE INDEX IF NOT EXISTS idx_user_exercise_preferences_user ON user_exercise_preferences(user_id);
CREATE INDEX IF NOT EXISTS idx_user_exercise_preferences_exercise ON user_exercise_preferences(exercise_id);

-- RLS 정책 설정
ALTER TABLE user_exercise_preferences ENABLE ROW LEVEL SECURITY;

-- 읽기 정책: 본인 데이터만
CREATE POLICY user_exercise_preferences_select_policy
ON user_exercise_preferences FOR SELECT
USING (auth.uid() = user_id);

-- 쓰기 정책: 본인 데이터만
CREATE POLICY user_exercise_preferences_insert_policy
ON user_exercise_preferences FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_exercise_preferences_update_policy
ON user_exercise_preferences FOR UPDATE
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

CREATE POLICY user_exercise_preferences_delete_policy
ON user_exercise_preferences FOR DELETE
USING (auth.uid() = user_id);

-- Updated_at 자동 갱신 트리거
CREATE OR REPLACE FUNCTION update_user_exercise_preferences_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_user_exercise_preferences_updated_at ON user_exercise_preferences;
CREATE TRIGGER trg_user_exercise_preferences_updated_at
    BEFORE UPDATE ON user_exercise_preferences
    FOR EACH ROW
    EXECUTE FUNCTION update_user_exercise_preferences_updated_at();


-- =========================================
-- Helper RPC Functions
-- =========================================

-- Upsert Preference (Frontend Helper)
-- 기존 레코드가 있으면 업데이트, 없으면 생성
CREATE OR REPLACE FUNCTION upsert_exercise_preference(
    p_exercise_id UUID,
    p_preference TEXT DEFAULT NULL,
    p_is_favorite BOOLEAN DEFAULT NULL,
    p_notes TEXT DEFAULT NULL
)
RETURNS VOID AS $$
DECLARE
    v_preference TEXT;
    v_is_favorite BOOLEAN;
    v_notes TEXT;
BEGIN
    -- 입력값이 NULL이면 기존 값을 유지하기 위해 조회 (단, 없으면 기본값 사용)
    -- 실제로는 ON CONFLICT DO UPDATE 구문에서 COALESCE를 사용하는 것이 효율적이지만,
    -- 명시적인 제어를 위해 아래와 같이 작성할 수도 있음. 
    -- 여기서는 간단하게 INSERT ... ON CONFLICT 구문에 COALESCE를 사용하여 구현.
    
    INSERT INTO user_exercise_preferences (user_id, exercise_id, preference, is_favorite, notes)
    VALUES (
        auth.uid(), 
        p_exercise_id, 
        COALESCE(p_preference, 'neutral'), 
        COALESCE(p_is_favorite, FALSE), 
        COALESCE(p_notes, '')
    )
    ON CONFLICT (user_id, exercise_id)
    DO UPDATE SET
        preference = CASE WHEN p_preference IS NOT NULL THEN EXCLUDED.preference ELSE user_exercise_preferences.preference END,
        is_favorite = CASE WHEN p_is_favorite IS NOT NULL THEN EXCLUDED.is_favorite ELSE user_exercise_preferences.is_favorite END,
        notes = CASE WHEN p_notes IS NOT NULL THEN EXCLUDED.notes ELSE user_exercise_preferences.notes END,
        updated_at = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
