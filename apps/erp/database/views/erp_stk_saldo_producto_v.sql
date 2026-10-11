-- =============================================================================
-- Vista : erp_stk_saldo_producto_v
-- Desc  : Stock por depósito y producto (suma lotes y ubicaciones): existencia,
--         reservado, disponible, cuarentena, costo unitario ponderado y valor
--         en moneda funcional y de reporte. El stock de los depósitos de
--         tránsito suma al inventario valorizado pero no está disponible.
-- =============================================================================
create or replace view erp_stk_saldo_producto_v as
select s.empresa_id,
       s.deposito_id,
       d.sucursal_id,
       d.tipo                                                             deposito_tipo,
       s.producto_id,
       sum(s.cantidad)                                                    cantidad,
       sum(s.cantidad_reservada)                                          cantidad_reservada,
       sum(case when s.es_disponible = 'S' and d.tipo <> 'T'
                then s.cantidad - s.cantidad_reservada else 0 end)        cantidad_disponible,
       sum(case when s.es_disponible = 'N' then s.cantidad else 0 end)    cantidad_cuarentena,
       case when sum(s.cantidad) > 0
            then round(sum(s.cantidad * s.costo_promedio) / sum(s.cantidad), 6) end          costo_unitario,
       case when sum(s.cantidad) > 0
            then round(sum(s.cantidad * s.costo_promedio_reporte) / sum(s.cantidad), 6) end  costo_unitario_reporte,
       sum(s.cantidad * s.costo_promedio)                                 valor,
       sum(s.cantidad * s.costo_promedio_reporte)                         valor_reporte,
       max(s.fecha_ultimo_movimiento)                                     fecha_ultimo_movimiento
  from erp_stk_saldo s
  join erp_stk_deposito d on d.deposito_id = s.deposito_id
 group by s.empresa_id, s.deposito_id, d.sucursal_id, d.tipo, s.producto_id;

comment on table erp_stk_saldo_producto_v is 'Stock por depósito y producto: existencia, reservado, disponible, cuarentena, costo y valor';
