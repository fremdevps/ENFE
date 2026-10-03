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
