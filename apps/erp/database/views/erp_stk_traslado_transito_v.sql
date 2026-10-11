-- =============================================================================
-- Vista : erp_stk_traslado_transito_v
-- Desc  : Mercadería en tránsito por traslado e ítem: qué hay, desde cuándo,
--         hacia dónde, con qué remisión y con cuántas horas de atraso respecto
--         de la llegada estimada. La suma de cantidad_pendiente por depósito de
--         tránsito, producto y lote es igual al saldo de ese depósito
--         (invariante verificable).
-- =============================================================================
create or replace view erp_stk_traslado_transito_v as
select t.empresa_id,
       t.traslado_id,
       t.sucursal_id,
       t.numero,
       t.tipo,
       t.estado,
       t.traslado_id_origen,
       t.relacion,
       t.deposito_id_origen,
       t.deposito_id_transito,
       t.deposito_id_destino,
       t.fecha_salida_real,
       t.fecha_llegada_estimada,
       t.remision_estado,
       t.remision_numero,
       i.traslado_item_id,
       i.producto_id,
       i.lote_id,
       i.cantidad_despachada,
       i.cantidad_faltante,
       i.cantidad_despachada - i.cantidad_recibida - i.cantidad_averiada
           - i.cantidad_perdida - i.cantidad_devuelta                              cantidad_pendiente,
       i.costo_unitario,
       (i.cantidad_despachada - i.cantidad_recibida - i.cantidad_averiada
           - i.cantidad_perdida - i.cantidad_devuelta) * i.costo_unitario          valor_pendiente,
       round((cast(systimestamp as date) - cast(t.fecha_salida_real as date)) * 24, 2)  horas_en_transito,
       greatest(round((cast(systimestamp as date) - cast(t.fecha_llegada_estimada as date)) * 24, 2), 0)  horas_atraso
  from erp_stk_traslado t
  join erp_stk_traslado_item i on i.traslado_id = t.traslado_id
 where t.estado in ('T', 'R', 'D')
   and i.cantidad_despachada - i.cantidad_recibida - i.cantidad_averiada
           - i.cantidad_perdida - i.cantidad_devuelta > 0;

comment on table erp_stk_traslado_transito_v is 'Mercadería en tránsito por traslado e ítem, con horas de atraso';
