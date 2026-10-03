create or replace package body adm_seguridad_reg
as
-- =============================================================================
-- Paquete : adm_seguridad_reg (body)
-- Hash    : PBKDF2-HMAC-SHA512 (1 bloque de 64 bytes) con salt aleatorio de 32 bytes.
-- =============================================================================

    C_ITERACIONES       constant pls_integer := 10000;
    C_PASSWORD_MIN_LEN  constant pls_integer := 8;

    -- -------------------------------------------------------------------------
    -- Privados
    -- -------------------------------------------------------------------------
    procedure P_REGISTRAR_LOGIN (
        I_USERNAME   in varchar2,
        I_RESULTADO  in varchar2
    ) is
        pragma autonomous_transaction;
    begin
        insert into adm_aud_login (username, resultado, apex_app_id, ip_cliente)
        values (substr(I_USERNAME, 1, 100),
                I_RESULTADO,
                to_number(sys_context('APEX$SESSION', 'APP_ID')),
                substr(owa_util.get_cgi_env('REMOTE_ADDR'), 1, 50));
        commit;
    exception
        when others then
            -- owa_util no disponible fuera de una petición web
            insert into adm_aud_login (username, resultado)
            values (substr(I_USERNAME, 1, 100), I_RESULTADO);
            commit;
    end P_REGISTRAR_LOGIN;

    procedure P_LOGIN_EXITOSO (
        I_USUARIO_ID in number
    ) is
        pragma autonomous_transaction;
    begin
        update adm_seg_usuario
           set intentos_fallidos  = 0,
               fecha_ultimo_login = systimestamp
         where usuario_id = I_USUARIO_ID;
        commit;
    end P_LOGIN_EXITOSO;

    procedure P_LOGIN_FALLIDO (
        I_USUARIO_ID in number
    ) is
        pragma autonomous_transaction;
    begin
        update adm_seg_usuario
           set intentos_fallidos = intentos_fallidos + 1,
               estado            = case when intentos_fallidos + 1 >= C_MAX_INTENTOS then 'B' else estado end
         where usuario_id = I_USUARIO_ID;
        commit;
    end P_LOGIN_FALLIDO;

    -- -------------------------------------------------------------------------
    -- Password
    -- -------------------------------------------------------------------------
    function F_GENERAR_SALT return raw is
    begin
        return dbms_crypto.randombytes(32);
    end F_GENERAR_SALT;

    function F_HASH_PASSWORD (
        I_PASSWORD  in varchar2,
        I_SALT      in raw
    ) return raw is
        V_CLAVE  raw(2000);
        V_U      raw(64);
        V_T      raw(64);
    begin
        if I_PASSWORD is null or I_SALT is null then
            return null;
        end if;

        V_CLAVE := utl_i18n.string_to_raw(I_PASSWORD, 'AL32UTF8');
        V_U     := dbms_crypto.mac(utl_raw.concat(I_SALT, hextoraw('00000001')),
                                   dbms_crypto.hmac_sh512, V_CLAVE);
        V_T     := V_U;

        for i in 2 .. C_ITERACIONES loop
            V_U := dbms_crypto.mac(V_U, dbms_crypto.hmac_sh512, V_CLAVE);
            V_T := utl_raw.bit_xor(V_T, V_U);
        end loop;

        return V_T;
    end F_HASH_PASSWORD;

    -- NULL-safe: password o hash nulos nunca validan.
    function F_PASSWORD_VALIDO (
        I_PASSWORD  in varchar2,
        I_SALT      in raw,
        I_HASH      in raw
    ) return boolean is
        V_CALCULADO  raw(64);
    begin
        V_CALCULADO := F_HASH_PASSWORD(I_PASSWORD, I_SALT);
        return V_CALCULADO is not null
           and I_HASH      is not null
           and utl_raw.compare(V_CALCULADO, I_HASH) = 0;
    end F_PASSWORD_VALIDO;

    procedure P_VALIDAR_POLITICA_PASSWORD (
        I_PASSWORD  in varchar2
    ) is
    begin
        if I_PASSWORD is null
           or length(I_PASSWORD) < C_PASSWORD_MIN_LEN
           or not regexp_like(I_PASSWORD, '[0-9]')
           or not regexp_like(I_PASSWORD, '[A-Za-z]')
        then
            raise_application_error(-20010,
                'La contraseña debe tener al menos ' || C_PASSWORD_MIN_LEN ||
                ' caracteres e incluir letras y números.');
        end if;
    end P_VALIDAR_POLITICA_PASSWORD;

    procedure P_CAMBIAR_PASSWORD_USUARIO (
        I_USERNAME          in varchar2,
        I_PASSWORD_ACTUAL   in varchar2,
        I_PASSWORD_NUEVO    in varchar2
    ) is
        V_USUARIO_ID     adm_seg_usuario.usuario_id%type;
        V_HASH           adm_seg_usuario.password_hash%type;
        V_SALT           adm_seg_usuario.password_salt%type;
    begin
        select usuario_id, password_hash, password_salt
          into V_USUARIO_ID, V_HASH, V_SALT
          from adm_seg_usuario
         where username = upper(trim(I_USERNAME))
           and tipo_autenticacion = 'LOCAL';

        if not F_PASSWORD_VALIDO(I_PASSWORD_ACTUAL, V_SALT, V_HASH) then
            raise_application_error(-20011, 'La contraseña actual no es correcta.');
        end if;

        if I_PASSWORD_ACTUAL = I_PASSWORD_NUEVO then
            raise_application_error(-20012, 'La nueva contraseña debe ser distinta a la actual.');
        end if;

        adm_usuario_ctr.P_CAMBIAR_PASSWORD(
            I_USUARIO_ID     => V_USUARIO_ID,
            I_PASSWORD_NUEVO => I_PASSWORD_NUEVO,
            I_DEBE_CAMBIAR   => 'N');
    exception
        when no_data_found then
            raise_application_error(-20013, 'Usuario no encontrado o no usa autenticación local.');
    end P_CAMBIAR_PASSWORD_USUARIO;

    -- -------------------------------------------------------------------------
    -- Autenticación
    -- -------------------------------------------------------------------------
    function F_AUTENTICAR (
        p_username  in varchar2,
        p_password  in varchar2
    ) return boolean is
        V_USERNAME  adm_seg_usuario.username%type := upper(trim(p_username));
        V_USUARIO   adm_seg_usuario%rowtype;
        V_APP_ID    number := to_number(sys_context('APEX$SESSION', 'APP_ID'));
    begin
        begin
            select * into V_USUARIO from adm_seg_usuario where username = V_USERNAME;
        exception
            when no_data_found then
                P_REGISTRAR_LOGIN(V_USERNAME, 'USUARIO_NO_EXISTE');
                return false;
        end;

        if V_USUARIO.estado = 'B' then
            P_REGISTRAR_LOGIN(V_USERNAME, 'BLOQUEADO');
            return false;
        elsif V_USUARIO.estado <> 'A' or V_USUARIO.tipo_autenticacion <> 'LOCAL' then
            P_REGISTRAR_LOGIN(V_USERNAME, 'INACTIVO');
            return false;
        end if;

        if not F_PASSWORD_VALIDO(p_password, V_USUARIO.password_salt, V_USUARIO.password_hash) then
            P_LOGIN_FALLIDO(V_USUARIO.usuario_id);
            P_REGISTRAR_LOGIN(V_USERNAME, 'PASSWORD_INVALIDO');
            return false;
        end if;

        -- Control centralizado: el usuario debe tener acceso a la app que lo invoca
        if V_APP_ID is not null and not F_TIENE_ACCESO_APP(V_USERNAME, V_APP_ID) then
            P_REGISTRAR_LOGIN(V_USERNAME, 'SIN_ACCESO');
            return false;
        end if;

        P_LOGIN_EXITOSO(V_USUARIO.usuario_id);
        P_REGISTRAR_LOGIN(V_USERNAME, 'OK');
        return true;
    end F_AUTENTICAR;

    -- -------------------------------------------------------------------------
    -- Autorización
    -- -------------------------------------------------------------------------
    function F_ES_SUPERADMIN (
        I_USERNAME  in varchar2
    ) return boolean is
        V_EXISTE  pls_integer;
    begin
        select count(*)
          into V_EXISTE
          from adm_seg_usuario     u
          join adm_seg_usuario_rol ur on ur.usuario_id = u.usuario_id
          join adm_seg_rol         r  on r.rol_id      = ur.rol_id
         where u.username      = upper(I_USERNAME)
           and u.estado        = 'A'
           and r.estado        = 'A'
           and r.es_superadmin = 'S'
           and trunc(sysdate) between ur.fecha_desde and coalesce(ur.fecha_hasta, trunc(sysdate))
           and rownum = 1;
        return V_EXISTE > 0;
    end F_ES_SUPERADMIN;

    function F_TIENE_ACCESO_APP (
        I_USERNAME      in varchar2,
        I_APEX_APP_ID   in number
    ) return boolean is
        V_EXISTE  pls_integer;
    begin
        if F_ES_SUPERADMIN(I_USERNAME) then
            return true;
        end if;

        select count(*)
          into V_EXISTE
          from adm_seg_usuario_permiso_v
         where username    = upper(I_USERNAME)
           and apex_app_id = I_APEX_APP_ID
           and rownum = 1;
        return V_EXISTE > 0;
    end F_TIENE_ACCESO_APP;

    function F_TIENE_PERMISO (
        I_USERNAME          in varchar2,
        I_PERMISO_CODIGO    in varchar2,
        I_EMPRESA_ID        in number default null
    ) return boolean is
        V_EXISTE  pls_integer;
    begin
        if F_ES_SUPERADMIN(I_USERNAME) then
            return true;
        end if;

        select count(*)
          into V_EXISTE
          from adm_seg_usuario_permiso_v
         where username       = upper(I_USERNAME)
           and permiso_codigo = upper(I_PERMISO_CODIGO)
           and (I_EMPRESA_ID is null or empresa_id is null or empresa_id = I_EMPRESA_ID)
           and rownum = 1;
        return V_EXISTE > 0;
    end F_TIENE_PERMISO;

    function F_TIENE_ACCESO_PAGINA (
        I_USERNAME          in varchar2,
        I_APEX_APP_ID       in number,
        I_APEX_PAGINA_ID    in number
    ) return boolean is
        V_EXISTE  pls_integer;
    begin
        if F_ES_SUPERADMIN(I_USERNAME) then
            return true;
        end if;

        -- Denegar por defecto: la página debe estar registrada como permiso PAGINA
        select count(*)
          into V_EXISTE
          from adm_seg_usuario_permiso_v
         where username       = upper(I_USERNAME)
           and apex_app_id    = I_APEX_APP_ID
           and apex_pagina_id = I_APEX_PAGINA_ID
           and permiso_tipo   = 'PAGINA'
           and rownum = 1;
        return V_EXISTE > 0;
    end F_TIENE_ACCESO_PAGINA;

    function F_DEBE_CAMBIAR_PASSWORD (
        I_USERNAME  in varchar2
    ) return boolean is
        V_FLAG  adm_seg_usuario.debe_cambiar_password%type;
    begin
        select debe_cambiar_password
          into V_FLAG
          from adm_seg_usuario
         where username = upper(I_USERNAME);
        return V_FLAG = 'S';
    exception
        when no_data_found then
            return false;
    end F_DEBE_CAMBIAR_PASSWORD;

end adm_seguridad_reg;
/
