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
               select 'AUD',        'ADM_AUD_ERROR_VER',                 'Ver bitácora de errores',            'REPORTE'     from dual union all
               select 'AUD',        'ADM_AUD_CAMBIO_VER',                'Ver historial de cambios',           'REPORTE'     from dual) p
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
