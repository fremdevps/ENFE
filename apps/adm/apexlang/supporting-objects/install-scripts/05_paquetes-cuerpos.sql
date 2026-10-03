-- GENERADO por tools/build-supporting-objects.ps1 - NO EDITAR (fuente: apps/adm/database)

-- >>> apps/adm/database/packages/adm_seg_password_utl.pkb
create or replace package body adm_seg_password_utl
as

    c_iteraciones       constant pls_integer := 10000;
    c_password_min_len  constant pls_integer := 8;

    function generar_salt return raw is
    begin
        return dbms_crypto.randombytes(32);
    end generar_salt;

    function calcular_hash (
        i_password  in varchar2,
        i_salt      in raw
    ) return raw is
        v_clave  raw(2000);
        v_u      raw(64);
        v_t      raw(64);
    begin
        if i_password is null or i_salt is null then
            return null;
        end if;

        v_clave := utl_i18n.string_to_raw(i_password, 'AL32UTF8');
        v_u     := dbms_crypto.mac(utl_raw.concat(i_salt, hextoraw('00000001')),
                                   dbms_crypto.hmac_sh512, v_clave);
        v_t     := v_u;

        for i in 2 .. c_iteraciones loop
            v_u := dbms_crypto.mac(v_u, dbms_crypto.hmac_sh512, v_clave);
            v_t := utl_raw.bit_xor(v_t, v_u);
        end loop;

        return v_t;
    end calcular_hash;

    function es_valido (
        i_password  in varchar2,
        i_salt      in raw,
        i_hash      in raw
    ) return boolean is
        v_calculado  raw(64);
    begin
        v_calculado := calcular_hash(i_password => i_password, i_salt => i_salt);
        return v_calculado is not null
           and i_hash      is not null
           and utl_raw.compare(v_calculado, i_hash) = 0;
    end es_valido;

    procedure validar_politica (
        i_password  in varchar2
    ) is
    begin
        if i_password is null
           or length(i_password) < c_password_min_len
           or not regexp_like(i_password, '[0-9]')
           or not regexp_like(i_password, '[A-Za-z]')
        then
            raise_application_error(c_err_politica,
                'La contraseña debe tener al menos ' || c_password_min_len ||
                ' caracteres e incluir letras y números.');
        end if;
    end validar_politica;

end adm_seg_password_utl;
/

-- >>> apps/adm/database/packages/adm_seg_usuario_ctr.pkb
create or replace package body adm_seg_usuario_ctr
as

    function obtener (
        i_usuario_id  in adm_seg_usuario.usuario_id%type
    ) return adm_seg_usuario%rowtype is
        r_usuario  adm_seg_usuario%rowtype;
    begin
        select * into r_usuario from adm_seg_usuario where usuario_id = i_usuario_id;
        return r_usuario;
    exception
        when no_data_found then
            raise_application_error(c_err_no_existe, 'El usuario ' || i_usuario_id || ' no existe.');
    end obtener;

    function obtener_por_username (
        i_username  in adm_seg_usuario.username%type
    ) return adm_seg_usuario%rowtype is
        r_usuario  adm_seg_usuario%rowtype;
    begin
        select * into r_usuario from adm_seg_usuario where username = upper(trim(i_username));
        return r_usuario;
    exception
        when no_data_found then
            return r_usuario;
    end obtener_por_username;

    procedure insertar (
        i_username               in  adm_seg_usuario.username%type,
        i_email                  in  adm_seg_usuario.email%type,
        i_nombres                in  adm_seg_usuario.nombres%type,
        i_apellidos              in  adm_seg_usuario.apellidos%type,
        i_tipo_autenticacion     in  adm_seg_usuario.tipo_autenticacion%type,
        i_password_hash          in  adm_seg_usuario.password_hash%type,
        i_password_salt          in  adm_seg_usuario.password_salt%type,
        i_debe_cambiar_password  in  adm_seg_usuario.debe_cambiar_password%type,
        i_empresa_id_defecto     in  adm_seg_usuario.empresa_id_defecto%type,
        o_usuario_id             out adm_seg_usuario.usuario_id%type
    ) is
    begin
        insert into adm_seg_usuario (
            username, email, nombres, apellidos, tipo_autenticacion,
            password_hash, password_salt, debe_cambiar_password, empresa_id_defecto)
        values (
            upper(trim(i_username)), lower(trim(i_email)), i_nombres, i_apellidos, i_tipo_autenticacion,
            i_password_hash, i_password_salt, i_debe_cambiar_password, i_empresa_id_defecto)
        returning usuario_id into o_usuario_id;
    end insertar;

    procedure actualizar (
        i_usuario_id          in adm_seg_usuario.usuario_id%type,
        i_email               in adm_seg_usuario.email%type,
        i_nombres             in adm_seg_usuario.nombres%type,
        i_apellidos           in adm_seg_usuario.apellidos%type,
        i_empresa_id_defecto  in adm_seg_usuario.empresa_id_defecto%type,
        i_estado              in adm_seg_usuario.estado%type
    ) is
    begin
        update adm_seg_usuario
           set email              = lower(trim(i_email)),
               nombres            = i_nombres,
               apellidos          = i_apellidos,
               empresa_id_defecto = i_empresa_id_defecto,
               estado             = i_estado
         where usuario_id = i_usuario_id;

        if sql%rowcount = 0 then
            raise_application_error(c_err_no_existe, 'El usuario ' || i_usuario_id || ' no existe.');
        end if;
    end actualizar;

    procedure actualizar_password (
        i_usuario_id             in adm_seg_usuario.usuario_id%type,
        i_password_hash          in adm_seg_usuario.password_hash%type,
        i_password_salt          in adm_seg_usuario.password_salt%type,
        i_debe_cambiar_password  in adm_seg_usuario.debe_cambiar_password%type
    ) is
    begin
        update adm_seg_usuario
           set password_hash         = i_password_hash,
               password_salt         = i_password_salt,
               debe_cambiar_password = i_debe_cambiar_password,
               fecha_cambio_password = systimestamp,
               intentos_fallidos     = 0
         where usuario_id = i_usuario_id;

        if sql%rowcount = 0 then
            raise_application_error(c_err_no_existe, 'El usuario ' || i_usuario_id || ' no existe.');
        end if;
    end actualizar_password;

    procedure actualizar_estado (
        i_usuario_id  in adm_seg_usuario.usuario_id%type,
        i_estado      in adm_seg_usuario.estado%type
    ) is
    begin
        update adm_seg_usuario
           set estado            = i_estado,
               intentos_fallidos = case when i_estado = 'A' then 0 else intentos_fallidos end
         where usuario_id = i_usuario_id;

        if sql%rowcount = 0 then
            raise_application_error(c_err_no_existe, 'El usuario ' || i_usuario_id || ' no existe.');
        end if;
    end actualizar_estado;

    procedure actualizar_intentos (
        i_usuario_id    in adm_seg_usuario.usuario_id%type,
        i_exitoso       in boolean,
        i_max_intentos  in pls_integer
    ) is
        pragma autonomous_transaction;
    begin
        if i_exitoso then
            update adm_seg_usuario
               set intentos_fallidos  = 0,
                   fecha_ultimo_login = systimestamp
             where usuario_id = i_usuario_id;
        else
            update adm_seg_usuario
               set intentos_fallidos = intentos_fallidos + 1,
                   estado            = case when intentos_fallidos + 1 >= i_max_intentos then 'B' else estado end
             where usuario_id = i_usuario_id;
        end if;
        commit;
    end actualizar_intentos;

end adm_seg_usuario_ctr;
/

-- >>> apps/adm/database/packages/adm_seg_usuario_rol_ctr.pkb
create or replace package body adm_seg_usuario_rol_ctr
as

    -- empresa_id null significa "todas las empresas": se compara null-safe
    function existe (
        i_usuario_id  in adm_seg_usuario_rol.usuario_id%type,
        i_rol_id      in adm_seg_usuario_rol.rol_id%type,
        i_empresa_id  in adm_seg_usuario_rol.empresa_id%type
    ) return boolean is
        v_cantidad  pls_integer;
    begin
        select count(*)
          into v_cantidad
          from adm_seg_usuario_rol
         where usuario_id = i_usuario_id
           and rol_id     = i_rol_id
           and decode(empresa_id, i_empresa_id, 1, 0) = 1;
        return v_cantidad > 0;
    end existe;

    procedure insertar (
        i_usuario_id   in adm_seg_usuario_rol.usuario_id%type,
        i_rol_id       in adm_seg_usuario_rol.rol_id%type,
        i_empresa_id   in adm_seg_usuario_rol.empresa_id%type,
        i_fecha_desde  in adm_seg_usuario_rol.fecha_desde%type,
        i_fecha_hasta  in adm_seg_usuario_rol.fecha_hasta%type
    ) is
    begin
        insert into adm_seg_usuario_rol (usuario_id, rol_id, empresa_id, fecha_desde, fecha_hasta)
        values (i_usuario_id, i_rol_id, i_empresa_id, i_fecha_desde, i_fecha_hasta);
    end insertar;

    procedure actualizar (
        i_usuario_id   in adm_seg_usuario_rol.usuario_id%type,
        i_rol_id       in adm_seg_usuario_rol.rol_id%type,
        i_empresa_id   in adm_seg_usuario_rol.empresa_id%type,
        i_fecha_desde  in adm_seg_usuario_rol.fecha_desde%type,
        i_fecha_hasta  in adm_seg_usuario_rol.fecha_hasta%type
    ) is
    begin
        update adm_seg_usuario_rol
           set fecha_desde = i_fecha_desde,
               fecha_hasta = i_fecha_hasta
         where usuario_id = i_usuario_id
           and rol_id     = i_rol_id
           and decode(empresa_id, i_empresa_id, 1, 0) = 1;
    end actualizar;

    procedure eliminar (
        i_usuario_id  in adm_seg_usuario_rol.usuario_id%type,
        i_rol_id      in adm_seg_usuario_rol.rol_id%type,
        i_empresa_id  in adm_seg_usuario_rol.empresa_id%type
    ) is
    begin
        delete from adm_seg_usuario_rol
         where usuario_id = i_usuario_id
           and rol_id     = i_rol_id
           and decode(empresa_id, i_empresa_id, 1, 0) = 1;
    end eliminar;

end adm_seg_usuario_rol_ctr;
/

-- >>> apps/adm/database/packages/adm_aud_login_ctr.pkb
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
        values (coalesce(substr(i_username, 1, 100), '(VACIO)'),   -- login enviado sin usuario
                i_resultado,
                to_number(sys_context('APEX$SESSION', 'APP_ID')),
                v_ip);
        commit;
    end insertar;

end adm_aud_login_ctr;
/

-- >>> apps/adm/database/packages/adm_aud_error_ctr.pkb
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

-- >>> apps/adm/database/packages/adm_gen_mensaje_error_ctr.pkb
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

-- >>> apps/adm/database/packages/adm_seg_seguridad_reg.pkb
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

-- >>> apps/adm/database/packages/adm_seg_usuario_reg.pkb
create or replace package body adm_seg_usuario_reg
as

    procedure validar_es_local (
        i_usuario_id  in adm_seg_usuario.usuario_id%type
    ) is
        r_usuario  adm_seg_usuario%rowtype;
    begin
        r_usuario := adm_seg_usuario_ctr.obtener(i_usuario_id => i_usuario_id);
        if r_usuario.tipo_autenticacion <> 'LOCAL' then
            raise_application_error(c_err_no_local,
                'El usuario ' || r_usuario.username || ' no usa autenticación local.');
        end if;
    end validar_es_local;

    procedure validar_cambio_password (
        i_usuario_id        in adm_seg_usuario.usuario_id%type,
        i_password_actual   in varchar2,
        i_password_nuevo    in varchar2,
        i_password_confirma in varchar2
    ) is
        r_usuario  adm_seg_usuario%rowtype;
    begin
        validar_es_local(i_usuario_id => i_usuario_id);
        r_usuario := adm_seg_usuario_ctr.obtener(i_usuario_id => i_usuario_id);

        if not adm_seg_password_utl.es_valido(i_password => i_password_actual,
                                              i_salt     => r_usuario.password_salt,
                                              i_hash     => r_usuario.password_hash)
        then
            raise_application_error(c_err_password_actual, 'La contraseña actual no es correcta.');
        end if;

        if i_password_nuevo is null or i_password_nuevo <> i_password_confirma then
            raise_application_error(c_err_confirmacion, 'La confirmación no coincide con la nueva contraseña.');
        end if;

        if i_password_actual = i_password_nuevo then
            raise_application_error(c_err_password_igual, 'La nueva contraseña debe ser distinta a la actual.');
        end if;

        adm_seg_password_utl.validar_politica(i_password => i_password_nuevo);
    end validar_cambio_password;

end adm_seg_usuario_reg;
/

-- >>> apps/adm/database/packages/adm_seg_usuario_api.pkb
create or replace package body adm_seg_usuario_api
as

    procedure crear (
        i_username            in  adm_seg_usuario.username%type,
        i_email               in  adm_seg_usuario.email%type,
        i_nombres             in  adm_seg_usuario.nombres%type,
        i_apellidos           in  adm_seg_usuario.apellidos%type default null,
        i_tipo_autenticacion  in  adm_seg_usuario.tipo_autenticacion%type default 'LOCAL',
        i_password            in  varchar2 default null,
        i_empresa_id_defecto  in  adm_seg_usuario.empresa_id_defecto%type default null,
        o_usuario_id          out adm_seg_usuario.usuario_id%type
    ) is
        v_salt  adm_seg_usuario.password_salt%type;
        v_hash  adm_seg_usuario.password_hash%type;
    begin
        if i_tipo_autenticacion = 'LOCAL' then
            adm_seg_password_utl.validar_politica(i_password => i_password);
            v_salt := adm_seg_password_utl.generar_salt;
            v_hash := adm_seg_password_utl.calcular_hash(i_password => i_password, i_salt => v_salt);
        end if;

        adm_seg_usuario_ctr.insertar(
            i_username              => i_username,
            i_email                 => i_email,
            i_nombres               => i_nombres,
            i_apellidos             => i_apellidos,
            i_tipo_autenticacion    => i_tipo_autenticacion,
            i_password_hash         => v_hash,
            i_password_salt         => v_salt,
            i_debe_cambiar_password => case when i_tipo_autenticacion = 'LOCAL' then 'S' else 'N' end,
            i_empresa_id_defecto    => i_empresa_id_defecto,
            o_usuario_id            => o_usuario_id);
    end crear;

    procedure modificar (
        i_usuario_id          in adm_seg_usuario.usuario_id%type,
        i_email               in adm_seg_usuario.email%type,
        i_nombres             in adm_seg_usuario.nombres%type,
        i_apellidos           in adm_seg_usuario.apellidos%type,
        i_empresa_id_defecto  in adm_seg_usuario.empresa_id_defecto%type,
        i_estado              in adm_seg_usuario.estado%type
    ) is
    begin
        adm_seg_usuario_ctr.actualizar(
            i_usuario_id         => i_usuario_id,
            i_email              => i_email,
            i_nombres            => i_nombres,
            i_apellidos          => i_apellidos,
            i_empresa_id_defecto => i_empresa_id_defecto,
            i_estado             => i_estado);
    end modificar;

    procedure resetear_password (
        i_usuario_id      in adm_seg_usuario.usuario_id%type,
        i_password_nuevo  in varchar2
    ) is
        v_salt  adm_seg_usuario.password_salt%type;
    begin
        adm_seg_usuario_reg.validar_es_local(i_usuario_id => i_usuario_id);
        adm_seg_password_utl.validar_politica(i_password => i_password_nuevo);
        v_salt := adm_seg_password_utl.generar_salt;

        adm_seg_usuario_ctr.actualizar_password(
            i_usuario_id            => i_usuario_id,
            i_password_hash         => adm_seg_password_utl.calcular_hash(i_password => i_password_nuevo, i_salt => v_salt),
            i_password_salt         => v_salt,
            i_debe_cambiar_password => 'S');
        adm_seg_usuario_ctr.actualizar_estado(i_usuario_id => i_usuario_id, i_estado => 'A');
    end resetear_password;

    procedure cambiar_password (
        i_username           in adm_seg_usuario.username%type,
        i_password_actual    in varchar2,
        i_password_nuevo     in varchar2,
        i_password_confirma  in varchar2
    ) is
        r_usuario  adm_seg_usuario%rowtype;
        v_salt     adm_seg_usuario.password_salt%type;
    begin
        r_usuario := adm_seg_usuario_ctr.obtener_por_username(i_username => i_username);
        if r_usuario.usuario_id is null then
            raise_application_error(adm_seg_usuario_ctr.c_err_no_existe, 'Usuario no encontrado.');
        end if;

        adm_seg_usuario_reg.validar_cambio_password(
            i_usuario_id        => r_usuario.usuario_id,
            i_password_actual   => i_password_actual,
            i_password_nuevo    => i_password_nuevo,
            i_password_confirma => i_password_confirma);

        v_salt := adm_seg_password_utl.generar_salt;
        adm_seg_usuario_ctr.actualizar_password(
            i_usuario_id            => r_usuario.usuario_id,
            i_password_hash         => adm_seg_password_utl.calcular_hash(i_password => i_password_nuevo, i_salt => v_salt),
            i_password_salt         => v_salt,
            i_debe_cambiar_password => 'N');
    end cambiar_password;

    procedure desbloquear (
        i_usuario_id  in adm_seg_usuario.usuario_id%type
    ) is
    begin
        adm_seg_usuario_ctr.actualizar_estado(i_usuario_id => i_usuario_id, i_estado => 'A');
    end desbloquear;

    procedure asignar_rol (
        i_usuario_id   in adm_seg_usuario_rol.usuario_id%type,
        i_rol_id       in adm_seg_usuario_rol.rol_id%type,
        i_empresa_id   in adm_seg_usuario_rol.empresa_id%type default null,
        i_fecha_desde  in adm_seg_usuario_rol.fecha_desde%type default trunc(current_date),
        i_fecha_hasta  in adm_seg_usuario_rol.fecha_hasta%type default null
    ) is
    begin
        if adm_seg_usuario_rol_ctr.existe(i_usuario_id => i_usuario_id,
                                          i_rol_id     => i_rol_id,
                                          i_empresa_id => i_empresa_id)
        then
            adm_seg_usuario_rol_ctr.actualizar(
                i_usuario_id  => i_usuario_id,
                i_rol_id      => i_rol_id,
                i_empresa_id  => i_empresa_id,
                i_fecha_desde => i_fecha_desde,
                i_fecha_hasta => i_fecha_hasta);
        else
            adm_seg_usuario_rol_ctr.insertar(
                i_usuario_id  => i_usuario_id,
                i_rol_id      => i_rol_id,
                i_empresa_id  => i_empresa_id,
                i_fecha_desde => i_fecha_desde,
                i_fecha_hasta => i_fecha_hasta);
        end if;
    end asignar_rol;

    procedure quitar_rol (
        i_usuario_id  in adm_seg_usuario_rol.usuario_id%type,
        i_rol_id      in adm_seg_usuario_rol.rol_id%type,
        i_empresa_id  in adm_seg_usuario_rol.empresa_id%type default null
    ) is
    begin
        adm_seg_usuario_rol_ctr.eliminar(
            i_usuario_id => i_usuario_id,
            i_rol_id     => i_rol_id,
            i_empresa_id => i_empresa_id);
    end quitar_rol;

end adm_seg_usuario_api;
/

-- >>> apps/adm/database/packages/adm_gen_error_api.pkb
create or replace package body adm_gen_error_api
as

    c_msg_inesperado  constant varchar2(200) :=
        'Ocurrió un error inesperado. Informe al administrador el código de incidente ';

    function registrar_incidente (
        i_componente   in varchar2,
        i_mensaje      in varchar2,
        i_ora_sqlcode  in number,
        i_ora_sqlerrm  in varchar2,
        i_backtrace    in varchar2
    ) return number is
        v_error_id  adm_aud_error.error_id%type;
    begin
        adm_aud_error_ctr.insertar(
            i_apex_app_id     => to_number(sys_context('APEX$SESSION', 'APP_ID')),
            i_apex_pagina_id  => to_number(sys_context('APEX$SESSION', 'APP_PAGE_ID')),
            i_username        => coalesce(sys_context('APEX$SESSION', 'APP_USER'), user),
            i_componente      => i_componente,
            i_mensaje         => i_mensaje,
            i_ora_sqlcode     => i_ora_sqlcode,
            i_ora_sqlerrm     => i_ora_sqlerrm,
            i_error_backtrace => i_backtrace,
            o_error_id        => v_error_id);
        return v_error_id;
    end registrar_incidente;

    function manejar_error_apex (
        p_error  in apex_error.t_error
    ) return apex_error.t_error_result is
        r_resultado   apex_error.t_error_result;
        v_constraint  varchar2(128);
        v_mensaje     adm_gen_mensaje_error.mensaje%type;
        v_error_id    number;

        function componente return varchar2 is
        begin
            return p_error.component.type || ': ' || p_error.component.name;
        end componente;
    begin
        r_resultado := apex_error.init_error_result(p_error => p_error);

        if p_error.is_internal_error then
            -- Errores comunes de ejecución (sesión expirada, acceso denegado) se muestran tal cual
            if not p_error.is_common_runtime_error then
                v_error_id := registrar_incidente(
                    i_componente  => componente,
                    i_mensaje     => p_error.message,
                    i_ora_sqlcode => p_error.ora_sqlcode,
                    i_ora_sqlerrm => p_error.ora_sqlerrm,
                    i_backtrace   => p_error.error_backtrace);
                r_resultado.message         := c_msg_inesperado || v_error_id || '.';
                r_resultado.additional_info := null;
            end if;
        else
            r_resultado.display_location :=
                case when r_resultado.display_location = apex_error.c_on_error_page
                     then apex_error.c_inline_in_notification
                     else r_resultado.display_location
                end;

            if p_error.ora_sqlcode in (-1, -2091, -2290, -2291, -2292) then
                v_constraint := apex_error.extract_constraint_name(p_error => p_error);
                v_mensaje    := adm_gen_mensaje_error_ctr.obtener_mensaje(i_codigo => v_constraint);
                if v_mensaje is not null then
                    r_resultado.message := v_mensaje;
                else
                    v_error_id := registrar_incidente(
                        i_componente  => componente,
                        i_mensaje     => 'Constraint sin mensaje: ' || v_constraint,
                        i_ora_sqlcode => p_error.ora_sqlcode,
                        i_ora_sqlerrm => p_error.ora_sqlerrm,
                        i_backtrace   => p_error.error_backtrace);
                    r_resultado.message := 'Los datos no cumplen una regla de integridad (' ||
                                           lower(v_constraint) || '). Incidente ' || v_error_id || '.';
                end if;
            elsif p_error.ora_sqlcode between -20999 and -20000 then
                r_resultado.message := apex_error.get_first_ora_error_text(p_error => p_error);
            elsif p_error.ora_sqlcode is not null then
                v_error_id := registrar_incidente(
                    i_componente  => componente,
                    i_mensaje     => p_error.message,
                    i_ora_sqlcode => p_error.ora_sqlcode,
                    i_ora_sqlerrm => p_error.ora_sqlerrm,
                    i_backtrace   => p_error.error_backtrace);
                r_resultado.message := c_msg_inesperado || v_error_id || '.';
            end if;

            -- Asociar el error al item/columna que lo causó cuando APEX puede deducirlo
            if r_resultado.page_item_name is null and r_resultado.column_alias is null then
                apex_error.auto_set_associated_item(p_error => p_error, p_error_result => r_resultado);
            end if;
        end if;

        return r_resultado;
    end manejar_error_apex;

    function registrar (
        i_componente  in varchar2,
        i_mensaje     in varchar2 default null
    ) return number is
    begin
        return registrar_incidente(
            i_componente  => i_componente,
            i_mensaje     => coalesce(i_mensaje, sqlerrm),
            i_ora_sqlcode => sqlcode,
            i_ora_sqlerrm => sqlerrm,
            i_backtrace   => dbms_utility.format_error_backtrace);
    end registrar;

    procedure registrar (
        i_componente  in varchar2,
        i_mensaje     in varchar2 default null
    ) is
        v_error_id  number;
    begin
        v_error_id := registrar(i_componente => i_componente, i_mensaje => i_mensaje);
    end registrar;

end adm_gen_error_api;
/
