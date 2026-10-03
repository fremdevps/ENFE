create or replace package body adm_gen_mensaje_error_ctr
as

    function obtener_mensaje (
        i_codigo  in adm_gen_mensaje_error.codigo%type
    ) return adm_gen_mensaje_error.mensaje%type is
        v_mensaje  adm_gen_mensaje_error.mensaje%type;
    begin
        select mensaje into v_mensaje from adm_gen_mensaje_error where codigo = upper(i_codigo);
        return v_mensaje;
    exception
        when no_data_found then
            return null;
    end obtener_mensaje;

end adm_gen_mensaje_error_ctr;
/
