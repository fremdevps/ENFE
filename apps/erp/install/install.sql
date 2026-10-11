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
@@../database/tables/erp_doc_clase_documento.sql
@@../database/tables/erp_doc_tipo_documento.sql
@@../database/tables/erp_doc_tipo_doc_fiscal.sql
@@../database/tables/erp_doc_motivo.sql
@@../database/tables/erp_doc_timbrado.sql
@@../database/tables/erp_doc_numerador.sql
@@../database/tables/erp_doc_numerador_usuario.sql
@@../database/tables/erp_doc_numero_inutilizado.sql
@@../database/tables/erp_doc_fe_certificado.sql
@@../database/tables/erp_doc_fe_config.sql
@@../database/tables/erp_doc_fe_actividad.sql
@@../database/tables/erp_doc_fe_cod_respuesta.sql
@@../database/tables/erp_doc_fe_lote.sql
@@../database/tables/erp_doc_fe_documento.sql
@@../database/tables/erp_doc_fe_lote_detalle.sql
@@../database/tables/erp_doc_fe_evento.sql
@@../database/tables/erp_doc_fe_log.sql

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
@@../database/triggers/trg_erp_cldo_bu.sql
@@../database/triggers/trg_erp_tido_bu.sql
@@../database/triggers/trg_erp_tdfi_bu.sql
@@../database/triggers/trg_erp_moti_bu.sql
@@../database/triggers/trg_erp_timb_bu.sql
@@../database/triggers/trg_erp_nume_bu.sql
@@../database/triggers/trg_erp_nuus_bu.sql
@@../database/triggers/trg_erp_nuin_bu.sql
@@../database/triggers/trg_erp_fece_bu.sql
@@../database/triggers/trg_erp_feco_bu.sql
@@../database/triggers/trg_erp_feac_bu.sql
@@../database/triggers/trg_erp_fecr_bu.sql
@@../database/triggers/trg_erp_felo_bu.sql
@@../database/triggers/trg_erp_fedo_bu.sql
@@../database/triggers/trg_erp_feld_bu.sql
@@../database/triggers/trg_erp_feev_bu.sql
@@../database/triggers/trg_erp_felg_bu.sql

prompt == Vistas
@@../database/views/erp_gen_usuario_empresa_v.sql

prompt == Tipos
@@../database/types/erp_impuesto_calc_typ.sql
@@../database/types/erp_impuesto_calc_tab.sql

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
@@../database/packages/erp_doc_fe_xml_utl.pks
@@../database/packages/erp_doc_fe_cdc_utl.pks
@@../database/packages/erp_doc_fe_secreto_utl.pks
@@../database/packages/erp_doc_fe_firma_utl.pks
@@../database/packages/erp_doc_fe_qr_utl.pks
@@../database/packages/erp_doc_numerador_ctr.pks
@@../database/packages/erp_doc_numero_inutilizado_ctr.pks
@@../database/packages/erp_doc_fe_documento_ctr.pks
@@../database/packages/erp_doc_fe_lote_ctr.pks
@@../database/packages/erp_doc_fe_log_ctr.pks
@@../database/packages/erp_doc_fe_certificado_ctr.pks
@@../database/packages/erp_doc_fe_config_ctr.pks
@@../database/packages/erp_doc_fe_de_reg.pks
@@../database/packages/erp_doc_fe_cola_reg.pks
@@../database/packages/erp_doc_numerador_reg.pks
@@../database/packages/erp_doc_tipo_documento_api.pks
@@../database/packages/erp_doc_numerador_api.pks
@@../database/packages/erp_doc_fe_cola_api.pks
@@../database/packages/erp_doc_fe_config_api.pks
@@../database/packages/erp_doc_fe_documento_api.pks

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
@@../database/packages/erp_doc_fe_xml_utl.pkb
@@../database/packages/erp_doc_fe_cdc_utl.pkb
@@../database/packages/erp_doc_fe_secreto_utl.pkb
@@../database/packages/erp_doc_fe_firma_utl.pkb
@@../database/packages/erp_doc_fe_qr_utl.pkb
@@../database/packages/erp_doc_numerador_ctr.pkb
@@../database/packages/erp_doc_numero_inutilizado_ctr.pkb
@@../database/packages/erp_doc_fe_documento_ctr.pkb
@@../database/packages/erp_doc_fe_lote_ctr.pkb
@@../database/packages/erp_doc_fe_log_ctr.pkb
@@../database/packages/erp_doc_fe_certificado_ctr.pkb
@@../database/packages/erp_doc_fe_config_ctr.pkb
@@../database/packages/erp_doc_fe_de_reg.pkb
@@../database/packages/erp_doc_fe_cola_reg.pkb
@@../database/packages/erp_doc_numerador_reg.pkb
@@../database/packages/erp_doc_tipo_documento_api.pkb
@@../database/packages/erp_doc_numerador_api.pkb
@@../database/packages/erp_doc_fe_cola_api.pkb
@@../database/packages/erp_doc_fe_config_api.pkb
@@../database/packages/erp_doc_fe_documento_api.pkb

prompt == Registro en seguridad central
@@../database/data/erp_seg_registro.sql

prompt == Datos iniciales
@@../database/data/erp_gen_datos_iniciales.sql
@@../database/data/erp_gen_mensajes_error.sql
@@../database/data/erp_doc_datos_iniciales.sql
@@../database/data/erp_doc_mensajes_error.sql

prompt == Objetos inválidos (debe estar vacío)
select object_name, object_type from user_objects
 where status = 'INVALID' and (object_name like 'ERP\_%' escape '\' or object_name like 'TRG\_ERP\_%' escape '\');

prompt == Instalación ERP completa
