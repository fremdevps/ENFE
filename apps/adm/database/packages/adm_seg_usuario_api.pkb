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
