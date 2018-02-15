CREATE OR REPLACE
FUNCTION cartodb.CDB_Organization_Member_Group_Role_Member_Name()
    RETURNS TEXT
AS $$
    SELECT 'cdb_org_member'::text || '_' || md5(current_database());
$$
LANGUAGE SQL STABLE PARALLEL SAFE;

DO LANGUAGE 'plpgsql' $$
DECLARE
    cdb_org_member_role_name TEXT;
BEGIN
  cdb_org_member_role_name := cartodb.CDB_Organization_Member_Group_Role_Member_Name();
  IF NOT EXISTS ( SELECT * FROM pg_roles WHERE rolname= cdb_org_member_role_name )
  THEN
    EXECUTE 'CREATE ROLE "' || cdb_org_member_role_name || '" NOLOGIN;';
  END IF;
END
$$;

CREATE OR REPLACE
FUNCTION cartodb.CDB_Organization_Create_Member(role_name text)
    RETURNS void
AS $$
BEGIN
    EXECUTE 'GRANT "' || cartodb.CDB_Organization_Member_Group_Role_Member_Name() || '" TO "' || role_name || '"';
END
$$ LANGUAGE PLPGSQL VOLATILE PARALLEL UNSAFE;

-------------------------------------------------------------------------------
-- Administrator
-------------------------------------------------------------------------------
CREATE OR REPLACE
FUNCTION cartodb._CDB_Organization_Admin_Role_Name()
    RETURNS TEXT
AS $$
    SELECT current_database() || '_a'::text;
$$
LANGUAGE SQL STABLE PARALLEL SAFE;

-- Administrator role creation on extension install
DO LANGUAGE 'plpgsql' $$
DECLARE
    cdb_org_admin_role_name TEXT;
BEGIN
    cdb_org_admin_role_name := cartodb._CDB_Organization_Admin_Role_Name();
    IF NOT EXISTS ( SELECT * FROM pg_roles WHERE rolname= cdb_org_admin_role_name )
    THEN
        EXECUTE format('CREATE ROLE %I CREATEROLE NOLOGIN;', cdb_org_admin_role_name);
    END IF;
END
$$;

CREATE OR REPLACE
FUNCTION cartodb.CDB_Organization_AddAdmin(username text)
    RETURNS void
AS $$
DECLARE
    cdb_user_role TEXT;
    cdb_admin_role TEXT;
BEGIN
    cdb_admin_role := cartodb._CDB_Organization_Admin_Role_Name();
    cdb_user_role := cartodb._CDB_User_RoleFromUsername(username);
    EXECUTE format('GRANT %I TO %I WITH ADMIN OPTION', cdb_admin_role, cdb_user_role);
    -- CREATEROLE is not inherited, and is needed for user creation
    EXECUTE format('ALTER ROLE %I CREATEROLE', cdb_user_role);
END
$$ LANGUAGE PLPGSQL VOLATILE PARALLEL UNSAFE;

CREATE OR REPLACE
FUNCTION cartodb.CDB_Organization_RemoveAdmin(username text)
    RETURNS void
AS $$
DECLARE
    cdb_user_role TEXT;
    cdb_admin_role TEXT;
BEGIN
    cdb_admin_role := cartodb._CDB_Organization_Admin_Role_Name();
    cdb_user_role := cartodb._CDB_User_RoleFromUsername(username);
    EXECUTE format('ALTER ROLE %I NOCREATEROLE', cdb_user_role);
    EXECUTE format('REVOKE %I FROM %I', cdb_admin_role, cdb_user_role);
END
$$ LANGUAGE PLPGSQL VOLATILE PARALLEL UNSAFE;

-------------------------------------------------------------------------------
-- Sharing tables
-------------------------------------------------------------------------------
CREATE OR REPLACE
FUNCTION cartodb.CDB_Organization_Add_Table_Read_Permission(from_schema text, table_name text, to_role_name text)
    RETURNS void
AS $$
BEGIN
    EXECUTE 'GRANT USAGE ON SCHEMA "' || from_schema || '" TO "' || to_role_name || '"';
    EXECUTE 'GRANT SELECT ON "' || from_schema || '"."' || table_name || '" TO "' || to_role_name || '"';
END
$$ LANGUAGE PLPGSQL VOLATILE PARALLEL UNSAFE;

CREATE OR REPLACE
FUNCTION cartodb.CDB_Organization_Add_Table_Organization_Read_Permission(from_schema text, table_name text)
    RETURNS void
AS $$
BEGIN
    EXECUTE 'SELECT cartodb.CDB_Organization_Add_Table_Read_Permission(''' || from_schema || ''', ''' || table_name || ''', ''' || cartodb.CDB_Organization_Member_Group_Role_Member_Name() || ''');';
END
$$ LANGUAGE PLPGSQL VOLATILE PARALLEL UNSAFE;

CREATE OR REPLACE
FUNCTION cartodb.CDB_Organization_Add_Table_Read_Write_Permission(from_schema text, table_name text, to_role_name text)
    RETURNS void
AS $$
BEGIN
    EXECUTE 'GRANT USAGE ON SCHEMA "' || from_schema || '" TO "' || to_role_name || '"';
    EXECUTE 'GRANT SELECT, INSERT, UPDATE, DELETE ON "' || from_schema || '"."' || table_name || '" TO "' || to_role_name || '"';
    EXECUTE 'GRANT USAGE, SELECT ON SEQUENCE ' || pg_catalog.pg_get_serial_sequence(Format('%I.%I', from_schema, table_name), 'cartodb_id') || ' TO "' || to_role_name || '"';
END
$$ LANGUAGE PLPGSQL VOLATILE PARALLEL UNSAFE;

CREATE OR REPLACE
FUNCTION cartodb.CDB_Organization_Add_Table_Organization_Read_Write_Permission(from_schema text, table_name text)
    RETURNS void
AS $$
BEGIN
    EXECUTE 'SELECT cartodb.CDB_Organization_Add_Table_Read_Write_Permission(''' || from_schema || ''', ''' || table_name || ''', ''' || cartodb.CDB_Organization_Member_Group_Role_Member_Name() || ''');';
END
$$ LANGUAGE PLPGSQL VOLATILE PARALLEL UNSAFE;


CREATE OR REPLACE
FUNCTION cartodb.CDB_Organization_Remove_Access_Permission(from_schema text, table_name text, to_role_name text)
    RETURNS void
AS $$
BEGIN
    EXECUTE 'REVOKE ALL PRIVILEGES ON TABLE "' || from_schema || '"."' || table_name || '" FROM "' || to_role_name || '"';
    -- EXECUTE 'REVOKE USAGE ON SCHEMA ' || from_schema || ' FROM "' || to_role_name || '"';
    -- We need to revoke usage on schema only if we are revoking privileges from the last table where to_role_name has
    -- any permission granted within the schema from_schema
END
$$ LANGUAGE PLPGSQL VOLATILE PARALLEL UNSAFE;

CREATE OR REPLACE
FUNCTION cartodb.CDB_Organization_Remove_Organization_Access_Permission(from_schema text, table_name text)
    RETURNS void
AS $$
BEGIN
    EXECUTE 'SELECT cartodb.CDB_Organization_Remove_Access_Permission(''' || from_schema || ''', ''' || table_name || ''', ''' || cartodb.CDB_Organization_Member_Group_Role_Member_Name() || ''');';
END
$$ LANGUAGE PLPGSQL VOLATILE PARALLEL UNSAFE;
