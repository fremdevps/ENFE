-- =============================================================================
-- Instalación de objetos ERP. Requiere ADM instalado previamente.
-- Mismo orden que los Supporting Objects de la app APEX ERP.
--     SQL> @install/install.sql   (desde apps/erp)
-- Orden de paquetes: ctr -> reg -> api (specs primero, luego bodies).
-- =============================================================================
whenever sqlerror exit failure rollback
set define off

prompt == Tablas
@@../database/tables/erp_gen_moneda.sql
@@../database/tables/erp_gen_pais.sql
@@../database/tables/erp_gen_feriado.sql
@@../database/tables/erp_gen_ubicacion.sql
@@../database/tables/erp_gen_impuesto.sql
@@../database/tables/erp_gen_impuesto_tasa.sql
@@../database/tables/erp_gen_impuesto_tasa_vig.sql
@@../database/tables/erp_gen_categoria_fiscal.sql
@@../database/tables/erp_gen_categoria_tasa.sql
@@../database/tables/erp_gen_cotizacion.sql
@@../database/tables/erp_gen_funcionalidad.sql
@@../database/tables/erp_gen_rubro.sql
@@../database/tables/erp_gen_rubro_func.sql
@@../database/tables/erp_gen_empresa_config.sql
@@../database/tables/erp_gen_empresa_func.sql
@@../database/tables/erp_gen_sucursal.sql
@@../database/tables/erp_gen_departamento.sql
@@../database/tables/erp_gen_punto_expedicion.sql
@@../database/tables/erp_gen_usuario_sucursal.sql
@@../database/tables/erp_stk_deposito.sql
@@../database/tables/erp_gen_tipo_doc_identidad.sql
@@../database/tables/erp_gen_persona.sql
@@../database/tables/erp_gen_persona_documento.sql
@@../database/tables/erp_gen_persona_direccion.sql
@@../database/tables/erp_gen_persona_contacto.sql
@@../database/tables/erp_gen_tipo_rol.sql
@@../database/tables/erp_gen_persona_rol.sql
@@../database/tables/erp_gen_parametro.sql
@@../database/tables/erp_gen_periodo.sql
@@../database/tables/erp_gen_periodo_habilita.sql
-- Inventario (stk)
@@../database/tables/erp_stk_unidad.sql
@@../database/tables/erp_stk_categoria.sql
@@../database/tables/erp_stk_marca.sql
@@../database/tables/erp_stk_producto.sql
@@../database/tables/erp_stk_deposito_ubicacion.sql
@@../database/tables/erp_stk_producto_codigo.sql
@@../database/tables/erp_stk_producto_unidad.sql
@@../database/tables/erp_stk_producto_equiv.sql
@@../database/tables/erp_stk_producto_deposito.sql
@@../database/tables/erp_stk_producto_proveedor.sql
@@../database/tables/erp_stk_kit.sql
@@../database/tables/erp_stk_lote.sql
@@../database/tables/erp_stk_vehiculo.sql
@@../database/tables/erp_stk_usuario_deposito.sql
@@../database/tables/erp_stk_tipo_movimiento.sql
@@../database/tables/erp_stk_movimiento.sql
@@../database/tables/erp_stk_movimiento_item.sql
@@../database/tables/erp_stk_saldo.sql
@@../database/tables/erp_stk_numerador.sql
@@../database/tables/erp_stk_motivo_traslado.sql
@@../database/tables/erp_stk_ruta_traslado.sql
@@../database/tables/erp_stk_traslado.sql
@@../database/tables/erp_stk_traslado_item.sql
@@../database/tables/erp_stk_traslado_recep.sql
@@../database/tables/erp_stk_traslado_recep_det.sql
@@../database/tables/erp_stk_traslado_evento.sql

prompt == Triggers
@@../database/triggers/trg_erp_mon_bu.sql
@@../database/triggers/trg_erp_pai_bu.sql
@@../database/triggers/trg_erp_feri_bu.sql
@@../database/triggers/trg_erp_ubi_bu.sql
@@../database/triggers/trg_erp_imp_bu.sql
@@../database/triggers/trg_erp_imta_bu.sql
@@../database/triggers/trg_erp_itv_bu.sql
@@../database/triggers/trg_erp_cafi_bu.sql
@@../database/triggers/trg_erp_cata_bu.sql
@@../database/triggers/trg_erp_cot_bu.sql
@@../database/triggers/trg_erp_func_bu.sql
@@../database/triggers/trg_erp_rub_bu.sql
@@../database/triggers/trg_erp_rufu_bu.sql
@@../database/triggers/trg_erp_emcf_bu.sql
@@../database/triggers/trg_erp_emfu_bu.sql
@@../database/triggers/trg_erp_suc_bu.sql
@@../database/triggers/trg_erp_dpto_bu.sql
@@../database/triggers/trg_erp_ptex_bu.sql
@@../database/triggers/trg_erp_ussu_bu.sql
@@../database/triggers/trg_erp_dpo_bu.sql
@@../database/triggers/trg_erp_tdi_bu.sql
@@../database/triggers/trg_erp_prs_bu.sql
@@../database/triggers/trg_erp_prdo_bu.sql
@@../database/triggers/trg_erp_prdi_bu.sql
@@../database/triggers/trg_erp_prco_bu.sql
@@../database/triggers/trg_erp_tirl_bu.sql
@@../database/triggers/trg_erp_prro_bu.sql
@@../database/triggers/trg_erp_par_bu.sql
@@../database/triggers/trg_erp_peri_bu.sql
@@../database/triggers/trg_erp_peha_bu.sql
-- Inventario (stk)
@@../database/triggers/trg_erp_uni_bu.sql
@@../database/triggers/trg_erp_ctg_bu.sql
@@../database/triggers/trg_erp_mar_bu.sql
@@../database/triggers/trg_erp_pro_bu.sql
@@../database/triggers/trg_erp_dpub_bu.sql
@@../database/triggers/trg_erp_prcd_bu.sql
@@../database/triggers/trg_erp_prun_bu.sql
@@../database/triggers/trg_erp_preq_bu.sql
@@../database/triggers/trg_erp_prdp_bu.sql
@@../database/triggers/trg_erp_prpv_bu.sql
@@../database/triggers/trg_erp_kit_bu.sql
@@../database/triggers/trg_erp_lot_bu.sql
@@../database/triggers/trg_erp_veh_bu.sql
@@../database/triggers/trg_erp_usdp_bu.sql
@@../database/triggers/trg_erp_timo_bu.sql
@@../database/triggers/trg_erp_mov_bu.sql
@@../database/triggers/trg_erp_moit_bu.sql
@@../database/triggers/trg_erp_sal_bu.sql
@@../database/triggers/trg_erp_stnu_bu.sql
@@../database/triggers/trg_erp_motr_bu.sql
@@../database/triggers/trg_erp_rutr_bu.sql
@@../database/triggers/trg_erp_tra_bu.sql
@@../database/triggers/trg_erp_trit_bu.sql
@@../database/triggers/trg_erp_trre_bu.sql
@@../database/triggers/trg_erp_trrd_bu.sql
@@../database/triggers/trg_erp_trev_bu.sql

prompt == Vistas
@@../database/views/erp_gen_usuario_empresa_v.sql
@@../database/views/erp_stk_saldo_producto_v.sql
@@../database/views/erp_stk_traslado_transito_v.sql

prompt == Tipos
@@../database/types/erp_impuesto_calc_typ.sql
@@../database/types/erp_impuesto_calc_tab.sql
@@../database/types/erp_stk_mov_item_typ.sql
@@../database/types/erp_stk_mov_item_tab.sql
@@../database/types/erp_stk_tras_item_typ.sql
@@../database/types/erp_stk_tras_item_tab.sql

prompt == Paquetes (especificaciones)
@@../database/packages/erp_gen_parametro_ctr.pks
@@../database/packages/erp_gen_periodo_ctr.pks
@@../database/packages/erp_gen_persona_ctr.pks
@@../database/packages/erp_gen_empresa_func_ctr.pks
@@../database/packages/erp_gen_moneda_reg.pks
@@../database/packages/erp_gen_impuesto_reg.pks
@@../database/packages/erp_gen_periodo_reg.pks
@@../database/packages/erp_gen_persona_reg.pks
@@../database/packages/erp_gen_parametro_api.pks
@@../database/packages/erp_gen_moneda_api.pks
@@../database/packages/erp_gen_impuesto_api.pks
@@../database/packages/erp_gen_periodo_api.pks
@@../database/packages/erp_gen_persona_api.pks
@@../database/packages/erp_gen_funcionalidad_api.pks
-- Inventario (stk): utl -> ctr -> reg -> api
@@../database/packages/erp_stk_comun_utl.pks
@@../database/packages/erp_stk_saldo_ctr.pks
@@../database/packages/erp_stk_movimiento_ctr.pks
@@../database/packages/erp_stk_movimiento_item_ctr.pks
@@../database/packages/erp_stk_categoria_ctr.pks
@@../database/packages/erp_stk_producto_ctr.pks
@@../database/packages/erp_stk_lote_ctr.pks
@@../database/packages/erp_stk_deposito_ubicacion_ctr.pks
@@../database/packages/erp_stk_numerador_ctr.pks
@@../database/packages/erp_stk_traslado_ctr.pks
@@../database/packages/erp_stk_traslado_item_ctr.pks
@@../database/packages/erp_stk_traslado_recep_ctr.pks
@@../database/packages/erp_stk_traslado_recep_det_ctr.pks
@@../database/packages/erp_stk_traslado_evento_ctr.pks
@@../database/packages/erp_stk_movimiento_reg.pks
@@../database/packages/erp_stk_producto_reg.pks
@@../database/packages/erp_stk_traslado_reg.pks
@@../database/packages/erp_stk_movimiento_api.pks
@@../database/packages/erp_stk_producto_api.pks
@@../database/packages/erp_stk_categoria_api.pks
@@../database/packages/erp_stk_lote_api.pks
@@../database/packages/erp_stk_traslado_api.pks

prompt == Paquetes (cuerpos)
@@../database/packages/erp_gen_parametro_ctr.pkb
@@../database/packages/erp_gen_periodo_ctr.pkb
@@../database/packages/erp_gen_persona_ctr.pkb
@@../database/packages/erp_gen_empresa_func_ctr.pkb
@@../database/packages/erp_gen_moneda_reg.pkb
@@../database/packages/erp_gen_impuesto_reg.pkb
@@../database/packages/erp_gen_periodo_reg.pkb
@@../database/packages/erp_gen_persona_reg.pkb
@@../database/packages/erp_gen_parametro_api.pkb
@@../database/packages/erp_gen_moneda_api.pkb
@@../database/packages/erp_gen_impuesto_api.pkb
@@../database/packages/erp_gen_periodo_api.pkb
@@../database/packages/erp_gen_persona_api.pkb
@@../database/packages/erp_gen_funcionalidad_api.pkb
-- Inventario (stk)
@@../database/packages/erp_stk_comun_utl.pkb
@@../database/packages/erp_stk_saldo_ctr.pkb
@@../database/packages/erp_stk_movimiento_ctr.pkb
@@../database/packages/erp_stk_movimiento_item_ctr.pkb
@@../database/packages/erp_stk_categoria_ctr.pkb
@@../database/packages/erp_stk_producto_ctr.pkb
@@../database/packages/erp_stk_lote_ctr.pkb
@@../database/packages/erp_stk_deposito_ubicacion_ctr.pkb
@@../database/packages/erp_stk_numerador_ctr.pkb
@@../database/packages/erp_stk_traslado_ctr.pkb
@@../database/packages/erp_stk_traslado_item_ctr.pkb
@@../database/packages/erp_stk_traslado_recep_ctr.pkb
@@../database/packages/erp_stk_traslado_recep_det_ctr.pkb
@@../database/packages/erp_stk_traslado_evento_ctr.pkb
@@../database/packages/erp_stk_movimiento_reg.pkb
@@../database/packages/erp_stk_producto_reg.pkb
@@../database/packages/erp_stk_traslado_reg.pkb
@@../database/packages/erp_stk_movimiento_api.pkb
@@../database/packages/erp_stk_producto_api.pkb
@@../database/packages/erp_stk_categoria_api.pkb
@@../database/packages/erp_stk_lote_api.pkb
@@../database/packages/erp_stk_traslado_api.pkb

prompt == Registro en seguridad central
@@../database/data/erp_seg_registro.sql

prompt == Datos iniciales
@@../database/data/erp_gen_datos_iniciales.sql
@@../database/data/erp_gen_mensajes_error.sql
@@../database/data/erp_stk_datos_iniciales.sql
@@../database/data/erp_stk_mensajes_error.sql

prompt == Objetos inválidos (debe estar vacío)
select object_name, object_type from user_objects
 where status = 'INVALID' and (object_name like 'ERP\_%' escape '\' or object_name like 'TRG\_ERP\_%' escape '\');

prompt == Instalación ERP completa
