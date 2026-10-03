-- =============================================================================
-- Mensajes de error por constraint (idempotente). Cada app agrega los suyos
-- en sus propios datos semilla con este mismo patrón.
-- =============================================================================
merge into adm_gen_mensaje_error t
using (
    select 'UK_ADM_USU_USERNAME'      codigo, 'Ya existe un usuario con ese nombre de usuario.' mensaje from dual union all
    select 'UK_ADM_USU_EMAIL',                'Ya existe un usuario con ese correo electrónico.'        from dual union all
    select 'CK_ADM_USU_PASSWORD_LOCAL',       'Un usuario con autenticación local necesita contraseña.' from dual union all
    select 'UK_ADM_EMP_CODIGO',               'Ya existe una empresa con ese código.'                    from dual union all
    select 'UK_ADM_APL_CODIGO',               'Ya existe una aplicación con ese código.'                 from dual union all
    select 'UK_ADM_APL_APEX_APP_ID',          'Ese ID de aplicación APEX ya está asignado a otra aplicación.' from dual union all
    select 'CK_ADM_APL_CODIGO_MAYUS',         'El código de la aplicación debe estar en mayúsculas.'     from dual union all
    select 'UK_ADM_MOD_APL_CODIGO',           'Ya existe un módulo con ese código en la aplicación.'     from dual union all
    select 'CK_ADM_MOD_CODIGO_MAYUS',         'El código del módulo debe estar en mayúsculas.'           from dual union all
    select 'UK_ADM_PER_CODIGO',               'Ya existe un permiso con ese código.'                     from dual union all
    select 'CK_ADM_PER_PAGINA',               'Un permiso de tipo Página debe indicar la página APEX.'   from dual union all
    select 'CK_ADM_PER_CODIGO_MAYUS',         'El código del permiso debe estar en mayúsculas.'          from dual union all
    select 'UK_ADM_ROL_CODIGO',               'Ya existe un rol con ese código.'                         from dual union all
    select 'CK_ADM_ROL_CODIGO_MAYUS',         'El código del rol debe estar en mayúsculas.'              from dual union all
    select 'UK_ADM_ROPE_ROL_PERMISO',         'El rol ya tiene asignado ese permiso.'                    from dual union all
    select 'UK_ADM_USRO_USU_ROL_EMP',         'El usuario ya tiene ese rol para esa empresa.'            from dual union all
    select 'CK_ADM_USRO_VIGENCIA',            'La fecha Hasta debe ser igual o posterior a la fecha Desde.' from dual union all
    select 'FK_ADM_USRO_ROL',                 'No se puede eliminar el rol: está asignado a usuarios.'   from dual union all
    select 'FK_ADM_ROL_APL',                  'No se puede eliminar la aplicación: tiene roles.'         from dual union all
    select 'FK_ADM_MOD_APL',                  'No se puede eliminar la aplicación: tiene módulos.'       from dual union all
    select 'FK_ADM_PER_MOD',                  'No se puede eliminar el módulo: tiene permisos.'          from dual union all
    select 'FK_ADM_USU_EMP_DEF',              'No se puede eliminar la empresa: es la empresa por defecto de usuarios.' from dual union all
    select 'FK_ADM_USRO_EMP',                 'No se puede eliminar la empresa: tiene roles asignados.'  from dual union all
    select 'UK_ADM_MSE_CODIGO',               'Ya existe un mensaje para ese constraint.'                from dual
) s
   on (t.codigo = s.codigo)
 when matched then
    update set t.mensaje = s.mensaje
 when not matched then
    insert (codigo, mensaje) values (s.codigo, s.mensaje);

commit;
