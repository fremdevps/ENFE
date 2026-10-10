-- =============================================================================
-- Genera el archivo versionado del trigger de historial de cambios de una tabla
-- (trg_<app>_<abrev>_aiud) en apps/<app>/database/triggers/.
--
-- Uso (SQLcl, desde la raíz del repositorio, con el esquema de las apps como
-- current_schema). Siempre 4 argumentos; "_" = sin valor (no usar "-": al final de la línea SQLcl lo toma como continuación):
--   @tools/db/generar_trigger_historial.sql <tabla> <columna_padre|_> <excluidas|_> <reservadas|_>
-- Ejemplos:
--   @tools/db/generar_trigger_historial.sql adm_gen_empresa _ _ _
--   @tools/db/generar_trigger_historial.sql adm_seg_usuario_rol usuario_id _ _
--   @tools/db/generar_trigger_historial.sql adm_seg_usuario _ intentos_fallidos,fecha_ultimo_login _
--
-- Después: instalar el archivo generado (@apps/<app>/database/triggers/<trigger>.sql)
-- y agregarlo a apps/<app>/install/install.sql (sección "Triggers de historial").
-- =============================================================================
set define on verify off feedback off heading off pagesize 0 linesize 32767 long 2000000 longchunksize 32767 trimspool on termout off

column archivo new_value archivo_trigger noprint
select 'apps/' || lower(regexp_substr('&1', '^[^_]+')) || '/database/triggers/'
       || adm_aud_cambio_utl.obtener_nombre_trigger(i_tabla => '&1') || '.sql' archivo
  from dual;

spool &archivo_trigger
select rtrim(adm_aud_cambio_utl.generar_trigger(
           i_tabla               => '&1',
           i_columna_padre       => nullif('&2', '_'),
           i_columnas_excluidas  => nullif('&3', '_'),
           i_columnas_reservadas => nullif('&4', '_')), chr(10))
  from dual;
spool off

set termout on
prompt Generado: &archivo_trigger
set feedback on heading on pagesize 100
