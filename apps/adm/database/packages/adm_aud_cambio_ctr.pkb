create or replace package body adm_aud_cambio_ctr
as

    g_purga_activa  boolean := false;

    -- Contexto del cambio: igual para todas las filas de un lote.
    type t_contexto is record (
        usuario         adm_aud_cambio.usuario%type,
        apex_app_id     adm_aud_cambio.apex_app_id%type,
        apex_pagina_id  adm_aud_cambio.apex_pagina_id%type,
        apex_sesion_id  adm_aud_cambio.apex_sesion_id%type,
        transaccion_id  adm_aud_cambio.transaccion_id%type,
        modulo          adm_aud_cambio.modulo%type
    );

    function obtener_contexto return t_contexto is
        r_contexto  t_contexto;
    begin
        r_contexto.usuario        := substr(coalesce(sys_context('APEX$SESSION', 'APP_USER'), user), 1, 100);
        r_contexto.apex_app_id    := apex_application.g_flow_id;
        r_contexto.apex_pagina_id := apex_application.g_flow_step_id;
        r_contexto.apex_sesion_id := apex_application.g_instance;
        r_contexto.transaccion_id := dbms_transaction.local_transaction_id;
        r_contexto.modulo         := substr(sys_context('userenv', 'module'), 1, 100);
        return r_contexto;
    end obtener_contexto;

    procedure insertar_lote (
        i_cambios  in t_cambios
    ) is
        r_contexto  t_contexto;
    begin
        if i_cambios.count = 0 then
            return;
        end if;
        r_contexto := obtener_contexto;

        forall i in 1 .. i_cambios.count
            insert into adm_aud_cambio (
                app_codigo, tabla, registro_id, registro_padre_id, empresa_id, operacion, cambios,
                usuario, apex_app_id, apex_pagina_id, apex_sesion_id, transaccion_id, modulo)
            values (
                i_cambios(i).app_codigo, i_cambios(i).tabla, i_cambios(i).registro_id,
                i_cambios(i).registro_padre_id, i_cambios(i).empresa_id, i_cambios(i).operacion,
                i_cambios(i).cambios,
                r_contexto.usuario, r_contexto.apex_app_id, r_contexto.apex_pagina_id,
                r_contexto.apex_sesion_id, r_contexto.transaccion_id, r_contexto.modulo);
    end insertar_lote;

    procedure insertar (
        i_cambio   in t_cambio,
        i_cambios  in adm_aud_cambio.cambios%type
    ) is
        r_contexto  t_contexto := obtener_contexto;
    begin
        insert into adm_aud_cambio (
            app_codigo, tabla, registro_id, registro_padre_id, empresa_id, operacion, cambios,
            usuario, apex_app_id, apex_pagina_id, apex_sesion_id, transaccion_id, modulo)
        values (
            i_cambio.app_codigo, i_cambio.tabla, i_cambio.registro_id,
            i_cambio.registro_padre_id, i_cambio.empresa_id, i_cambio.operacion,
            i_cambios,
            r_contexto.usuario, r_contexto.apex_app_id, r_contexto.apex_pagina_id,
            r_contexto.apex_sesion_id, r_contexto.transaccion_id, r_contexto.modulo);
    end insertar;

    procedure eliminar_anteriores (
        i_fecha_limite  in  adm_aud_cambio.fecha%type,
        o_filas         out number
    ) is
    begin
        g_purga_activa := true;
        delete from adm_aud_cambio
         where fecha < i_fecha_limite;
        o_filas := sql%rowcount;
        g_purga_activa := false;
    exception
        when others then
            g_purga_activa := false;
            raise;
    end eliminar_anteriores;

    function es_purga_activa return boolean is
    begin
        return g_purga_activa;
    end es_purga_activa;

end adm_aud_cambio_ctr;
/
