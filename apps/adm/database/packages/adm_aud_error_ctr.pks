create or replace package adm_aud_error_ctr
    authid definer
    accessible by (package adm_gen_error_api)
as
-- =============================================================================
-- Paquete : adm_aud_error_ctr   (capa ctr)
-- Tabla   : adm_aud_error
-- Desc    : insertar es AUTÓNOMO: el incidente queda registrado aunque la
--           transacción del usuario haga rollback.
-- =============================================================================

    procedure insertar (
        i_apex_app_id     in  adm_aud_error.apex_app_id%type,
        i_apex_pagina_id  in  adm_aud_error.apex_pagina_id%type,
        i_username        in  adm_aud_error.username%type,
        i_componente      in  adm_aud_error.componente%type,
        i_mensaje         in  adm_aud_error.mensaje%type,
        i_ora_sqlcode     in  adm_aud_error.ora_sqlcode%type,
        i_ora_sqlerrm     in  adm_aud_error.ora_sqlerrm%type,
        i_error_backtrace in  adm_aud_error.error_backtrace%type,
        o_error_id        out adm_aud_error.error_id%type
    );

end adm_aud_error_ctr;
/
