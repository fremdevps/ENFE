-- =============================================================================
-- PREREQUISITOS - ejecutar como DBA, una sola vez por base de datos.
--   OCI Autonomous : conectado como ADMIN
--   On-premise     : conectado como SYS / SYSTEM o un DBA del PDB
-- Esquema del workspace DEV: WKSP_DEV (OCI). On-prem: reemplazar por el esquema real.
-- =============================================================================
grant execute on sys.dbms_crypto to WKSP_DEV;

-- Recomendado: verificar
select grantee, privilege, table_name
  from dba_tab_privs
 where grantee = 'WKSP_DEV'
   and table_name = 'DBMS_CRYPTO';
