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
