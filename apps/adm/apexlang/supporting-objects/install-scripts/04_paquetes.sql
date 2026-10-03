-- GENERADO por tools/build-supporting-objects.ps1 - NO EDITAR (fuente: apps/adm/database)

-- >>> apps/adm/database/packages/adm_seguridad_reg.pks
create or replace package adm_seguridad_reg
authid definer
as
-- =============================================================================
-- Paquete : adm_seguridad_reg
-- Tipo    : reg (Reglas de negocio)
-- Desc    : Autenticación y autorización centralizada para TODAS las apps APEX.
--           - F_AUTENTICAR      -> Authentication Function (esquema Custom)
--           - F_TIENE_*         -> Authorization Schemes de cada app
-- Requiere: grant execute on dbms_crypto to <esquema>  (ver db/install/00_grants_admin.sql)
-- =============================================================================

    C_MAX_INTENTOS  constant pls_integer := 5;

    -- Password ----------------------------------------------------------------
    function F_GENERAR_SALT return raw;

    function F_HASH_PASSWORD (
        I_PASSWORD  in varchar2,
        I_SALT      in raw
    ) return raw;

    -- Lanza ORA-20010 si la contraseña no cumple la política.
    procedure P_VALIDAR_POLITICA_PASSWORD (
        I_PASSWORD  in varchar2
    );

    -- Cambio de contraseña por el propio usuario (valida la actual).
    procedure P_CAMBIAR_PASSWORD_USUARIO (
        I_USERNAME          in varchar2,
        I_PASSWORD_ACTUAL   in varchar2,
        I_PASSWORD_NUEVO    in varchar2
    );

    -- Autenticación -----------------------------------------------------------
    -- EXCEPCIÓN AL ESTÁNDAR: APEX invoca la función con los nombres fijos
    -- p_username / p_password, por eso no usan el prefijo I_.
    function F_AUTENTICAR (
        p_username  in varchar2,
        p_password  in varchar2
    ) return boolean;

    -- Autorización ------------------------------------------------------------
    function F_ES_SUPERADMIN (
        I_USERNAME  in varchar2
    ) return boolean;

    function F_TIENE_ACCESO_APP (
        I_USERNAME      in varchar2,
        I_APEX_APP_ID   in number
    ) return boolean;

    function F_TIENE_PERMISO (
        I_USERNAME          in varchar2,
        I_PERMISO_CODIGO    in varchar2,
        I_EMPRESA_ID        in number default null
    ) return boolean;

    function F_TIENE_ACCESO_PAGINA (
        I_USERNAME          in varchar2,
        I_APEX_APP_ID       in number,
        I_APEX_PAGINA_ID    in number
    ) return boolean;

    function F_DEBE_CAMBIAR_PASSWORD (
        I_USERNAME  in varchar2
    ) return boolean;

end adm_seguridad_reg;
/

-- >>> apps/adm/database/packages/adm_usuario_ctr.pks
create or replace package adm_usuario_ctr
authid definer
as
-- =============================================================================
-- Paquete : adm_usuario_ctr
-- Tipo    : ctr (Control - DML y persistencia)
-- Desc    : Altas, cambios, contraseñas y asignación de roles de usuarios.
-- =============================================================================

    procedure P_INSERTAR (
        I_USERNAME              in  varchar2,
        I_EMAIL                 in  varchar2,
        I_NOMBRES               in  varchar2,
        I_APELLIDOS             in  varchar2 default null,
        I_TIPO_AUTENTICACION    in  varchar2 default 'LOCAL',
        I_PASSWORD              in  varchar2 default null,
        I_EMPRESA_ID_DEFECTO    in  number   default null,
        O_USUARIO_ID            out number
    );

    procedure P_ACTUALIZAR (
        I_USUARIO_ID            in number,
        I_EMAIL                 in varchar2,
        I_NOMBRES               in varchar2,
        I_APELLIDOS             in varchar2,
        I_EMPRESA_ID_DEFECTO    in number,
        I_ESTADO                in varchar2
    );

    -- I_DEBE_CAMBIAR = 'S' cuando lo resetea un administrador.
    procedure P_CAMBIAR_PASSWORD (
        I_USUARIO_ID        in number,
        I_PASSWORD_NUEVO    in varchar2,
        I_DEBE_CAMBIAR      in varchar2 default 'S'
    );

    procedure P_DESBLOQUEAR (
        I_USUARIO_ID  in number
    );

    procedure P_ASIGNAR_ROL (
        I_USUARIO_ID    in number,
        I_ROL_ID        in number,
        I_EMPRESA_ID    in number default null,
        I_FECHA_DESDE   in date   default trunc(sysdate),
        I_FECHA_HASTA   in date   default null
    );

    procedure P_QUITAR_ROL (
        I_USUARIO_ID    in number,
        I_ROL_ID        in number,
        I_EMPRESA_ID    in number default null
    );

end adm_usuario_ctr;
/

-- >>> apps/adm/database/packages/adm_seguridad_reg.pkb
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

-- >>> apps/adm/database/packages/adm_usuario_ctr.pkb
create or replace package body adm_usuario_ctr
as

    procedure P_INSERTAR (
        I_USERNAME              in  varchar2,
        I_EMAIL                 in  varchar2,
        I_NOMBRES               in  varchar2,
        I_APELLIDOS             in  varchar2 default null,
        I_TIPO_AUTENTICACION    in  varchar2 default 'LOCAL',
        I_PASSWORD              in  varchar2 default null,
        I_EMPRESA_ID_DEFECTO    in  number   default null,
        O_USUARIO_ID            out number
    ) is
        V_SALT  raw(32);
        V_HASH  raw(64);
    begin
        if I_TIPO_AUTENTICACION = 'LOCAL' then
            adm_seguridad_reg.P_VALIDAR_POLITICA_PASSWORD(I_PASSWORD);
            V_SALT := adm_seguridad_reg.F_GENERAR_SALT;
            V_HASH := adm_seguridad_reg.F_HASH_PASSWORD(I_PASSWORD, V_SALT);
        end if;

        insert into adm_seg_usuario (
            username, email, nombres, apellidos, tipo_autenticacion,
            password_hash, password_salt, debe_cambiar_password, empresa_id_defecto)
        values (
            upper(trim(I_USERNAME)), lower(trim(I_EMAIL)), I_NOMBRES, I_APELLIDOS, I_TIPO_AUTENTICACION,
            V_HASH, V_SALT, case when I_TIPO_AUTENTICACION = 'LOCAL' then 'S' else 'N' end, I_EMPRESA_ID_DEFECTO)
        returning usuario_id into O_USUARIO_ID;
    end P_INSERTAR;

    procedure P_ACTUALIZAR (
        I_USUARIO_ID            in number,
        I_EMAIL                 in varchar2,
        I_NOMBRES               in varchar2,
        I_APELLIDOS             in varchar2,
        I_EMPRESA_ID_DEFECTO    in number,
        I_ESTADO                in varchar2
    ) is
    begin
        update adm_seg_usuario
           set email              = lower(trim(I_EMAIL)),
               nombres            = I_NOMBRES,
               apellidos          = I_APELLIDOS,
               empresa_id_defecto = I_EMPRESA_ID_DEFECTO,
               estado             = I_ESTADO
         where usuario_id = I_USUARIO_ID;

        if sql%rowcount = 0 then
            raise_application_error(-20020, 'Usuario ' || I_USUARIO_ID || ' no existe.');
        end if;
    end P_ACTUALIZAR;

    procedure P_CAMBIAR_PASSWORD (
        I_USUARIO_ID        in number,
        I_PASSWORD_NUEVO    in varchar2,
        I_DEBE_CAMBIAR      in varchar2 default 'S'
    ) is
        V_SALT  raw(32);
    begin
        adm_seguridad_reg.P_VALIDAR_POLITICA_PASSWORD(I_PASSWORD_NUEVO);
        V_SALT := adm_seguridad_reg.F_GENERAR_SALT;

        update adm_seg_usuario
           set password_salt         = V_SALT,
               password_hash         = adm_seguridad_reg.F_HASH_PASSWORD(I_PASSWORD_NUEVO, V_SALT),
               debe_cambiar_password = I_DEBE_CAMBIAR,
               fecha_cambio_password = systimestamp,
               intentos_fallidos     = 0
         where usuario_id = I_USUARIO_ID
           and tipo_autenticacion = 'LOCAL';

        if sql%rowcount = 0 then
            raise_application_error(-20021, 'Usuario ' || I_USUARIO_ID || ' no existe o no usa autenticación local.');
        end if;
    end P_CAMBIAR_PASSWORD;

    procedure P_DESBLOQUEAR (
        I_USUARIO_ID  in number
    ) is
    begin
        update adm_seg_usuario
           set estado            = 'A',
               intentos_fallidos = 0
         where usuario_id = I_USUARIO_ID
           and estado     = 'B';
    end P_DESBLOQUEAR;

    procedure P_ASIGNAR_ROL (
        I_USUARIO_ID    in number,
        I_ROL_ID        in number,
        I_EMPRESA_ID    in number default null,
        I_FECHA_DESDE   in date   default trunc(sysdate),
        I_FECHA_HASTA   in date   default null
    ) is
    begin
        merge into adm_seg_usuario_rol t
        using (select I_USUARIO_ID usuario_id, I_ROL_ID rol_id, I_EMPRESA_ID empresa_id from dual) s
           on (    t.usuario_id = s.usuario_id
               and t.rol_id     = s.rol_id
               and decode(t.empresa_id, s.empresa_id, 1, 0) = 1)
         when matched then
            update set t.fecha_desde = I_FECHA_DESDE,
                       t.fecha_hasta = I_FECHA_HASTA
         when not matched then
            insert (usuario_id, rol_id, empresa_id, fecha_desde, fecha_hasta)
            values (s.usuario_id, s.rol_id, s.empresa_id, I_FECHA_DESDE, I_FECHA_HASTA);
    end P_ASIGNAR_ROL;

    procedure P_QUITAR_ROL (
        I_USUARIO_ID    in number,
        I_ROL_ID        in number,
        I_EMPRESA_ID    in number default null
    ) is
    begin
        delete from adm_seg_usuario_rol
         where usuario_id = I_USUARIO_ID
           and rol_id     = I_ROL_ID
           and decode(empresa_id, I_EMPRESA_ID, 1, 0) = 1;
    end P_QUITAR_ROL;

end adm_usuario_ctr;
/
