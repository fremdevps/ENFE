create or replace package body adm_aud_error_ctr
as

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
    ) is
        pragma autonomous_transaction;
    begin
        insert into adm_aud_error (
            apex_app_id, apex_pagina_id, username, componente, mensaje,
            ora_sqlcode, ora_sqlerrm, error_backtrace)
        values (
            i_apex_app_id, i_apex_pagina_id, substr(i_username, 1, 100), substr(i_componente, 1, 400),
            substr(i_mensaje, 1, 4000), i_ora_sqlcode, substr(i_ora_sqlerrm, 1, 4000),
            substr(i_error_backtrace, 1, 4000))
        returning error_id into o_error_id;
        commit;
    end insertar;

end adm_aud_error_ctr;
/
