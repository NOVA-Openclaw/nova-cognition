-- Management Functions for Bootstrap Context System
-- These functions provide a safe interface for updating context

-- Update or insert universal context
CREATE OR REPLACE FUNCTION update_universal_context(
    p_file_key TEXT,
    p_content TEXT,
    p_description TEXT DEFAULT NULL,
    p_updated_by TEXT DEFAULT 'system'
) RETURNS INTEGER AS $$
DECLARE
    v_id INTEGER;
BEGIN
    INSERT INTO bootstrap_context_universal (file_key, content, description, updated_by)
    VALUES (p_file_key, p_content, p_description, p_updated_by)
    ON CONFLICT (file_key) DO UPDATE
    SET content = EXCLUDED.content,
        description = COALESCE(EXCLUDED.description, bootstrap_context_universal.description),
        updated_at = NOW(),
        updated_by = EXCLUDED.updated_by
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Update or insert agent-specific context
CREATE OR REPLACE FUNCTION update_agent_context(
    p_agent_name TEXT,
    p_file_key TEXT,
    p_content TEXT,
    p_description TEXT DEFAULT NULL,
    p_updated_by TEXT DEFAULT 'system'
) RETURNS INTEGER AS $$
DECLARE
    v_id INTEGER;
BEGIN
    INSERT INTO bootstrap_context_agents (agent_name, file_key, content, description, updated_by)
    VALUES (p_agent_name, p_file_key, p_content, p_description, p_updated_by)
    ON CONFLICT (agent_name, file_key) DO UPDATE
    SET content = EXCLUDED.content,
        description = COALESCE(EXCLUDED.description, bootstrap_context_agents.description),
        updated_at = NOW(),
        updated_by = EXCLUDED.updated_by
    RETURNING id INTO v_id;
    
    RETURN v_id;
END;
$$ LANGUAGE plpgsql;

-- Get all bootstrap files for a specific agent (universal + agent-specific)
CREATE OR REPLACE FUNCTION get_agent_bootstrap(p_agent_name TEXT)
RETURNS TABLE (
    filename TEXT,
    content TEXT,
    source TEXT  -- 'universal' or 'agent'
) AS $$
BEGIN
    RETURN QUERY
    -- Universal context files
    SELECT 
        file_key || '.md' as filename,
        u.content,
        'universal'::TEXT as source
    FROM bootstrap_context_universal u
    WHERE (SELECT value::boolean FROM bootstrap_context_config WHERE key = 'enabled')
    
    UNION ALL
    
    -- Agent-specific files
    SELECT 
        file_key || '.md' as filename,
        a.content,
        'agent'::TEXT as source
    FROM bootstrap_context_agents a
    WHERE a.agent_name = p_agent_name
        AND (SELECT value::boolean FROM bootstrap_context_config WHERE key = 'enabled');
END;
$$ LANGUAGE plpgsql;

-- Copy file content to bootstrap context (for migration)
CREATE OR REPLACE FUNCTION copy_file_to_bootstrap(
    p_file_path TEXT,
    p_file_content TEXT,
    p_agent_name TEXT DEFAULT NULL,
    p_updated_by TEXT DEFAULT 'migration'
) RETURNS TEXT AS $$
DECLARE
    v_file_key TEXT;
    v_result TEXT;
BEGIN
    -- Extract file key from path (strip .md extension)
    v_file_key := upper(regexp_replace(
        regexp_replace(p_file_path, '^.*/([^/]+)\.md$', '\1'),
        '-', '_', 'g'
    ));
    
    -- Determine if universal or agent-specific
    IF p_agent_name IS NULL THEN
        -- Universal context
        PERFORM update_universal_context(
            v_file_key,
            p_file_content,
            'Migrated from ' || p_file_path,
            p_updated_by
        );
        v_result := 'universal:' || v_file_key;
    ELSE
        -- Agent-specific context
        PERFORM update_agent_context(
            p_agent_name,
            v_file_key,
            p_file_content,
            'Migrated from ' || p_file_path,
            p_updated_by
        );
        v_result := p_agent_name || ':' || v_file_key;
    END IF;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;

-- Delete universal context
CREATE OR REPLACE FUNCTION delete_universal_context(p_file_key TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_deleted BOOLEAN;
BEGIN
    DELETE FROM bootstrap_context_universal WHERE file_key = p_file_key;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted > 0;
END;
$$ LANGUAGE plpgsql;

-- Delete agent context
CREATE OR REPLACE FUNCTION delete_agent_context(p_agent_name TEXT, p_file_key TEXT)
RETURNS BOOLEAN AS $$
DECLARE
    v_deleted BOOLEAN;
BEGIN
    DELETE FROM bootstrap_context_agents 
    WHERE agent_name = p_agent_name AND file_key = p_file_key;
    GET DIAGNOSTICS v_deleted = ROW_COUNT;
    RETURN v_deleted > 0;
END;
$$ LANGUAGE plpgsql;

-- List all context files
CREATE OR REPLACE FUNCTION list_all_context()
RETURNS TABLE (
    type TEXT,
    agent_name TEXT,
    file_key TEXT,
    content_length INTEGER,
    updated_at TIMESTAMPTZ,
    updated_by TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        'universal'::TEXT,
        NULL::TEXT,
        u.file_key,
        length(u.content),
        u.updated_at,
        u.updated_by
    FROM bootstrap_context_universal u
    
    UNION ALL
    
    SELECT 
        'agent'::TEXT,
        a.agent_name,
        a.file_key,
        length(a.content),
        a.updated_at,
        a.updated_by
    FROM bootstrap_context_agents a
    ORDER BY type, agent_name, file_key;
END;
$$ LANGUAGE plpgsql;

-- Get configuration
CREATE OR REPLACE FUNCTION get_bootstrap_config()
RETURNS TABLE (
    key TEXT,
    value JSONB,
    description TEXT
) AS $$
BEGIN
    RETURN QUERY SELECT c.key, c.value, c.description FROM bootstrap_context_config c;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_universal_context IS 'Update or insert universal context file';
COMMENT ON FUNCTION update_agent_context IS 'Update or insert agent-specific context file';
COMMENT ON FUNCTION get_agent_bootstrap IS 'Get all bootstrap files for an agent (universal + agent-specific)';
COMMENT ON FUNCTION copy_file_to_bootstrap IS 'Migrate file content to database (auto-detects universal vs agent)';
COMMENT ON FUNCTION list_all_context IS 'List all context files with metadata';
COMMENT ON FUNCTION get_bootstrap_config IS 'Get bootstrap system configuration';
