-- =============================================================================
-- Registro del ERP en la seguridad central (ADM). Idempotente.
-- Requiere que ADM esté instalado (adm_seg_aplicacion con codigo = 'ERP').
-- =============================================================================

-- Autonomous Database habilita DML paralelo por defecto: varios merge sobre tablas
-- relacionadas en la misma transacción darían ORA-12839.
alter session disable parallel dml;

-- Módulos del ERP -------------------------------------------------------------
merge into adm_seg_modulo t
using (select a.aplicacion_id, m.codigo, m.nombre, m.icono, m.orden
         from adm_seg_aplicacion a
        cross join (select 'GEN' codigo, 'General'        nombre, 'fa-cogs'         icono,  5 orden from dual union all
                    select 'FIN',        'Finanzas',              'fa-money',             10       from dual union all
                    select 'DOC',        'Documentos',            'fa-file-text-o',       15       from dual union all
                    select 'STK',        'Inventario',            'fa-cubes',             20       from dual union all
                    select 'COM',        'Compras',               'fa-shopping-cart',     30       from dual union all
                    select 'VEN',        'Ventas',                'fa-line-chart',        40       from dual union all
                    select 'PRD',        'Producción',            'fa-industry',          50       from dual union all
                    select 'CNT',        'Contabilidad',          'fa-book',              60       from dual) m
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

-- Permisos del módulo General ---------------------------------------------------
merge into adm_seg_permiso t
using (select m.modulo_id, p.codigo, p.nombre
         from adm_seg_modulo m
         join adm_seg_aplicacion a on a.aplicacion_id = m.aplicacion_id and a.codigo = 'ERP'
        cross join (select 'ERP_GEN_CATALOGO_GESTIONAR' codigo, 'Gestionar catálogos generales (monedas, países, impuestos, documentos)' nombre from dual union all
                    select 'ERP_GEN_EMPRESA_CONFIGURAR', 'Configurar la empresa (datos fiscales, sucursales, parámetros)' from dual union all
                    select 'ERP_GEN_COTIZACION_GESTIONAR', 'Cargar y corregir cotizaciones' from dual union all
                    select 'ERP_GEN_PERSONA_VER', 'Consultar personas' from dual union all
                    select 'ERP_GEN_PERSONA_GESTIONAR', 'Crear y modificar personas' from dual union all
                    select 'ERP_GEN_PERIODO_CERRAR', 'Crear y cerrar períodos' from dual union all
                    select 'ERP_GEN_PERIODO_REABRIR', 'Reabrir períodos cerrados' from dual) p
        where m.codigo = 'GEN') s
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

-- Administrador del ERP: todos los permisos del ERP -----------------------------
merge into adm_seg_rol t
using (select a.aplicacion_id, 'ERP_ADMINISTRADOR' codigo, 'Administrador ERP' nombre,
              'Configuración general del ERP y todos sus permisos' descripcion
         from adm_seg_aplicacion a where a.codigo = 'ERP') s
   on (t.codigo = s.codigo)
 when not matched then
    insert (aplicacion_id, codigo, nombre, descripcion)
    values (s.aplicacion_id, s.codigo, s.nombre, s.descripcion);

merge into adm_seg_rol_permiso t
using (select r.rol_id, p.permiso_id
         from adm_seg_rol r
         join adm_seg_permiso p on p.codigo like 'ERP\_%' escape '\'
        where r.codigo = 'ERP_ADMINISTRADOR') s
   on (t.rol_id = s.rol_id and t.permiso_id = s.permiso_id)
 when not matched then
    insert (rol_id, permiso_id) values (s.rol_id, s.permiso_id);

commit;

-- Permisos del módulo Inventario -------------------------------------------------
merge into adm_seg_permiso t
using (select m.modulo_id, p.codigo, p.nombre
         from adm_seg_modulo m
         join adm_seg_aplicacion a on a.aplicacion_id = m.aplicacion_id and a.codigo = 'ERP'
        cross join (select 'ERP_STK_CATALOGO_GESTIONAR' codigo, 'Gestionar catálogos de inventario (unidades, categorías, marcas, ubicaciones, vehículos, rutas)' nombre from dual union all
                    select 'ERP_STK_PRODUCTO_VER', 'Consultar productos' from dual union all
                    select 'ERP_STK_PRODUCTO_GESTIONAR', 'Crear y modificar productos' from dual union all
                    select 'ERP_STK_LOTE_GESTIONAR', 'Crear y modificar lotes y números de serie' from dual union all
                    select 'ERP_STK_SALDO_VER', 'Consultar saldos y movimientos de stock' from dual union all
                    select 'ERP_STK_COSTO_VER', 'Ver costos y valorización del stock' from dual union all
                    select 'ERP_STK_MOVIMIENTO_REGISTRAR', 'Registrar ajustes y movimientos manuales de stock' from dual union all
                    select 'ERP_STK_MOVIMIENTO_ANULAR', 'Anular movimientos manuales de stock' from dual union all
                    select 'ERP_STK_RESERVA_GESTIONAR', 'Reservar y liberar stock' from dual union all
                    select 'ERP_STK_TRASLADO_VER', 'Consultar traslados y mercadería en tránsito' from dual union all
                    select 'ERP_STK_TRASLADO_CREAR', 'Crear, modificar y solicitar traslados' from dual union all
                    select 'ERP_STK_TRASLADO_APROBAR', 'Aprobar y rechazar traslados' from dual union all
                    select 'ERP_STK_TRASLADO_DESPACHAR', 'Despachar traslados' from dual union all
                    select 'ERP_STK_TRASLADO_RECIBIR', 'Recibir traslados y generar devoluciones' from dual union all
                    select 'ERP_STK_TRASLADO_RESOLVER', 'Resolver diferencias de traslados (pérdida, devolución)' from dual union all
                    select 'ERP_STK_TRASLADO_ANULAR', 'Anular traslados' from dual) p
        where m.codigo = 'STK') s
   on (t.codigo = s.codigo)
 when not matched then
    insert (modulo_id, codigo, nombre, tipo)
    values (s.modulo_id, s.codigo, s.nombre, 'ACCION');

-- El administrador del ERP recibe también los permisos de inventario
merge into adm_seg_rol_permiso t
using (select r.rol_id, p.permiso_id
         from adm_seg_rol r
         join adm_seg_permiso p on p.codigo like 'ERP\_STK\_%' escape '\'
        where r.codigo = 'ERP_ADMINISTRADOR') s
   on (t.rol_id = s.rol_id and t.permiso_id = s.permiso_id)
 when not matched then
    insert (rol_id, permiso_id) values (s.rol_id, s.permiso_id);

commit;
