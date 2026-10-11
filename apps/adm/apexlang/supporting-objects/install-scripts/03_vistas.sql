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

-- >>> apps/adm/database/views/adm_aud_cambio_v.sql
-- =============================================================================
-- Vista : adm_aud_cambio_v
-- Desc  : Cabecera del historial de cambios con descripciones para listados:
--         entidad (comentario de la tabla), operación, empresa y cantidad de
--         campos. No expone el JSON (ver adm_aud_cambio_det_v).
--         Usa all_tab_comments del esquema actual (no user_*) para que también
--         resuelva los comentarios cuando la consulta otro usuario (DBA, soporte).
-- =============================================================================
create or replace view adm_aud_cambio_v as
select c.cambio_id,
       c.fecha,
       c.usuario,
       c.app_codigo,
       c.tabla,
       coalesce(regexp_replace(tc.comments, '\.?\s*Abrev:.*$', null, 1, 1, 'i'), lower(c.tabla)) entidad,
       c.registro_id,
       c.registro_padre_id,
       c.empresa_id,
       e.razon_social empresa,
       c.operacion,
       decode(c.operacion, 'I', 'Alta', 'U', 'Modificación', 'D', 'Eliminación') operacion_desc,
       json_value(c.cambios, '$.size()' returning number) campos,
       c.apex_app_id,
       c.apex_pagina_id,
       c.apex_sesion_id,
       c.transaccion_id,
       c.modulo
  from adm_aud_cambio c
  left join all_tab_comments tc on tc.owner = sys_context('userenv', 'current_schema') and tc.table_name = c.tabla
  left join adm_gen_empresa e on e.empresa_id = c.empresa_id;

comment on table adm_aud_cambio_v is 'Historial de cambios: una fila por registro modificado, con descripciones';

-- >>> apps/adm/database/views/adm_aud_cambio_det_v.sql
-- =============================================================================
-- Vista : adm_aud_cambio_det_v
-- Desc  : Detalle del historial de cambios: expande el JSON de adm_aud_cambio
--         a una fila por campo (Campo / Antes / Después).
--         campo = comentario de la columna (all_col_comments del esquema actual); si no tiene,
--         el nombre de la columna. Las columnas reservadas (contraseñas,
--         hashes, tokens) muestran "(reservado)": su valor nunca se guarda.
--         Los valores de más de 4000 bytes se muestran truncados.
-- =============================================================================
create or replace view adm_aud_cambio_det_v as
select c.cambio_id,
       c.fecha,
       c.usuario,
       c.app_codigo,
       c.tabla,
       coalesce((select regexp_replace(tc.comments, '\.?\s*Abrev:.*$', null, 1, 1, 'i')
                   from all_tab_comments tc
                  where tc.owner = sys_context('userenv', 'current_schema')
                    and tc.table_name = c.tabla),
                lower(c.tabla)) entidad,
       c.registro_id,
       c.registro_padre_id,
       c.empresa_id,
       c.operacion,
       decode(c.operacion, 'I', 'Alta', 'U', 'Modificación', 'D', 'Eliminación') operacion_desc,
       c.transaccion_id,
       j.orden,
       j.columna,
       coalesce((select cc.comments
                   from all_col_comments cc
                  where cc.owner = sys_context('userenv', 'current_schema')
                    and cc.table_name = c.tabla
                    and cc.column_name = upper(j.columna)),
                initcap(replace(j.columna, '_', ' '))) campo,
       case when j.reservado = 'true' then '(reservado)' else j.antes end antes,
       case when j.reservado = 'true' then '(reservado)' else j.despues end despues,
       case when j.reservado = 'true' then 'S' else 'N' end es_reservado
  from adm_aud_cambio c,
       json_table(c.cambios, '$[*]'
           columns (orden      for ordinality,
                    columna    varchar2(128)           path '$.col',
                    antes      varchar2(4000) truncate path '$.antes',
                    despues    varchar2(4000) truncate path '$.despues',
                    reservado  varchar2(5)             path '$.reservado')) j;

comment on table adm_aud_cambio_det_v is 'Historial de cambios: una fila por campo modificado (Campo / Antes / Después)';
