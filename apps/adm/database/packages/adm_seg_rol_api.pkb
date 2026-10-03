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
