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
