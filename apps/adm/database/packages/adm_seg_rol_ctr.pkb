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
