create or replace package adm_seg_rol_api
    authid definer
as
-- =============================================================================
-- Paquete : adm_seg_rol_api   (capa api)
-- Desc    : Gestión de roles y sus permisos para APEX / REST.
-- =============================================================================

    c_err_superadmin_protegido  constant pls_integer := -20030;

    procedure crear (
        i_aplicacion_id  in  adm_seg_rol.aplicacion_id%type,
        i_codigo         in  adm_seg_rol.codigo%type,
        i_nombre         in  adm_seg_rol.nombre%type,
        i_descripcion    in  adm_seg_rol.descripcion%type,
        i_es_superadmin  in  adm_seg_rol.es_superadmin%type,
        i_estado         in  adm_seg_rol.estado%type,
        o_rol_id         out adm_seg_rol.rol_id%type
    );

    procedure modificar (
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

    -- Deja al rol exactamente con los permisos indicados (lista "1:5:9" de APEX).
    procedure asignar_permisos (
        i_rol_id    in adm_seg_rol.rol_id%type,
        i_permisos  in varchar2
    );

    -- Permisos del rol en formato "1:5:9" (para el shuttle de APEX).
    function obtener_permisos (
        i_rol_id  in adm_seg_rol.rol_id%type
    ) return varchar2;

end adm_seg_rol_api;
/
