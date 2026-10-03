-- =============================================================================
-- Verificador de consultas de una app APEX (smoke test del lado del servidor).
-- Ejecuta TODAS las consultas de regiones (reportes, IR, cards, métricas),
-- series de gráficos y LOVs dinámicas de la app, dentro de una sesión APEX real
-- (binds como :APP_USER resueltos), y lista las que fallan.
--
-- No necesita contraseña: crea la sesión con apex_session (requiere un usuario
-- de BD con acceso al workspace, p.ej. ADMIN en OCI o el esquema del workspace).
--
-- Uso (SQLcl):  @tools/apex/verificar_consultas.sql 100 QA_ADMIN
--   &1 = ID de la aplicación   &2 = usuario de la app con el que se simula la sesión
-- Termina con error (exit 1) si alguna consulta falla.
-- =============================================================================
set serveroutput on size unlimited feedback off verify off
whenever sqlerror exit failure

declare
    c_app_id   constant number        := &1;
    c_usuario  constant varchar2(100) := upper('&2');
    v_fallas   pls_integer := 0;
    v_total    pls_integer := 0;

    procedure probar(i_donde varchar2, i_sql varchar2) is
        l_ctx  apex_exec.t_context;
        l_sql  varchar2(32767) := i_sql;
    begin
        if l_sql is null then return; end if;
        v_total := v_total + 1;
        begin
            l_ctx := apex_exec.open_query_context(
                         p_location  => apex_exec.c_location_local_db,
                         p_sql_query => l_sql,
                         p_max_rows  => 1);
            if apex_exec.next_row(l_ctx) then null; end if;
            apex_exec.close(l_ctx);
        exception when others then
            apex_exec.close(l_ctx);
            v_fallas := v_fallas + 1;
            dbms_output.put_line('FALLA  ' || i_donde);
            dbms_output.put_line('       ' || sqlerrm);
        end;
    end probar;
begin
    apex_session.create_session(p_app_id => c_app_id, p_page_id => 1, p_username => c_usuario);

    for r in (select page_id, region_name, region_source
                from apex_application_page_regions
               where application_id = c_app_id
                 and query_type_code = 'SQL'
                 and region_source is not null
               order by page_id, display_sequence) loop
        probar('página ' || r.page_id || ' · región "' || r.region_name || '"', r.region_source);
    end loop;

    for r in (select s.page_id, s.region_name, s.series_name, s.data_source series_source
                from apex_application_page_chart_s s
               where s.application_id = c_app_id
                 and s.data_source_type like 'SQL%' and s.data_source is not null
               order by s.page_id) loop
        probar('página ' || r.page_id || ' · gráfico "' || r.region_name || '" serie "' || r.series_name || '"', r.series_source);
    end loop;

    for r in (select list_of_values_name, list_of_values_query
                from apex_application_lovs
               where application_id = c_app_id
                 and lov_type = 'Dynamic'
                 and list_of_values_query is not null) loop
        probar('LOV "' || r.list_of_values_name || '"', r.list_of_values_query);
    end loop;

    apex_session.delete_session;
    dbms_output.put_line('-----');
    dbms_output.put_line('App ' || c_app_id || ': ' || v_total || ' consultas, ' || v_fallas || ' con error.');
    if v_fallas > 0 then
        raise_application_error(-20900, v_fallas || ' consulta(s) con error en la app ' || c_app_id);
    end if;
end;
/
