create or replace package adm_seg_rol_permiso_ctr
    authid definer
    accessible by (package adm_seg_rol_api)
as
-- =============================================================================
-- Paquete : adm_seg_rol_permiso_ctr   (capa ctr)
-- Tabla   : adm_seg_rol_permiso
-- =============================================================================

    procedure insertar (
        i_rol_id      in adm_seg_rol_permiso.rol_id%type,
        i_permiso_id  in adm_seg_rol_permiso.permiso_id%type
    );

    -- Elimina los permisos del rol que NO están en i_permisos_ids.
    procedure eliminar_no_incluidos (
        i_rol_id        in adm_seg_rol_permiso.rol_id%type,
        i_permisos_ids  in apex_t_number
    );

end adm_seg_rol_permiso_ctr;
/
