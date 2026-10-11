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

-- >>> apps/adm/database/packages/adm_seg_rol_ctr.pkb
create or replace package body adm_seg_rol_ctr
as

    procedure insertar (
        i_aplicacion_id  in  adm_seg_rol.aplicacion_id%type,
        i_codigo         in  adm_seg_rol.codigo%type,
        i_nombre         in  adm_seg_rol.nombre%type,
        i_descripcion    in  adm_seg_rol.descripcion%type,
        i_es_superadmin  in  adm_seg_rol.es_superadmin%type,
        i_estado         in  adm_seg_rol.estado%type,
        o_rol_id         out adm_seg_rol.rol_id%type
    ) is
    begin
        insert into adm_seg_rol (aplicacion_id, codigo, nombre, descripcion, es_superadmin, estado)
        values (i_aplicacion_id, upper(trim(i_codigo)), i_nombre, i_descripcion, i_es_superadmin, i_estado)
        returning rol_id into o_rol_id;
    end insertar;

    procedure actualizar (
        i_rol_id         in adm_seg_rol.rol_id%type,
        i_aplicacion_id  in adm_seg_rol.aplicacion_id%type,
        i_codigo         in adm_seg_rol.codigo%type,
        i_nombre         in adm_seg_rol.nombre%type,
        i_descripcion    in adm_seg_rol.descripcion%type,
        i_es_superadmin  in adm_seg_rol.es_superadmin%type,
        i_estado         in adm_seg_rol.estado%type
    ) is
    begin
        update adm_seg_rol
           set aplicacion_id = i_aplicacion_id,
               codigo        = upper(trim(i_codigo)),
               nombre        = i_nombre,
               descripcion   = i_descripcion,
               es_superadmin = i_es_superadmin,
               estado        = i_estado
         where rol_id = i_rol_id;
    end actualizar;

    procedure eliminar (
        i_rol_id  in adm_seg_rol.rol_id%type
    ) is
    begin
        delete from adm_seg_rol where rol_id = i_rol_id;
    end eliminar;

end adm_seg_rol_ctr;
/

-- >>> apps/adm/database/packages/adm_seg_rol_permiso_ctr.pkb
create or replace package body adm_seg_rol_permiso_ctr
as

    procedure insertar (
        i_rol_id      in adm_seg_rol_permiso.rol_id%type,
        i_permiso_id  in adm_seg_rol_permiso.permiso_id%type
    ) is
    begin
        merge into adm_seg_rol_permiso t
        using (select i_rol_id rol_id, i_permiso_id permiso_id from dual) s
           on (t.rol_id = s.rol_id and t.permiso_id = s.permiso_id)
         when not matched then
            insert (rol_id, permiso_id) values (s.rol_id, s.permiso_id);
    end insertar;

    procedure eliminar_no_incluidos (
        i_rol_id        in adm_seg_rol_permiso.rol_id%type,
        i_permisos_ids  in apex_t_number
    ) is
    begin
        delete from adm_seg_rol_permiso
         where rol_id = i_rol_id
           and permiso_id not in (select column_value from table(i_permisos_ids));
    end eliminar_no_incluidos;

end adm_seg_rol_permiso_ctr;
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

-- >>> apps/adm/database/packages/adm_seg_rol_api.pkb
create or replace package body adm_seg_rol_api
as

    -- El rol SUPERADMIN es parte del bootstrap: no se renombra, desactiva ni elimina.
    procedure validar_no_es_superadmin_base (
        i_rol_id  in adm_seg_rol.rol_id%type
    ) is
        v_codigo  adm_seg_rol.codigo%type;
    begin
        select codigo into v_codigo from adm_seg_rol where rol_id = i_rol_id;
        if v_codigo = 'SUPERADMIN' then
            raise_application_error(c_err_superadmin_protegido,
                'El rol SUPERADMIN es del sistema y no puede modificarse ni eliminarse.');
        end if;
    end validar_no_es_superadmin_base;

    procedure crear (
        i_aplicacion_id  in  adm_seg_rol.aplicacion_id%type,
        i_codigo         in  adm_seg_rol.codigo%type,
        i_nombre         in  adm_seg_rol.nombre%type,
        i_descripcion    in  adm_seg_rol.descripcion%type,
        i_es_superadmin  in  adm_seg_rol.es_superadmin%type,
        i_estado         in  adm_seg_rol.estado%type,
        o_rol_id         out adm_seg_rol.rol_id%type
    ) is
    begin
        adm_seg_rol_ctr.insertar(
            i_aplicacion_id => i_aplicacion_id,
            i_codigo        => i_codigo,
            i_nombre        => i_nombre,
            i_descripcion   => i_descripcion,
            i_es_superadmin => coalesce(i_es_superadmin, 'N'),
            i_estado        => coalesce(i_estado, 'A'),
            o_rol_id        => o_rol_id);
    end crear;

    procedure modificar (
        i_rol_id         in adm_seg_rol.rol_id%type,
        i_aplicacion_id  in adm_seg_rol.aplicacion_id%type,
        i_codigo         in adm_seg_rol.codigo%type,
        i_nombre         in adm_seg_rol.nombre%type,
        i_descripcion    in adm_seg_rol.descripcion%type,
        i_es_superadmin  in adm_seg_rol.es_superadmin%type,
        i_estado         in adm_seg_rol.estado%type
    ) is
    begin
        validar_no_es_superadmin_base(i_rol_id => i_rol_id);
        adm_seg_rol_ctr.actualizar(
            i_rol_id        => i_rol_id,
            i_aplicacion_id => i_aplicacion_id,
            i_codigo        => i_codigo,
            i_nombre        => i_nombre,
            i_descripcion   => i_descripcion,
            i_es_superadmin => i_es_superadmin,
            i_estado        => i_estado);
    end modificar;

    procedure eliminar (
        i_rol_id  in adm_seg_rol.rol_id%type
    ) is
    begin
        validar_no_es_superadmin_base(i_rol_id => i_rol_id);
        adm_seg_rol_ctr.eliminar(i_rol_id => i_rol_id);
    end eliminar;

    procedure asignar_permisos (
        i_rol_id    in adm_seg_rol.rol_id%type,
        i_permisos  in varchar2
    ) is
        v_ids  apex_t_number := apex_string.split_numbers(p_str => i_permisos, p_sep => ':');
    begin
        adm_seg_rol_permiso_ctr.eliminar_no_incluidos(i_rol_id => i_rol_id, i_permisos_ids => v_ids);
        for i in 1 .. v_ids.count loop
            adm_seg_rol_permiso_ctr.insertar(i_rol_id => i_rol_id, i_permiso_id => v_ids(i));
        end loop;
    end asignar_permisos;

    function obtener_permisos (
        i_rol_id  in adm_seg_rol.rol_id%type
    ) return varchar2 is
        v_lista  varchar2(32767);
    begin
        select listagg(permiso_id, ':') within group (order by permiso_id)
          into v_lista
          from adm_seg_rol_permiso
         where rol_id = i_rol_id;
        return v_lista;
    end obtener_permisos;

end adm_seg_rol_api;
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

-- >>> apps/adm/database/packages/adm_aud_cambio_utl.pkb
create or replace package body adm_aud_cambio_utl
as

    c_nl                 constant varchar2(1)   := chr(10);
    c_patron_reservado   constant varchar2(100) := 'PASSWORD|HASH|TOKEN|CLAVE|SECRET|SALT';
    c_formato_fecha      constant varchar2(40)  := 'YYYY-MM-DD"T"HH24:MI:SS';
    c_formato_fecha_hora constant varchar2(40)  := 'YYYY-MM-DD"T"HH24:MI:SS.FF6';
    c_formato_tz         constant varchar2(40)  := 'YYYY-MM-DD"T"HH24:MI:SS.FF6TZH:TZM';

    -- Datos de la tabla que necesita el generador.
    type t_tabla is record (
        nombre      varchar2(128),      -- en mayúsculas
        app         varchar2(30),
        abreviatura varchar2(30),
        nombre_trigger varchar2(128),   -- en minúsculas
        pk          varchar2(128),
        tiene_empresa boolean
    );

    -- ------------------------------------------------------------------ privados
    function esta_en_lista (
        i_lista    in varchar2,
        i_columna  in varchar2
    ) return boolean is
    begin
        return instr(',' || replace(upper(i_lista), ' ') || ',', ',' || upper(i_columna) || ',') > 0;
    end esta_en_lista;

    function obtener_tabla (
        i_tabla  in varchar2
    ) return t_tabla is
        r_tabla       t_tabla;
        v_comentario  user_tab_comments.comments%type;
        v_cantidad    pls_integer;
        v_tipo        user_tab_cols.data_type%type;
    begin
        r_tabla.nombre := upper(trim(i_tabla));

        begin
            select c.comments
              into v_comentario
              from user_tables t
              left join user_tab_comments c on c.table_name = t.table_name
             where t.table_name = r_tabla.nombre;
        exception
            when no_data_found then
                raise_application_error(c_err_no_auditable, 'No existe la tabla ' || lower(r_tabla.nombre) || '.');
        end;

        r_tabla.app         := regexp_substr(r_tabla.nombre, '^[^_]+');
        r_tabla.abreviatura := upper(regexp_substr(v_comentario, 'Abrev:\s*(\w+)', 1, 1, 'i', 1));
        if r_tabla.abreviatura is null then
            raise_application_error(c_err_no_auditable,
                'La tabla ' || lower(r_tabla.nombre) || ' no tiene abreviatura en su comentario ("Abrev: xxx").');
        end if;

        r_tabla.nombre_trigger := lower('trg_' || r_tabla.app || '_' || r_tabla.abreviatura || '_aiud');
        if length(r_tabla.nombre_trigger) > 30 then
            raise_application_error(c_err_no_auditable,
                'El nombre ' || r_tabla.nombre_trigger || ' supera los 30 caracteres.');
        end if;

        select count(*), max(cc.column_name)
          into v_cantidad, r_tabla.pk
          from user_constraints k
          join user_cons_columns cc on cc.constraint_name = k.constraint_name
         where k.table_name = r_tabla.nombre
           and k.constraint_type = 'P';
        if v_cantidad <> 1 then
            raise_application_error(c_err_no_auditable,
                'La tabla ' || lower(r_tabla.nombre) || ' debe tener una clave primaria de una sola columna.');
        end if;

        select c.data_type
          into v_tipo
          from user_tab_cols c
         where c.table_name = r_tabla.nombre
           and c.column_name = r_tabla.pk;
        if v_tipo <> 'NUMBER' then
            raise_application_error(c_err_no_auditable,
                'La clave primaria de ' || lower(r_tabla.nombre) || ' debe ser numérica.');
        end if;

        select count(*)
          into v_cantidad
          from user_tab_cols c
         where c.table_name = r_tabla.nombre
           and c.column_name = 'EMPRESA_ID'
           and c.data_type = 'NUMBER';
        r_tabla.tiene_empresa := v_cantidad = 1;

        return r_tabla;
    end obtener_tabla;

    -- Código del trigger, sin el "/" final.
    function generar_codigo (
        i_tabla                in varchar2,
        i_columna_padre        in varchar2,
        i_columnas_excluidas   in varchar2,
        i_columnas_reservadas  in varchar2
    ) return clob is
        r_tabla       t_tabla := obtener_tabla(i_tabla);
        v_padre       varchar2(128) := upper(trim(i_columna_padre));
        v_cantidad    pls_integer;
        v_lineas      clob;             -- llamadas agregar_* (una por columna)
        v_reservadas  varchar2(4000);
        v_omitidas    varchar2(4000);
        v_codigo      clob;
        v_col         varchar2(128);
        v_proc        varchar2(30);
        v_llamada     varchar2(400);
        v_registro    varchar2(300);
        v_cascada     pls_integer;      -- FK on delete cascade / set null hacia un padre

        procedure escribir (i_linea in varchar2 default null) is
        begin
            v_codigo := v_codigo || i_linea || c_nl;
        end escribir;

        procedure anotar (io_lista in out nocopy varchar2, i_texto in varchar2) is
        begin
            io_lista := substr(io_lista || case when io_lista is not null then ', ' end || i_texto, 1, 4000);
        end anotar;
    begin
        if v_padre is not null then
            select count(*)
              into v_cantidad
              from user_tab_cols c
             where c.table_name = r_tabla.nombre
               and c.column_name = v_padre
               and c.data_type = 'NUMBER';
            if v_cantidad = 0 then
                raise_application_error(c_err_no_auditable,
                    'La columna padre ' || lower(v_padre) || ' no existe en ' || lower(r_tabla.nombre) || ' o no es numérica.');
            end if;
        end if;

        for r_col in (select c.column_name, c.data_type, c.char_length
                        from user_tab_cols c
                       where c.table_name = r_tabla.nombre
                         and c.hidden_column = 'NO'
                         and c.virtual_column = 'NO'
                       order by c.column_id) loop
            v_col := lower(r_col.column_name);

            if r_col.column_name = r_tabla.pk then
                anotar(v_omitidas, v_col || ' (PK: va en registro_id)');
                continue;
            elsif r_col.column_name in ('CREADO_POR', 'FECHA_CREACION', 'MODIFICADO_POR', 'FECHA_MODIFICACION') then
                continue;
            elsif esta_en_lista(i_columnas_excluidas, r_col.column_name) then
                anotar(v_omitidas, v_col || ' (excluida)');
                continue;
            end if;

            v_proc := case
                          when r_col.data_type in ('VARCHAR2', 'CHAR', 'NVARCHAR2', 'NCHAR') then 'agregar_texto'
                          when r_col.data_type in ('NUMBER', 'FLOAT', 'BINARY_FLOAT', 'BINARY_DOUBLE') then 'agregar_numero'
                          when r_col.data_type = 'DATE' then 'agregar_fecha'
                          when r_col.data_type like 'TIMESTAMP%TIME ZONE' then 'agregar_fecha_hora_tz'
                          when r_col.data_type like 'TIMESTAMP%' then 'agregar_fecha_hora'
                          when r_col.data_type = 'RAW' then 'agregar_binario'
                      end;
            if v_proc is null then
                anotar(v_omitidas, v_col || ' (' || lower(r_col.data_type) || ')');
                continue;
            end if;

            if esta_en_lista(i_columnas_reservadas, r_col.column_name)
               or (regexp_like(r_col.column_name, c_patron_reservado)
                   and (v_proc in ('agregar_numero', 'agregar_binario')
                        or (v_proc = 'agregar_texto' and r_col.char_length > 1))) then
                anotar(v_reservadas, v_col);
                v_lineas := v_lineas
                    || '        if (:old.' || v_col || ' is null and :new.' || v_col || ' is not null)' || c_nl
                    || '           or (:old.' || v_col || ' is not null and :new.' || v_col || ' is null)' || c_nl
                    || '           or :old.' || v_col || ' <> :new.' || v_col || ' then' || c_nl
                    || '            adm_aud_cambio_utl.agregar_reservado(v_detalle, ''' || v_col || ''');' || c_nl
                    || '        end if;' || c_nl;
            else
                v_llamada := '        adm_aud_cambio_utl.' || rpad(v_proc || '(v_detalle,', 34)
                    || rpad('''' || v_col || ''',', 34) || ':old.' || v_col || ', :new.' || v_col || ');';
                v_lineas := v_lineas || v_llamada || c_nl;
            end if;
        end loop;

        if v_lineas is null then
            raise_application_error(c_err_no_auditable,
                'La tabla ' || lower(r_tabla.nombre) || ' no tiene columnas para auditar.');
        end if;

        -- Un borrado en cascada (o un set null) que llega desde la tabla padre ejecuta
        -- la sección de fila de este trigger pero NO su "after statement".
        -- 0 = ninguna, 1 = cascade, 2 o 3 = set null
        select sign(count(case when k.delete_rule = 'CASCADE' then 1 end))
               + 2 * sign(count(case when k.delete_rule = 'SET NULL' then 1 end))
          into v_cascada
          from user_constraints k
         where k.table_name = r_tabla.nombre
           and k.constraint_type = 'R'
           and k.delete_rule in ('CASCADE', 'SET NULL');

        v_registro := 'coalesce(:new.' || lower(r_tabla.pk) || ', :old.' || lower(r_tabla.pk) || ')';

        escribir('-- =============================================================================');
        escribir('-- Trigger : ' || r_tabla.nombre_trigger);
        escribir('-- Tabla   : ' || lower(r_tabla.nombre));
        escribir('-- Desc    : Historial de cambios en adm_aud_cambio (compound, inserción por lote).');
        escribir('--           GENERADO: no editar a mano. Para regenerarlo (desde la raíz del repositorio):');
        escribir('--             @tools/db/generar_trigger_historial.sql ' || lower(r_tabla.nombre)
                 || ' ' || coalesce(lower(v_padre), '_')
                 || ' ' || coalesce(lower(replace(i_columnas_excluidas, ' ')), '_')
                 || ' ' || coalesce(lower(replace(i_columnas_reservadas, ' ')), '_'));
        if v_reservadas is not null then
            escribir('-- Reservadas (solo se registra que cambiaron): ' || v_reservadas);
        end if;
        if v_omitidas is not null then
            escribir('-- No auditadas: ' || v_omitidas || ' y las columnas de auditoría.');
        end if;
        escribir('-- =============================================================================');
        escribir('create or replace trigger ' || r_tabla.nombre_trigger);
        escribir('    for insert or update or delete on ' || lower(r_tabla.nombre));
        escribir('    compound trigger');
        escribir;
        escribir('    v_cambios  adm_aud_cambio_api.t_cambios;');
        escribir;
        escribir('    after each row is');
        escribir('        v_detalle  json_array_t := json_array_t();');
        escribir('    begin');
        v_codigo := v_codigo || v_lineas;
        escribir;
        escribir('        adm_aud_cambio_api.agregar(');
        escribir('            io_cambios          => v_cambios,');
        escribir('            i_app_codigo        => ''' || r_tabla.app || ''',');
        escribir('            i_tabla             => ''' || r_tabla.nombre || ''',');
        escribir('            i_registro_id       => ' || v_registro || ',');
        escribir('            i_registro_padre_id => ' || case when v_padre is null then 'null'
                     else 'coalesce(:new.' || lower(v_padre) || ', :old.' || lower(v_padre) || ')' end || ',');
        escribir('            i_empresa_id        => ' || case when r_tabla.tiene_empresa
                     then 'coalesce(:new.empresa_id, :old.empresa_id)' else 'null' end || ',');
        escribir('            i_operacion         => case when inserting then ''I'' when updating then ''U'' else ''D'' end,');
        escribir('            i_detalle           => v_detalle);');
        if v_cascada > 0 then
            escribir;
            escribir('        -- La tabla tiene una FK ' || case when v_cascada >= 2 then 'on delete set null' else 'on delete cascade' end
                     || ': cuando el cambio llega desde la tabla padre');
            escribir('        -- no se ejecuta "after statement", así que se inserta en el momento.');
            if v_cascada >= 2 then
                escribir('        if deleting or updating then');
            else
                escribir('        if deleting then');
            end if;
            escribir('            adm_aud_cambio_api.registrar(io_cambios => v_cambios);');
            escribir('        end if;');
        end if;
        escribir('    end after each row;');
        escribir;
        escribir('    after statement is');
        escribir('    begin');
        escribir('        adm_aud_cambio_api.registrar(io_cambios => v_cambios);');
        escribir('    end after statement;');
        escribir;
        v_codigo := v_codigo || 'end ' || r_tabla.nombre_trigger || ';';
        return v_codigo;
    end generar_codigo;

    -- Agrega el elemento ya convertido a texto (o número) al detalle.
    procedure agregar_elemento (
        io_detalle        in out nocopy json_array_t,
        i_columna         in varchar2,
        i_antes           in varchar2,
        i_despues         in varchar2
    ) is
        v_elemento  json_object_t := json_object_t();
    begin
        v_elemento.put('col', i_columna);
        if i_antes is null then
            v_elemento.put_null('antes');
        else
            v_elemento.put('antes', i_antes);
        end if;
        if i_despues is null then
            v_elemento.put_null('despues');
        else
            v_elemento.put('despues', i_despues);
        end if;
        io_detalle.append(v_elemento);
    end agregar_elemento;

    -- ------------------------------------------------------------------ públicos
    function generar_trigger (
        i_tabla                in varchar2,
        i_columna_padre        in varchar2 default null,
        i_columnas_excluidas   in varchar2 default null,
        i_columnas_reservadas  in varchar2 default null
    ) return clob is
    begin
        return generar_codigo(
                   i_tabla               => i_tabla,
                   i_columna_padre       => i_columna_padre,
                   i_columnas_excluidas  => i_columnas_excluidas,
                   i_columnas_reservadas => i_columnas_reservadas) || c_nl || '/' || c_nl;
    end generar_trigger;

    function obtener_nombre_trigger (
        i_tabla  in varchar2
    ) return varchar2 is
    begin
        return obtener_tabla(i_tabla => i_tabla).nombre_trigger;
    end obtener_nombre_trigger;

    procedure crear_trigger (
        i_tabla                in varchar2,
        i_columna_padre        in varchar2 default null,
        i_columnas_excluidas   in varchar2 default null,
        i_columnas_reservadas  in varchar2 default null
    ) is
    begin
        execute immediate generar_codigo(
                              i_tabla               => i_tabla,
                              i_columna_padre       => i_columna_padre,
                              i_columnas_excluidas  => i_columnas_excluidas,
                              i_columnas_reservadas => i_columnas_reservadas);
    end crear_trigger;

    procedure agregar_texto (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in varchar2,
        i_despues   in varchar2
    ) is
    begin
        if i_antes = i_despues or (i_antes is null and i_despues is null) then
            return;
        end if;
        agregar_elemento(io_detalle, i_columna, i_antes, i_despues);
    end agregar_texto;

    procedure agregar_numero (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in number,
        i_despues   in number
    ) is
        v_elemento  json_object_t;
    begin
        if i_antes = i_despues or (i_antes is null and i_despues is null) then
            return;
        end if;
        -- Número JSON (sin máscara ni separadores de la sesión)
        v_elemento := json_object_t();
        v_elemento.put('col', i_columna);
        if i_antes is null then
            v_elemento.put_null('antes');
        else
            v_elemento.put('antes', i_antes);
        end if;
        if i_despues is null then
            v_elemento.put_null('despues');
        else
            v_elemento.put('despues', i_despues);
        end if;
        io_detalle.append(v_elemento);
    end agregar_numero;

    procedure agregar_fecha (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in date,
        i_despues   in date
    ) is
    begin
        if i_antes = i_despues or (i_antes is null and i_despues is null) then
            return;
        end if;
        agregar_elemento(io_detalle, i_columna,
                         to_char(i_antes, c_formato_fecha), to_char(i_despues, c_formato_fecha));
    end agregar_fecha;

    procedure agregar_fecha_hora (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in timestamp,
        i_despues   in timestamp
    ) is
    begin
        if i_antes = i_despues or (i_antes is null and i_despues is null) then
            return;
        end if;
        agregar_elemento(io_detalle, i_columna,
                         to_char(i_antes, c_formato_fecha_hora), to_char(i_despues, c_formato_fecha_hora));
    end agregar_fecha_hora;

    procedure agregar_fecha_hora_tz (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in timestamp with time zone,
        i_despues   in timestamp with time zone
    ) is
    begin
        if i_antes = i_despues or (i_antes is null and i_despues is null) then
            return;
        end if;
        agregar_elemento(io_detalle, i_columna,
                         to_char(i_antes, c_formato_tz), to_char(i_despues, c_formato_tz));
    end agregar_fecha_hora_tz;

    procedure agregar_binario (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2,
        i_antes     in raw,
        i_despues   in raw
    ) is
    begin
        if i_antes = i_despues or (i_antes is null and i_despues is null) then
            return;
        end if;
        agregar_elemento(io_detalle, i_columna, rawtohex(i_antes), rawtohex(i_despues));
    end agregar_binario;

    procedure agregar_reservado (
        io_detalle  in out nocopy json_array_t,
        i_columna   in varchar2
    ) is
        v_elemento  json_object_t := json_object_t();
    begin
        v_elemento.put('col', i_columna);
        v_elemento.put_null('antes');
        v_elemento.put_null('despues');
        v_elemento.put('reservado', true);
        io_detalle.append(v_elemento);
    end agregar_reservado;

end adm_aud_cambio_utl;
/

-- >>> apps/adm/database/packages/adm_aud_cambio_ctr.pkb
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

-- >>> apps/adm/database/packages/adm_aud_cambio_api.pkb
create or replace package body adm_aud_cambio_api
as

    e_json_muy_grande  exception;
    pragma exception_init(e_json_muy_grande, -40478);

    procedure agregar (
        io_cambios           in out nocopy t_cambios,
        i_app_codigo         in adm_aud_cambio.app_codigo%type,
        i_tabla              in adm_aud_cambio.tabla%type,
        i_registro_id        in adm_aud_cambio.registro_id%type,
        i_registro_padre_id  in adm_aud_cambio.registro_padre_id%type,
        i_empresa_id         in adm_aud_cambio.empresa_id%type,
        i_operacion          in adm_aud_cambio.operacion%type,
        i_detalle            in json_array_t
    ) is
        r_cambio  adm_aud_cambio_ctr.t_cambio;
    begin
        if i_detalle is null or i_detalle.get_size = 0 then
            return;
        end if;

        r_cambio.app_codigo        := i_app_codigo;
        r_cambio.tabla             := i_tabla;
        r_cambio.registro_id       := i_registro_id;
        r_cambio.registro_padre_id := i_registro_padre_id;
        r_cambio.empresa_id        := i_empresa_id;
        r_cambio.operacion         := i_operacion;

        begin
            r_cambio.cambios := i_detalle.to_string;
        exception
            when e_json_muy_grande then
                -- Más de 32767 bytes: se inserta sola, como CLOB
                adm_aud_cambio_ctr.insertar(i_cambio => r_cambio, i_cambios => i_detalle.to_clob);
                return;
        end;

        io_cambios(io_cambios.count + 1) := r_cambio;
        if io_cambios.count >= c_filas_lote then
            registrar(io_cambios => io_cambios);
        end if;
    end agregar;

    procedure registrar (
        io_cambios  in out nocopy t_cambios
    ) is
    begin
        adm_aud_cambio_ctr.insertar_lote(i_cambios => io_cambios);
        io_cambios.delete;
    end registrar;

    procedure purgar (
        i_meses_retencion  in  number default c_meses_retencion,
        o_filas            out number
    ) is
    begin
        if i_meses_retencion is null or i_meses_retencion < 1 or i_meses_retencion <> trunc(i_meses_retencion) then
            raise_application_error(c_err_retencion,
                'La retención del historial de cambios debe ser un número entero de meses, mínimo 1.');
        end if;

        adm_aud_cambio_ctr.eliminar_anteriores(
            i_fecha_limite => add_months(trunc(sysdate, 'MM'), -i_meses_retencion),
            o_filas        => o_filas);
    end purgar;

    procedure ejecutar_purga (
        i_meses_retencion  in number default c_meses_retencion
    ) is
        v_filas  number;
    begin
        purgar(i_meses_retencion => i_meses_retencion, o_filas => v_filas);
        commit;
    exception
        when others then
            rollback;
            adm_gen_error_api.registrar(i_componente => 'adm_aud_cambio_api.ejecutar_purga');
            raise;
    end ejecutar_purga;

end adm_aud_cambio_api;
/
