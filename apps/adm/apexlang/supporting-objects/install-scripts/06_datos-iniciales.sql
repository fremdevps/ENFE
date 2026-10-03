-- GENERADO por tools/build-supporting-objects.ps1 - NO EDITAR (fuente: apps/adm/database)

-- >>> apps/adm/database/data/adm_seg_datos_iniciales.sql
-- =============================================================================
-- Datos iniciales de seguridad central (idempotente: se puede re-ejecutar).
-- Registra la app ADM, sus módulos, permisos y roles base.
-- El usuario administrador se crea aparte (adm_seg_crear_admin.sql).
-- =============================================================================

-- Aplicaciones (IDs APEX fijos: ADM=100, ERP=200) -----------------------------
merge into adm_seg_aplicacion t
using (select 'ADM' codigo, 'Administración Central' nombre,
              'Seguridad, usuarios, roles y catálogo de aplicaciones' descripcion,
              100 apex_app_id, 'fa-shield' icono, 0 orden from dual
       union all
       select 'ERP', 'ERP', 'Planificación de recursos empresariales',
              200, 'fa-cubes', 10 from dual) s
   on (t.codigo = s.codigo)
 when matched then
    update set t.apex_app_id = nvl(t.apex_app_id, s.apex_app_id)
 when not matched then
    insert (codigo, nombre, descripcion, apex_app_id, icono, orden)
    values (s.codigo, s.nombre, s.descripcion, s.apex_app_id, s.icono, s.orden);

-- Módulos ---------------------------------------------------------------------
merge into adm_seg_modulo t
using (select a.aplicacion_id, m.codigo, m.nombre, m.orden
         from adm_seg_aplicacion a
        cross join (select 'SEG' codigo, 'Seguridad'  nombre, 10 orden from dual union all
                    select 'GEN',        'General',           20       from dual union all
                    select 'AUD',        'Auditoría',         30       from dual) m
        where a.codigo = 'ADM') s
   on (t.aplicacion_id = s.aplicacion_id and t.codigo = s.codigo)
 when not matched then
    insert (aplicacion_id, codigo, nombre, orden)
    values (s.aplicacion_id, s.codigo, s.nombre, s.orden);

-- Permisos --------------------------------------------------------------------
merge into adm_seg_permiso t
using (select m.modulo_id, p.codigo, p.nombre, p.tipo
         from adm_seg_modulo m
         join adm_seg_aplicacion a on a.aplicacion_id = m.aplicacion_id and a.codigo = 'ADM'
         join (select 'SEG' modulo, 'ADM_SEG_USUARIO_VER'        codigo, 'Ver usuarios'                 nombre, 'ACCION' tipo from dual union all
               select 'SEG',        'ADM_SEG_USUARIO_GESTIONAR',         'Crear/editar usuarios',              'ACCION'      from dual union all
               select 'SEG',        'ADM_SEG_USUARIO_RESET_PASSWORD',    'Resetear contraseñas',               'ACCION'      from dual union all
               select 'SEG',        'ADM_SEG_ROL_GESTIONAR',             'Gestionar roles y permisos',         'ACCION'      from dual union all
               select 'SEG',        'ADM_SEG_APLICACION_GESTIONAR',      'Gestionar aplicaciones y módulos',   'ACCION'      from dual union all
               select 'GEN',        'ADM_GEN_EMPRESA_GESTIONAR',         'Gestionar empresas',                 'ACCION'      from dual union all
               select 'GEN',        'ADM_GEN_MENSAJE_GESTIONAR',         'Gestionar mensajes de error',        'ACCION'      from dual union all
               select 'AUD',        'ADM_AUD_LOGIN_VER',                 'Ver bitácora de accesos',            'REPORTE'     from dual union all
               select 'AUD',        'ADM_AUD_ERROR_VER',                 'Ver bitácora de errores',            'REPORTE'     from dual) p
           on p.modulo = m.codigo) s
   on (t.codigo = s.codigo)
 when not matched then
    insert (modulo_id, codigo, nombre, tipo)
    values (s.modulo_id, s.codigo, s.nombre, s.tipo);

-- Roles -----------------------------------------------------------------------
merge into adm_seg_rol t
using (select null aplicacion_id, 'SUPERADMIN' codigo, 'Super Administrador' nombre,
              'Acceso total a todas las aplicaciones' descripcion, 'S' es_superadmin from dual
       union all
       select a.aplicacion_id, 'ADM_ADMINISTRADOR', 'Administrador de Seguridad',
              'Gestiona usuarios, roles y aplicaciones', 'N'
         from adm_seg_aplicacion a where a.codigo = 'ADM') s
   on (t.codigo = s.codigo)
 when not matched then
    insert (aplicacion_id, codigo, nombre, descripcion, es_superadmin)
    values (s.aplicacion_id, s.codigo, s.nombre, s.descripcion, s.es_superadmin);

-- ADM_ADMINISTRADOR recibe todos los permisos de la app ADM ------------------
merge into adm_seg_rol_permiso t
using (select r.rol_id, p.permiso_id
         from adm_seg_rol r
         join adm_seg_permiso p on 1 = 1
         join adm_seg_modulo m on m.modulo_id = p.modulo_id
         join adm_seg_aplicacion a on a.aplicacion_id = m.aplicacion_id and a.codigo = 'ADM'
        where r.codigo = 'ADM_ADMINISTRADOR') s
   on (t.rol_id = s.rol_id and t.permiso_id = s.permiso_id)
 when not matched then
    insert (rol_id, permiso_id) values (s.rol_id, s.permiso_id);

commit;

-- >>> apps/adm/database/data/adm_gen_mensajes_error.sql
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
