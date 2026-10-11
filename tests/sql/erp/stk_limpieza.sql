-- =============================================================================
-- Pruebas de inventario: borra todos los datos de la empresa de prueba STKTEST.
-- No confirma: lo decide el script que lo llama (las pruebas con rollback no
-- dejan nada; las de concurrencia y volumen confirman y limpian al terminar).
-- =============================================================================
declare
    v_empresa_id  number;
begin
    select max(empresa_id) into v_empresa_id from adm_gen_empresa where codigo = 'STKTEST';
    if v_empresa_id is not null then
        delete from erp_stk_traslado_evento where traslado_id in (select traslado_id from erp_stk_traslado where empresa_id = v_empresa_id);
        delete from erp_stk_traslado_recep_det
         where traslado_recep_id in (select r.traslado_recep_id
                                       from erp_stk_traslado_recep r
                                       join erp_stk_traslado t on t.traslado_id = r.traslado_id
                                      where t.empresa_id = v_empresa_id);
        delete from erp_stk_traslado_recep where traslado_id in (select traslado_id from erp_stk_traslado where empresa_id = v_empresa_id);
        delete from erp_stk_traslado_item where traslado_id in (select traslado_id from erp_stk_traslado where empresa_id = v_empresa_id);
        delete from erp_stk_traslado where empresa_id = v_empresa_id;
        delete from erp_stk_movimiento_item where empresa_id = v_empresa_id;
        delete from erp_stk_movimiento where empresa_id = v_empresa_id;
        delete from erp_stk_saldo where empresa_id = v_empresa_id;
        delete from erp_stk_numerador where empresa_id = v_empresa_id;
        delete from erp_stk_ruta_traslado where empresa_id = v_empresa_id;
        delete from erp_stk_lote where empresa_id = v_empresa_id;
        delete from erp_stk_producto where empresa_id = v_empresa_id;
        delete from erp_stk_marca where empresa_id = v_empresa_id;
        delete from erp_stk_categoria where empresa_id = v_empresa_id;
        delete from erp_stk_vehiculo where empresa_id = v_empresa_id;
        delete from erp_stk_usuario_deposito
         where deposito_id in (select d.deposito_id from erp_stk_deposito d
                                 join erp_gen_sucursal s on s.sucursal_id = d.sucursal_id
                                where s.empresa_id = v_empresa_id);
        delete from erp_stk_deposito_ubicacion
         where deposito_id in (select d.deposito_id from erp_stk_deposito d
                                 join erp_gen_sucursal s on s.sucursal_id = d.sucursal_id
                                where s.empresa_id = v_empresa_id);
        delete from erp_gen_usuario_sucursal where sucursal_id in (select sucursal_id from erp_gen_sucursal where empresa_id = v_empresa_id);
        delete from erp_stk_deposito where sucursal_id in (select sucursal_id from erp_gen_sucursal where empresa_id = v_empresa_id);
        delete from erp_gen_sucursal where empresa_id = v_empresa_id;
        delete from erp_gen_cotizacion where empresa_id = v_empresa_id;
        delete from erp_gen_periodo where empresa_id = v_empresa_id;
        delete from erp_gen_empresa_func where empresa_id = v_empresa_id;
        delete from erp_gen_parametro where empresa_id = v_empresa_id;
        delete from erp_gen_empresa_config where empresa_id = v_empresa_id;
    end if;
    delete from adm_seg_usuario where username like 'STK\_QA\_%' escape '\';
    delete from erp_gen_persona where nro_documento = 'STKTEST1';
    if v_empresa_id is not null then
        delete from adm_gen_empresa where empresa_id = v_empresa_id;
    end if;
end;
/
