create or replace package body adm_seg_seguridad_reg
as

    function autenticar (
        p_username  in varchar2,
        p_password  in varchar2
    ) return boolean is
        v_username  adm_seg_usuario.username%type := upper(trim(p_username));
        v_app_id    number := to_number(sys_context('APEX$SESSION', 'APP_ID'));
        r_usuario   adm_seg_usuario%rowtype;
    begin
        r_usuario := adm_seg_usuario_ctr.obtener_por_username(i_username => v_username);

        if r_usuario.usuario_id is null then
            adm_aud_login_ctr.insertar(i_username => v_username, i_resultado => 'USUARIO_NO_EXISTE');
            return false;
        elsif r_usuario.estado = 'B' then
            adm_aud_login_ctr.insertar(i_username => v_username, i_resultado => 'BLOQUEADO');
            return false;
        elsif r_usuario.estado <> 'A' or r_usuario.tipo_autenticacion <> 'LOCAL' then
            adm_aud_login_ctr.insertar(i_username => v_username, i_resultado => 'INACTIVO');
            return false;
        end if;

        if not adm_seg_password_utl.es_valido(i_password => p_password,
                                              i_salt     => r_usuario.password_salt,
                                              i_hash     => r_usuario.password_hash)
        then
            adm_seg_usuario_ctr.actualizar_intentos(i_usuario_id   => r_usuario.usuario_id,
                                                    i_exitoso      => false,
                                                    i_max_intentos => c_max_intentos);
            adm_aud_login_ctr.insertar(i_username => v_username, i_resultado => 'PASSWORD_INVALIDO');
            return false;
        end if;

        -- Control centralizado: debe tener acceso a la app que lo invoca
        if v_app_id is not null and not tiene_acceso_app(i_username => v_username, i_apex_app_id => v_app_id) then
            adm_aud_login_ctr.insertar(i_username => v_username, i_resultado => 'SIN_ACCESO');
            return false;
        end if;

        adm_seg_usuario_ctr.actualizar_intentos(i_usuario_id   => r_usuario.usuario_id,
                                                i_exitoso      => true,
                                                i_max_intentos => c_max_intentos);
        adm_aud_login_ctr.insertar(i_username => v_username, i_resultado => 'OK');
        return true;
    end autenticar;

    function es_superadmin (
        i_username  in varchar2
    ) return boolean is
        v_cantidad  pls_integer;
    begin
        select count(*)
          into v_cantidad
          from adm_seg_usuario     u
          join adm_seg_usuario_rol ur on ur.usuario_id = u.usuario_id
          join adm_seg_rol         r  on r.rol_id      = ur.rol_id
         where u.username      = upper(i_username)
           and u.estado        = 'A'
           and r.estado        = 'A'
           and r.es_superadmin = 'S'
           and trunc(current_date) between ur.fecha_desde and coalesce(ur.fecha_hasta, trunc(current_date))
           and rownum = 1;
        return v_cantidad > 0;
    end es_superadmin;

    function tiene_acceso_app (
        i_username     in varchar2,
        i_apex_app_id  in number
    ) return boolean is
        v_cantidad  pls_integer;
    begin
        if es_superadmin(i_username => i_username) then
            return true;
        end if;

        select count(*)
          into v_cantidad
          from adm_seg_usuario_permiso_v
         where username    = upper(i_username)
           and apex_app_id = i_apex_app_id
           and rownum = 1;
        return v_cantidad > 0;
    end tiene_acceso_app;

    function tiene_permiso (
        i_username        in varchar2,
        i_permiso_codigo  in varchar2,
        i_empresa_id      in number default null
    ) return boolean is
        v_cantidad  pls_integer;
    begin
        if es_superadmin(i_username => i_username) then
            return true;
        end if;

        select count(*)
          into v_cantidad
          from adm_seg_usuario_permiso_v
         where username       = upper(i_username)
           and permiso_codigo = upper(i_permiso_codigo)
           and (i_empresa_id is null or empresa_id is null or empresa_id = i_empresa_id)
           and rownum = 1;
        return v_cantidad > 0;
    end tiene_permiso;

    function tiene_acceso_pagina (
        i_username        in varchar2,
        i_apex_app_id     in number,
        i_apex_pagina_id  in number
    ) return boolean is
        v_cantidad  pls_integer;
    begin
        if es_superadmin(i_username => i_username) then
            return true;
        end if;

        -- Denegar por defecto: la página debe estar registrada como permiso PAGINA
        select count(*)
          into v_cantidad
          from adm_seg_usuario_permiso_v
         where username       = upper(i_username)
           and apex_app_id    = i_apex_app_id
           and apex_pagina_id = i_apex_pagina_id
           and permiso_tipo   = 'PAGINA'
           and rownum = 1;
        return v_cantidad > 0;
    end tiene_acceso_pagina;

    function debe_cambiar_password (
        i_username  in varchar2
    ) return boolean is
        r_usuario  adm_seg_usuario%rowtype;
    begin
        r_usuario := adm_seg_usuario_ctr.obtener_por_username(i_username => i_username);
        return r_usuario.debe_cambiar_password = 'S';
    end debe_cambiar_password;

end adm_seg_seguridad_reg;
/
