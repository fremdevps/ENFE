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
