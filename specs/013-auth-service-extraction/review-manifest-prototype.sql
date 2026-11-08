-- ISOLATED SYNTHETIC REVIEW ONLY. Not a migration or production security setup.
-- Illustrates atomic manifest consumption for synthetic role and grant records;
-- it does not implement identity mapping, audit alerting, or reviewed activation.
-- Requires a disposable PostgreSQL cluster; creates cluster-wide test roles.

CREATE ROLE eka_manifest_owner NOLOGIN;
CREATE ROLE eka_manifest_forward LOGIN NOINHERIT;
CREATE ROLE eka_manifest_reverse LOGIN NOINHERIT;
CREATE ROLE eka_manifest_runtime LOGIN NOINHERIT;
CREATE SCHEMA manifest_review AUTHORIZATION eka_manifest_owner;
REVOKE ALL ON SCHEMA manifest_review FROM PUBLIC;
GRANT USAGE ON SCHEMA manifest_review TO eka_manifest_forward, eka_manifest_reverse, eka_manifest_runtime;

SET ROLE eka_manifest_owner;
CREATE TABLE manifest_review.control (
    singleton boolean PRIMARY KEY DEFAULT true CHECK (singleton),
    frozen boolean NOT NULL,
    revision bigint NOT NULL CHECK (revision >= 0)
);
INSERT INTO manifest_review.control VALUES (true, true, 0);
CREATE TABLE manifest_review.policy (
    direction text NOT NULL CHECK (direction IN ('FORWARD', 'REVERSE')),
    subject text NOT NULL,
    role text NOT NULL CHECK (role IN ('ADMIN', 'MEMBER')),
    PRIMARY KEY (direction, subject)
);
CREATE TABLE manifest_review.collections (id uuid PRIMARY KEY);
CREATE TABLE manifest_review.grants (
    direction text NOT NULL,
    subject text NOT NULL,
    collection_id uuid NOT NULL REFERENCES manifest_review.collections(id),
    permission text NOT NULL CHECK (permission IN ('READ', 'MANAGE')),
    PRIMARY KEY (direction, subject, collection_id),
    FOREIGN KEY (direction, subject) REFERENCES manifest_review.policy(direction, subject)
        ON DELETE CASCADE
);
CREATE TABLE manifest_review.runs (
    run_id uuid PRIMARY KEY,
    direction text NOT NULL CHECK (direction IN ('FORWARD', 'REVERSE')),
    active boolean NOT NULL DEFAULT false
);
CREATE TABLE manifest_review.entries (
    run_id uuid NOT NULL REFERENCES manifest_review.runs(run_id),
    entry_id uuid NOT NULL,
    subject text NOT NULL,
    old_role text CHECK (old_role IN ('ADMIN', 'MEMBER')),
    new_role text CHECK (new_role IN ('ADMIN', 'MEMBER')),
    consumed boolean NOT NULL DEFAULT false,
    PRIMARY KEY (run_id, entry_id),
    CHECK (old_role IS DISTINCT FROM new_role)
);
CREATE TABLE manifest_review.grant_entries (
    run_id uuid NOT NULL REFERENCES manifest_review.runs(run_id),
    entry_id uuid NOT NULL,
    subject text NOT NULL,
    collection_id uuid NOT NULL,
    old_permission text CHECK (old_permission IN ('READ', 'MANAGE')),
    new_permission text CHECK (new_permission IN ('READ', 'MANAGE')),
    consumed boolean NOT NULL DEFAULT false,
    PRIMARY KEY (run_id, entry_id),
    CHECK (old_permission IS DISTINCT FROM new_permission)
);
CREATE TABLE manifest_review.audit (
    run_id uuid NOT NULL,
    entry_id uuid NOT NULL,
    login_name name NOT NULL,
    direction text NOT NULL,
    happened_at timestamptz NOT NULL DEFAULT clock_timestamp(),
    PRIMARY KEY (run_id, entry_id)
);

CREATE FUNCTION manifest_review.apply_entry(p_run uuid, p_entry uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    c manifest_review.control%ROWTYPE;
    r manifest_review.runs%ROWTYPE;
    e manifest_review.entries%ROWTYPE;
    actual text;
BEGIN
    -- Freeze, run, manifest and record locks share a fixed order in this model.
    SELECT * INTO STRICT c FROM manifest_review.control WHERE singleton FOR UPDATE;
    IF NOT c.frozen OR c.revision = 9223372036854775807 THEN
        RAISE EXCEPTION 'freeze or revision unavailable' USING ERRCODE = '55000';
    END IF;
    SELECT * INTO STRICT r FROM manifest_review.runs WHERE run_id = p_run FOR UPDATE;
    IF NOT r.active OR NOT (
        (r.direction = 'FORWARD' AND session_user = 'eka_manifest_forward') OR
        (r.direction = 'REVERSE' AND session_user = 'eka_manifest_reverse')
    ) THEN
        RAISE EXCEPTION 'unauthorized or inactive run' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO STRICT e FROM manifest_review.entries
        WHERE run_id = p_run AND entry_id = p_entry FOR UPDATE;
    IF e.consumed THEN
        RAISE EXCEPTION 'entry already consumed' USING ERRCODE = '55000';
    END IF;
    SELECT role INTO actual FROM manifest_review.policy
        WHERE direction = r.direction AND subject = e.subject FOR UPDATE;
    IF actual IS DISTINCT FROM e.old_role THEN
        RAISE EXCEPTION 'manifest old state mismatch' USING ERRCODE = '55000';
    END IF;
    IF e.old_role IS NULL THEN
        INSERT INTO manifest_review.policy VALUES (r.direction, e.subject, e.new_role);
    ELSIF e.new_role IS NULL THEN
        IF EXISTS (SELECT 1 FROM manifest_review.grants
                   WHERE direction = r.direction AND subject = e.subject) THEN
            RAISE EXCEPTION 'remove grants with manifest entries before deleting identity'
                USING ERRCODE = '55000';
        END IF;
        DELETE FROM manifest_review.policy WHERE direction = r.direction AND subject = e.subject;
    ELSE
        UPDATE manifest_review.policy SET role = e.new_role
            WHERE direction = r.direction AND subject = e.subject;
    END IF;
    UPDATE manifest_review.entries SET consumed = true WHERE run_id = p_run AND entry_id = p_entry;
    UPDATE manifest_review.control SET revision = revision + 1 WHERE singleton;
    INSERT INTO manifest_review.audit(run_id, entry_id, login_name, direction)
        VALUES (p_run, p_entry, session_user, r.direction);
END;
$$;
CREATE FUNCTION manifest_review.apply_grant_entry(p_run uuid, p_entry uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog
AS $$
DECLARE
    c manifest_review.control%ROWTYPE;
    r manifest_review.runs%ROWTYPE;
    e manifest_review.grant_entries%ROWTYPE;
    actual text;
BEGIN
    SELECT * INTO STRICT c FROM manifest_review.control WHERE singleton FOR UPDATE;
    IF NOT c.frozen OR c.revision = 9223372036854775807 THEN
        RAISE EXCEPTION 'freeze or revision unavailable' USING ERRCODE = '55000';
    END IF;
    SELECT * INTO STRICT r FROM manifest_review.runs WHERE run_id = p_run FOR UPDATE;
    IF NOT r.active OR NOT (
        (r.direction = 'FORWARD' AND session_user = 'eka_manifest_forward') OR
        (r.direction = 'REVERSE' AND session_user = 'eka_manifest_reverse')
    ) THEN
        RAISE EXCEPTION 'unauthorized or inactive run' USING ERRCODE = '42501';
    END IF;
    SELECT * INTO STRICT e FROM manifest_review.grant_entries
        WHERE run_id = p_run AND entry_id = p_entry FOR UPDATE;
    IF e.consumed THEN
        RAISE EXCEPTION 'entry already consumed' USING ERRCODE = '55000';
    END IF;
    SELECT permission INTO actual FROM manifest_review.grants
        WHERE direction = r.direction AND subject = e.subject AND collection_id = e.collection_id
        FOR UPDATE;
    IF actual IS DISTINCT FROM e.old_permission THEN
        RAISE EXCEPTION 'manifest old state mismatch' USING ERRCODE = '55000';
    END IF;
    IF e.old_permission IS NULL THEN
        INSERT INTO manifest_review.grants VALUES (r.direction, e.subject, e.collection_id, e.new_permission);
    ELSIF e.new_permission IS NULL THEN
        DELETE FROM manifest_review.grants
            WHERE direction = r.direction AND subject = e.subject AND collection_id = e.collection_id;
    ELSE
        UPDATE manifest_review.grants SET permission = e.new_permission
            WHERE direction = r.direction AND subject = e.subject AND collection_id = e.collection_id;
    END IF;
    UPDATE manifest_review.grant_entries SET consumed = true WHERE run_id = p_run AND entry_id = p_entry;
    UPDATE manifest_review.control SET revision = revision + 1 WHERE singleton;
    INSERT INTO manifest_review.audit(run_id, entry_id, login_name, direction)
        VALUES (p_run, p_entry, session_user, r.direction);
END;
$$;
REVOKE ALL ON ALL TABLES IN SCHEMA manifest_review FROM PUBLIC;
REVOKE ALL ON FUNCTION manifest_review.apply_entry(uuid, uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION manifest_review.apply_grant_entry(uuid, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION manifest_review.apply_entry(uuid, uuid)
    TO eka_manifest_forward, eka_manifest_reverse;
GRANT EXECUTE ON FUNCTION manifest_review.apply_grant_entry(uuid, uuid)
    TO eka_manifest_forward, eka_manifest_reverse;
RESET ROLE;
