create or replace package adm_seg_rol_ctr
    authid definer
    accessible by (package adm_seg_rol_api)
as
-- =============================================================================
-- Paquete : adm_seg_rol_ctr   (capa ctr)
-- Tabla   : adm_seg_rol
-- =============================================================================

    procedure insertar (
        i_aplicacion_id  in  adm_seg_rol.aplicacion_id%type,
        i_codigo         in  adm_seg_rol.codigo%type,
        i_nombre         in  adm_seg_rol.nombre%type,
        i_descripcion    in  adm_seg_rol.descripcion%type,
        i_es_superadmin  in  adm_seg_rol.es_superadmin%type,
        i_estado         in  adm_seg_rol.estado%type,
        o_rol_id         out adm_seg_rol.rol_id%type
    );

    procedure actualizar (
        i_rol_id         in adm_seg_rol.rol_id%type,
        i_aplicacion_id  in adm_seg_rol.aplicacion_id%type,
        i_codigo         in adm_seg_rol.codigo%type,
        i_nombre         in adm_seg_rol.nombre%type,
        i_descripcion    in adm_seg_rol.descripcion%type,
        i_es_superadmin  in adm_seg_rol.es_superadmin%type,
        i_estado         in adm_seg_rol.estado%type
    );

    procedure eliminar (
        i_rol_id  in adm_seg_rol.rol_id%type
    );

end adm_seg_rol_ctr;
/
