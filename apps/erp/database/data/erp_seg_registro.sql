-- =============================================================================
-- Registro del ERP en la seguridad central (ADM). Idempotente.
-- Requiere que ADM esté instalado (adm_seg_aplicacion con codigo = 'ERP').
-- =============================================================================

-- Módulos del ERP -------------------------------------------------------------
merge into adm_seg_modulo t
using (select a.aplicacion_id, m.codigo, m.nombre, m.icono, m.orden
         from adm_seg_aplicacion a
        cross join (select 'FIN' codigo, 'Finanzas'       nombre, 'fa-money'        icono, 10 orden from dual union all
                    select 'STK',        'Inventario',            'fa-cubes',             20       from dual union all
                    select 'COM',        'Compras',               'fa-shopping-cart',     30       from dual union all
                    select 'VEN',        'Ventas',                'fa-line-chart',        40       from dual union all
                    select 'PRD',        'Producción',            'fa-industry',          50       from dual) m
        where a.codigo = 'ERP') s
   on (t.aplicacion_id = s.aplicacion_id and t.codigo = s.codigo)
 when not matched then
    insert (aplicacion_id, codigo, nombre, icono, orden)
    values (s.aplicacion_id, s.codigo, s.nombre, s.icono, s.orden);

-- Permiso base de acceso por módulo (ERP_<MOD>_ACCESO) ------------------------
merge into adm_seg_permiso t
using (select m.modulo_id, 'ERP_' || m.codigo || '_ACCESO' codigo, 'Acceso a ' || m.nombre nombre
         from adm_seg_modulo m
         join adm_seg_aplicacion a on a.aplicacion_id = m.aplicacion_id and a.codigo = 'ERP') s
   on (t.codigo = s.codigo)
 when not matched then
    insert (modulo_id, codigo, nombre, tipo)
    values (s.modulo_id, s.codigo, s.nombre, 'ACCION');

-- Rol base ---------------------------------------------------------------------
merge into adm_seg_rol t
using (select a.aplicacion_id, 'ERP_USUARIO' codigo, 'Usuario ERP' nombre,
              'Acceso a todos los módulos del ERP' descripcion
         from adm_seg_aplicacion a where a.codigo = 'ERP') s
   on (t.codigo = s.codigo)
 when not matched then
    insert (aplicacion_id, codigo, nombre, descripcion)
    values (s.aplicacion_id, s.codigo, s.nombre, s.descripcion);

merge into adm_seg_rol_permiso t
using (select r.rol_id, p.permiso_id
         from adm_seg_rol r
         join adm_seg_permiso p on p.codigo like 'ERP\_%\_ACCESO' escape '\'
        where r.codigo = 'ERP_USUARIO') s
   on (t.rol_id = s.rol_id and t.permiso_id = s.permiso_id)
 when not matched then
    insert (rol_id, permiso_id) values (s.rol_id, s.permiso_id);

commit;
