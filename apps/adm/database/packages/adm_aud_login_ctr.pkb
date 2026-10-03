create or replace package body adm_aud_login_ctr
as

    procedure insertar (
        i_username   in adm_aud_login.username%type,
        i_resultado  in adm_aud_login.resultado%type
    ) is
        pragma autonomous_transaction;
        v_ip  adm_aud_login.ip_cliente%type;
    begin
        begin
            v_ip := substr(owa_util.get_cgi_env('REMOTE_ADDR'), 1, 50);
        exception
            when others then
                v_ip := null;   -- fuera de una petición web (SQLcl, jobs)
        end;

        insert into adm_aud_login (username, resultado, apex_app_id, ip_cliente)
        values (substr(i_username, 1, 100),
                i_resultado,
                to_number(sys_context('APEX$SESSION', 'APP_ID')),
                v_ip);
        commit;
    end insertar;

end adm_aud_login_ctr;
/
