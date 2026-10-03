create or replace package adm_gen_mensaje_error_ctr
    authid definer
    accessible by (package adm_gen_error_api)
as
-- =============================================================================
-- Paquete : adm_gen_mensaje_error_ctr   (capa ctr)
-- Tabla   : adm_gen_mensaje_error
-- =============================================================================

    -- Mensaje para un constraint; null si no está registrado.
    function obtener_mensaje (
        i_codigo  in adm_gen_mensaje_error.codigo%type
    ) return adm_gen_mensaje_error.mensaje%type;

end adm_gen_mensaje_error_ctr;
/
