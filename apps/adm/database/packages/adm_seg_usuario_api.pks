create or replace package adm_seg_usuario_api
    authid definer
as
-- =============================================================================
-- Paquete : adm_seg_usuario_api   (capa api)
-- Desc    : Fachada de gestión de usuarios para APEX, REST y scripts.
--           No hace COMMIT (en APEX confirma APEX; en scripts, el script).
-- =============================================================================

    procedure crear (
        i_username            in  adm_seg_usuario.username%type,
        i_email               in  adm_seg_usuario.email%type,
        i_nombres             in  adm_seg_usuario.nombres%type,
        i_apellidos           in  adm_seg_usuario.apellidos%type default null,
        i_tipo_autenticacion  in  adm_seg_usuario.tipo_autenticacion%type default 'LOCAL',
        i_password            in  varchar2 default null,
        i_empresa_id_defecto  in  adm_seg_usuario.empresa_id_defecto%type default null,
        o_usuario_id          out adm_seg_usuario.usuario_id%type
    );

    procedure modificar (
        i_usuario_id          in adm_seg_usuario.usuario_id%type,
        i_email               in adm_seg_usuario.email%type,
        i_nombres             in adm_seg_usuario.nombres%type,
        i_apellidos           in adm_seg_usuario.apellidos%type,
        i_empresa_id_defecto  in adm_seg_usuario.empresa_id_defecto%type,
        i_estado              in adm_seg_usuario.estado%type
    );

    -- Un administrador fija una contraseña temporal: el usuario deberá cambiarla
    -- y queda desbloqueado.
    procedure resetear_password (
        i_usuario_id      in adm_seg_usuario.usuario_id%type,
        i_password_nuevo  in varchar2
    );

    -- El propio usuario cambia su contraseña.
    procedure cambiar_password (
        i_username           in adm_seg_usuario.username%type,
        i_password_actual    in varchar2,
        i_password_nuevo     in varchar2,
        i_password_confirma  in varchar2
    );

    procedure desbloquear (
        i_usuario_id  in adm_seg_usuario.usuario_id%type
    );

    -- Asigna (o actualiza la vigencia de) un rol. i_empresa_id null = todas.
    procedure asignar_rol (
        i_usuario_id   in adm_seg_usuario_rol.usuario_id%type,
        i_rol_id       in adm_seg_usuario_rol.rol_id%type,
        i_empresa_id   in adm_seg_usuario_rol.empresa_id%type default null,
        i_fecha_desde  in adm_seg_usuario_rol.fecha_desde%type default trunc(current_date),
        i_fecha_hasta  in adm_seg_usuario_rol.fecha_hasta%type default null
    );

    procedure quitar_rol (
        i_usuario_id  in adm_seg_usuario_rol.usuario_id%type,
        i_rol_id      in adm_seg_usuario_rol.rol_id%type,
        i_empresa_id  in adm_seg_usuario_rol.empresa_id%type default null
    );

end adm_seg_usuario_api;
/
