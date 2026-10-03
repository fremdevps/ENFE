-- GENERADO por tools/build-supporting-objects.ps1 - NO EDITAR (fuente: apps/adm/database)

-- >>> apps/adm/database/views/adm_seg_usuario_permiso_v.sql
-- =============================================================================
-- Vista : adm_seg_usuario_permiso_v
-- Desc  : Permisos efectivos por usuario (solo usuarios, roles, permisos,
--         módulos y aplicaciones activos y asignaciones vigentes).
--         Un rol es_superadmin = 'S' recibe todos los permisos activos.
--         empresa_id null = aplica a todas las empresas.
-- =============================================================================
create or replace view adm_seg_usuario_permiso_v as
select u.usuario_id,
       u.username,
       ur.empresa_id,
       r.rol_id,
       r.codigo   as rol_codigo,
       a.aplicacion_id,
       a.codigo   as aplicacion_codigo,
       a.apex_app_id,
       m.modulo_id,
       m.codigo   as modulo_codigo,
       p.permiso_id,
       p.codigo   as permiso_codigo,
       p.tipo     as permiso_tipo,
       p.apex_pagina_id
  from adm_seg_usuario     u
  join adm_seg_usuario_rol ur on ur.usuario_id = u.usuario_id
  join adm_seg_rol         r  on r.rol_id      = ur.rol_id
  join adm_seg_permiso     p  on p.estado      = 'A'
  join adm_seg_modulo      m  on m.modulo_id   = p.modulo_id     and m.estado = 'A'
  join adm_seg_aplicacion  a  on a.aplicacion_id = m.aplicacion_id and a.estado = 'A'
 where u.estado = 'A'
   and r.estado = 'A'
   and trunc(current_date) between ur.fecha_desde and coalesce(ur.fecha_hasta, trunc(current_date))
   and (   r.es_superadmin = 'S'
        or exists (select 1
                     from adm_seg_rol_permiso rp
                    where rp.rol_id     = r.rol_id
                      and rp.permiso_id = p.permiso_id));

comment on table adm_seg_usuario_permiso_v is 'Permisos efectivos por usuario (base para authorization schemes y menú)';
