-- =============================================================================
-- Vista : erp_gen_usuario_empresa_v
-- Desc  : Empresas activas en las que cada usuario tiene algún permiso del ERP
--         (rol vigente para esa empresa o para todas). Base del selector de
--         empresa activa (APP_EMPRESA_ID) y de su validación.
-- =============================================================================
create or replace view erp_gen_usuario_empresa_v as
select distinct
       v.username,
       e.empresa_id,
       e.codigo,
       e.razon_social,
       case when e.empresa_id = u.empresa_id_defecto then 'S' else 'N' end es_defecto
  from adm_seg_usuario_permiso_v v
  join adm_seg_usuario u on u.usuario_id = v.usuario_id
  join adm_gen_empresa e on (v.empresa_id = e.empresa_id or v.empresa_id is null)
 where v.aplicacion_codigo = 'ERP'
   and e.estado = 'A';

comment on table erp_gen_usuario_empresa_v is 'Empresas habilitadas por usuario en el ERP (selector de empresa activa)';
