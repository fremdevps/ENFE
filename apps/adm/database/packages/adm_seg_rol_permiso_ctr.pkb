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
