-- ═══════════════════════════════════════════════════════════════════════════
-- open-autoDM - Prune the audit-log tables + analytics index
--
-- cleanup_old_rows() previously pruned debug_events, job_queue, dm_rate_events
-- and completed automation_sessions - but NOT dm_jobs / dm_logs, which grow
-- without bound on every trigger. This replaces the function with a version
-- that also prunes those two tables.
--
-- Retention: 180 days. The Analytics UI offers at most a 90-day range (its
-- 400-day guard exists only to bound the zero-fill loop), so 180 days keeps a
-- full extra half-year of history while capping table growth.
--
-- dm_sent_log is deliberately NEVER pruned: its UNIQUE constraints are the
-- one-DM-per-person dedup guarantee - deleting rows there would allow
-- re-sending to people who already received an automation.
-- ═══════════════════════════════════════════════════════════════════════════

-- Composite index for the Analytics queries (dm_jobs filtered by account +
-- created_at range; previously only created_at DESC was indexed).
CREATE INDEX IF NOT EXISTS idx_dm_jobs_account_created
  ON public.dm_jobs (instagram_account_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.cleanup_old_rows()
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  DELETE FROM public.debug_events WHERE created_at < NOW() - INTERVAL '7 days';
  DELETE FROM public.job_queue WHERE status IN ('done', 'failed') AND updated_at < NOW() - INTERVAL '7 days';
  DELETE FROM public.dm_rate_events WHERE sent_at < NOW() - INTERVAL '2 hours';
  DELETE FROM public.automation_sessions WHERE completed = TRUE AND last_activity_at < NOW() - INTERVAL '30 days';
  -- NEW: audit trail + conversation history (see retention note above)
  DELETE FROM public.dm_jobs WHERE created_at < NOW() - INTERVAL '180 days';
  DELETE FROM public.dm_logs WHERE sent_at < NOW() - INTERVAL '180 days';
END;
$$;

GRANT EXECUTE ON FUNCTION public.cleanup_old_rows() TO service_role;
