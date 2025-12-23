-- =========================================
-- 샘플 데이터 및 빠른 루틴 추가
-- =========================================

-- 1. 운동 카테고리 추가
INSERT INTO exercise_categories (name, description, icon, color) VALUES
('헬스', '웨이트 트레이닝과 근력 운동', 'barbell-outline', '#FF6B35'),
('유산소', '심폐지구력 향상 운동', 'heart-outline', '#34D399'),
('요가', '유연성과 균형감각 향상', 'body-outline', '#8B5CF6'),
('복합', '여러 운동이 혼합된 루틴', 'flash-outline', '#F59E0B')
ON CONFLICT DO NOTHING;

-- 2. 기본 운동들 추가
INSERT INTO exercises (name, description, muscle_groups, equipment, difficulty_level, instructions, met_value, is_cardio) VALUES
-- 근력 운동
('푸시업', '가슴과 팔 근육을 강화하는 기본 운동', ARRAY['가슴', '삼두', '어깨'], '맨몸', 'beginner', '1. 엎드려서 손을 어깨 너비로 벌립니다\n2. 몸을 곧게 유지하며 팔을 굽혔다 펴줍니다', 8.0, false),
('스쿼트', '하체 전체 근력을 기르는 기본 운동', ARRAY['하체', '둔근'], '맨몸', 'beginner', '1. 어깨 너비로 발을 벌리고 서세요\n2. 무릎이 발끝을 넘지 않게 앉았다 일어서세요', 6.0, false),
('풀업', '등과 이두근을 강화하는 운동', ARRAY['등', '이두'], '풀업바', 'intermediate', '1. 풀업바를 잡고 매달립니다\n2. 팔꿈치를 굽혀 가슴이 바에 닿도록 올립니다', 10.0, false),
('플랭크', '코어 근력을 기르는 정적 운동', ARRAY['복근', '코어'], '맨몸', 'beginner', '1. 팔꿈치와 발가락으로 지탱합니다\n2. 몸을 일직선으로 유지하며 버팁니다', 5.0, false),
('덤벨 벤치프레스', '가슴 근육 발달을 위한 주요 운동', ARRAY['가슴', '삼두', '어깨'], '덤벨', 'intermediate', '1. 벤치에 누워 덤벨을 가슴 위로 올립니다\n2. 천천히 내렸다가 다시 밀어올립니다', 8.0, false),
('데드리프트', '전신 근력 향상을 위한 복합 운동', ARRAY['등', '하체', '코어'], '바벨', 'advanced', '1. 바벨을 잡고 허리를 곧게 펴세요\n2. 엉덩이를 뒤로 빼며 바벨을 들어올립니다', 12.0, false),

-- 유산소 운동
('버피', '전신 유산소 운동', ARRAY['전신'], '맨몸', 'intermediate', '1. 스쿼트 자세에서 시작\n2. 플랭크로 이동 후 점프하여 일어납니다', 15.0, true),
('마운틴 클라이머', '코어와 심폐지구력 향상', ARRAY['복근', '전신'], '맨몸', 'beginner', '1. 플랭크 자세를 유지합니다\n2. 무릎을 가슴 쪽으로 번갈아 가져옵니다', 12.0, true),
('점핑잭', '기본 유산소 워밍업 운동', ARRAY['전신'], '맨몸', 'beginner', '1. 발을 모으고 서세요\n2. 점프하며 팔다리를 벌렸다 모읍니다', 8.0, true),
('하이니', '하체 파워와 심폐지구력 향상', ARRAY['하체', '코어'], '맨몸', 'intermediate', '1. 제자리에서 무릎을 높이 올려가며 뜁니다\n2. 팔을 자연스럽게 흔들어 줍니다', 10.0, true),

-- 유연성 운동
('다운워드 독', '어깨와 햄스트링 스트레칭', ARRAY['어깨', '하체'], '매트', 'beginner', '1. 네발기기 자세에서 시작\n2. 엉덩이를 높이 올려 역삼각형을 만듭니다', 3.0, false),
('고양이 소 자세', '척추 유연성 향상', ARRAY['등', '코어'], '매트', 'beginner', '1. 네발기기 자세로 시작\n2. 등을 둥글게 했다가 반대로 젖혀줍니다', 2.0, false)
ON CONFLICT DO NOTHING;

-- 3. 공개 운동 루틴 추가 (빠른 루틴으로 표시될 데이터)
INSERT INTO workout_routines (user_id, name, description, is_public, category, difficulty_level, estimated_duration, total_exercises) VALUES
-- 초보자용 루틴
(null, '초보자 홈트레이닝', '집에서 쉽게 할 수 있는 기본 운동 루틴', true, 'strength', 'beginner', 20, 4),
(null, '아침 요가 스트레칭', '하루를 시작하는 부드러운 요가 동작', true, 'flexibility', 'beginner', 15, 4),
(null, '빠른 유산소 운동', '짧은 시간에 효과적인 유산소 운동', true, 'cardio', 'intermediate', 15, 4),

-- 중급자용 루틴
(null, '상체 근력 강화', '상체 근육 발달을 위한 집중 운동', true, 'strength', 'intermediate', 30, 5),
(null, '하체 파워 업', '하체 근력과 파워 향상 운동', true, 'strength', 'intermediate', 25, 4),
(null, '전신 HIIT', '고강도 인터벌 트레이닝', true, 'mixed', 'intermediate', 20, 6),

-- 고급자용 루틴
(null, '풀바디 웨이트', '전신 근력을 위한 웨이트 트레이닝', true, 'strength', 'advanced', 45, 6),
(null, '파워 유산소', '고강도 유산소 운동으로 체력 극대화', true, 'cardio', 'advanced', 30, 5);

-- 4. 루틴별 운동 구성 (routine_exercises)
-- 초보자 홈트레이닝 루틴 (routine_id = 1)
INSERT INTO routine_exercises (routine_id, exercise_id, order_index, sets, reps, duration, rest_time, notes) VALUES
(1, 1, 1, 3, 10, null, 60, '천천히 정확한 자세로'), -- 푸시업
(1, 2, 2, 3, 15, null, 60, '무릎이 발끝을 넘지 않게'), -- 스쿼트
(1, 4, 3, 3, null, 30, 60, '코어에 힘을 주고 버티기'), -- 플랭크
(1, 8, 4, 3, null, 30, 60, '빠르게 무릎 올리기'); -- 마운틴 클라이머

-- 아침 요가 스트레칭 (routine_id = 2)
INSERT INTO routine_exercises (routine_id, exercise_id, order_index, sets, reps, duration, rest_time, notes) VALUES
(2, 11, 1, 1, null, 60, 30, '깊게 호흡하며'), -- 다운워드 독
(2, 12, 2, 2, 10, null, 30, '천천히 부드럽게'), -- 고양이 소 자세
(2, 4, 3, 1, null, 45, 30, '호흡에 집중'), -- 플랭크
(2, 11, 4, 1, null, 45, 0, '마무리 스트레칭'); -- 다운워드 독

-- 빠른 유산소 운동 (routine_id = 3)
INSERT INTO routine_exercises (routine_id, exercise_id, order_index, sets, reps, duration, rest_time, notes) VALUES
(3, 9, 1, 4, null, 30, 30, '최대한 빠르게'), -- 점핑잭
(3, 7, 2, 3, 8, null, 45, '올바른 자세 유지'), -- 버피
(3, 8, 3, 4, null, 30, 30, '리듬감 있게'), -- 마운틴 클라이머
(3, 10, 4, 3, null, 45, 30, '무릎을 높이 올리기'); -- 하이니

-- 상체 근력 강화 (routine_id = 4)
INSERT INTO routine_exercises (routine_id, exercise_id, order_index, sets, reps, duration, rest_time, notes) VALUES
(4, 1, 1, 4, 12, null, 90, '가슴까지 내려가기'), -- 푸시업
(4, 3, 2, 3, 8, null, 120, '천천히 컨트롤'), -- 풀업
(4, 5, 3, 4, 12, null, 90, '적당한 중량으로'), -- 덤벨 벤치프레스
(4, 4, 4, 3, null, 60, 90, '어깨부터 발끝까지 일직선'), -- 플랭크
(4, 1, 5, 2, 15, null, 60, '마무리 푸시업'); -- 푸시업

-- 하체 파워 업 (routine_id = 5)
INSERT INTO routine_exercises (routine_id, exercise_id, order_index, sets, reps, duration, rest_time, notes) VALUES
(5, 2, 1, 4, 20, null, 90, '깊게 앉았다 일어서기'), -- 스쿼트
(5, 6, 2, 4, 10, null, 120, '허리 곧게 유지'), -- 데드리프트
(5, 2, 3, 3, 15, null, 60, '빠른 템포로'), -- 스쿼트
(5, 10, 4, 4, null, 45, 60, '폭발적으로'); -- 하이니

-- 전신 HIIT (routine_id = 6)
INSERT INTO routine_exercises (routine_id, exercise_id, order_index, sets, reps, duration, rest_time, notes) VALUES
(6, 7, 1, 3, 10, null, 30, '최대 강도로'), -- 버피
(6, 2, 2, 3, 20, null, 30, '빠른 리듬으로'), -- 스쿼트
(6, 8, 3, 3, null, 45, 30, '고강도 유지'), -- 마운틴 클라이머
(6, 1, 4, 3, 15, null, 30, '빠르게 진행'), -- 푸시업
(6, 9, 5, 3, null, 30, 30, '전력으로'), -- 점핑잭
(6, 4, 6, 2, null, 60, 60, '마무리 코어'); -- 플랭크

-- 풀바디 웨이트 (routine_id = 7)
INSERT INTO routine_exercises (routine_id, exercise_id, order_index, sets, reps, duration, rest_time, notes) VALUES
(7, 6, 1, 5, 8, null, 180, '고중량으로'), -- 데드리프트
(7, 2, 2, 4, 12, null, 120, '깊은 스쿼트'), -- 스쿼트
(7, 5, 3, 4, 10, null, 120, '가슴에 충분한 자극'), -- 덤벨 벤치프레스
(7, 3, 4, 3, 6, null, 180, '완전한 가동범위'), -- 풀업
(7, 4, 5, 3, null, 90, 90, '코어 안정성'), -- 플랭크
(7, 1, 6, 3, 20, null, 60, '마무리 운동'); -- 푸시업

-- 파워 유산소 (routine_id = 8)
INSERT INTO routine_exercises (routine_id, exercise_id, order_index, sets, reps, duration, rest_time, notes) VALUES
(8, 7, 1, 5, 12, null, 45, '최대 파워로'), -- 버피
(8, 10, 2, 4, null, 60, 45, '무릎을 가슴까지'), -- 하이니
(8, 8, 3, 5, null, 45, 30, '빠른 속도 유지'), -- 마운틴 클라이머
(8, 9, 4, 4, null, 60, 45, '리듬감 있게'), -- 점핑잭
(8, 2, 5, 4, 25, null, 60, '폭발적인 동작'); -- 스쿼트

-- 5. 운동 루틴의 총 운동 개수 업데이트
UPDATE workout_routines SET total_exercises = (
    SELECT COUNT(*) FROM routine_exercises WHERE routine_id = workout_routines.id
);

-- =========================================
-- 샘플 데이터 추가 완료
-- =========================================
