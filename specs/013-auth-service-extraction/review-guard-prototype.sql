-- REVIEW PROTOTYPE ONLY: run solely in an isolated disposable PostgreSQL database.
-- Not a migration, production role setup, or a complete implementation.
-- Does not enforce the required reviewed manifest or independent failure alerts.
-- Assumes synthetic public.app_users, public.collection_grants,
-- public.collections, eka_auth.identities and eka_auth.grants already exist.
-- Install as a trusted database owner after separately securing schema ownership.
-- Uses a reserved advisory-lock key; actual deployment must allocate and verify it.

CREATE TABLE eka_auth.review_control (
    singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
    frozen boolean NOT NULL DEFAULT false,
    epoch uuid NOT NULL,
    revision bigint NOT NULL CHECK (revision >= 0)
);

INSERT INTO eka_auth.review_control (singleton, frozen, epoch, revision)
VALUES (true, false, gen_random_uuid(), 0);

-- Synthetic audit only: append-only privileges, retention, integrity protection
-- and reporting of failed/rolled-back attempts are not implemented.
CREATE TABLE eka_auth.review_audit (
    occurred_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    login_name name NOT NULL,
    table_schema name NOT NULL,
    table_name name NOT NULL,
    operation text NOT NULL
);

-- This prototype names the synthetic migration login explicitly. Production
-- identity, membership, connection-pool and permissions require separate review.
CREATE FUNCTION eka_auth.review_guard() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog
AS $$
DECLARE
    is_frozen boolean;
BEGIN
    PERFORM pg_catalog.pg_advisory_xact_lock_shared(19201, 13001);
    -- Lock and recheck the current tuple: an older repeatable-read snapshot
    -- must raise a serialization failure rather than admit a post-freeze write.
    SELECT c.frozen INTO STRICT is_frozen
      FROM eka_auth.review_control AS c WHERE c.singleton = true FOR UPDATE;
    IF is_frozen THEN
        IF NOT (
            (session_user = 'eka_review_migrator'
             AND TG_TABLE_SCHEMA = 'eka_auth'
             AND TG_TABLE_NAME IN ('identities', 'grants')
             AND TG_OP = 'INSERT')
            OR
            (session_user = 'eka_review_reverse_migrator'
             AND TG_TABLE_SCHEMA = 'public'
             AND TG_TABLE_NAME IN ('app_users', 'collection_grants')
             AND TG_OP IN ('INSERT', 'UPDATE', 'DELETE'))
        ) THEN
            RAISE EXCEPTION 'policy writes frozen' USING ERRCODE = '55000';
        END IF;
        INSERT INTO eka_auth.review_audit (login_name, table_schema, table_name, operation)
        VALUES (session_user, TG_TABLE_SCHEMA, TG_TABLE_NAME, TG_OP);
    END IF;
    RETURN NULL;
END;
$$;

CREATE FUNCTION eka_auth.review_bump_revision() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog
AS $$
BEGIN
    UPDATE eka_auth.review_control
       SET revision = revision + 1
     WHERE singleton = true AND revision < 9223372036854775807;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'policy revision unavailable' USING ERRCODE = '55000';
    END IF;
    RETURN NULL;
END;
$$;

CREATE FUNCTION eka_auth.review_set_freeze(p_frozen boolean) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog
AS $$
BEGIN
    IF p_frozen IS NULL THEN
        RAISE EXCEPTION 'invalid freeze state' USING ERRCODE = '22023';
    END IF;
    PERFORM pg_catalog.pg_advisory_xact_lock(19201, 13001);
    UPDATE eka_auth.review_control SET frozen = p_frozen WHERE singleton = true;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'freeze control unavailable' USING ERRCODE = '55000';
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION eka_auth.review_guard() FROM PUBLIC;
REVOKE ALL ON FUNCTION eka_auth.review_bump_revision() FROM PUBLIC;
REVOKE ALL ON FUNCTION eka_auth.review_set_freeze(boolean) FROM PUBLIC;

CREATE TRIGGER review_guard_users BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE
ON public.app_users FOR EACH STATEMENT EXECUTE FUNCTION eka_auth.review_guard();
CREATE TRIGGER review_revision_users AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE
ON public.app_users FOR EACH STATEMENT EXECUTE FUNCTION eka_auth.review_bump_revision();
CREATE TRIGGER review_guard_legacy_grants BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE
ON public.collection_grants FOR EACH STATEMENT EXECUTE FUNCTION eka_auth.review_guard();
CREATE TRIGGER review_revision_legacy_grants AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE
ON public.collection_grants FOR EACH STATEMENT EXECUTE FUNCTION eka_auth.review_bump_revision();
CREATE TRIGGER review_guard_collections BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE
ON public.collections FOR EACH STATEMENT EXECUTE FUNCTION eka_auth.review_guard();
CREATE TRIGGER review_revision_collections AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE
ON public.collections FOR EACH STATEMENT EXECUTE FUNCTION eka_auth.review_bump_revision();
CREATE TRIGGER review_guard_identities BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE
ON eka_auth.identities FOR EACH STATEMENT EXECUTE FUNCTION eka_auth.review_guard();
CREATE TRIGGER review_revision_identities AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE
ON eka_auth.identities FOR EACH STATEMENT EXECUTE FUNCTION eka_auth.review_bump_revision();
CREATE TRIGGER review_guard_grants BEFORE INSERT OR UPDATE OR DELETE OR TRUNCATE
ON eka_auth.grants FOR EACH STATEMENT EXECUTE FUNCTION eka_auth.review_guard();
CREATE TRIGGER review_revision_grants AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE
ON eka_auth.grants FOR EACH STATEMENT EXECUTE FUNCTION eka_auth.review_bump_revision();
