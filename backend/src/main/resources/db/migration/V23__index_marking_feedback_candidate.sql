CREATE INDEX idx_marking_candidate_feedback_candidate_id
    ON marking_candidate_feedback (candidate_key, id DESC);
