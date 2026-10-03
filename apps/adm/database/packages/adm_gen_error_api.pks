create or replace package adm_gen_error_api
    authid definer
as
-- =============================================================================
-- Paquete : adm_gen_error_api   (capa api)
-- Desc    : Manejo de errores central para TODAS las apps APEX y el PL/SQL.
--
--   APEX  -> Application > Error Handling Function Name: adm_gen_error_api.manejar_error_apex
--   PL/SQL-> en bloques when others que deban registrar y re-lanzar:
--                exception when others then
--                    adm_gen_error_api.registrar(i_componente => 'erp_fin_factura_api.emitir');
--                    raise;
--
--   Reglas (recomendación Oracle, APEX_ERROR):
--   - Constraint (ORA-00001/02290/02291/02292): mensaje de adm_gen_mensaje_error
--     por nombre de constraint; si no existe, mensaje genérico + incidente.
--   - Negocio (ORA-20000..20999): se muestra el texto tal cual (ya es para el usuario).
--   - Interno / inesperado: se registra en adm_aud_error y el usuario ve solo
--     "Código de incidente N". Nunca se muestra el error técnico.
-- =============================================================================

    -- EXCEPCIÓN AL ESTÁNDAR: APEX exige el parámetro p_error.
    function manejar_error_apex (
        p_error  in apex_error.t_error
    ) return apex_error.t_error_result;

    -- Registra el error actual (sqlcode/sqlerrm/backtrace) y devuelve el nro. de incidente.
    function registrar (
        i_componente  in varchar2,
        i_mensaje     in varchar2 default null
    ) return number;

    procedure registrar (
        i_componente  in varchar2,
        i_mensaje     in varchar2 default null
    );

end adm_gen_error_api;
/
