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
@@../database/tables/erp_gen_ubicacion.sql
@@../database/tables/erp_gen_impuesto.sql
@@../database/tables/erp_gen_impuesto_tasa.sql
@@../database/tables/erp_gen_impuesto_tasa_vig.sql
@@../database/tables/erp_gen_categoria_fiscal.sql
@@../database/tables/erp_gen_categoria_tasa.sql
@@../database/tables/erp_gen_cotizacion.sql
@@../database/tables/erp_gen_empresa_config.sql
@@../database/tables/erp_gen_sucursal.sql
@@../database/tables/erp_gen_tipo_doc_identidad.sql
@@../database/tables/erp_gen_persona.sql
@@../database/tables/erp_gen_persona_direccion.sql
@@../database/tables/erp_gen_persona_contacto.sql
@@../database/tables/erp_gen_parametro.sql
@@../database/tables/erp_gen_periodo.sql

prompt == Triggers
@@../database/triggers/trg_erp_mon_bu.sql
@@../database/triggers/trg_erp_pai_bu.sql
@@../database/triggers/trg_erp_ubi_bu.sql
@@../database/triggers/trg_erp_imp_bu.sql
@@../database/triggers/trg_erp_imta_bu.sql
@@../database/triggers/trg_erp_itv_bu.sql
@@../database/triggers/trg_erp_cafi_bu.sql
@@../database/triggers/trg_erp_cata_bu.sql
@@../database/triggers/trg_erp_cot_bu.sql
@@../database/triggers/trg_erp_emcf_bu.sql
@@../database/triggers/trg_erp_suc_bu.sql
@@../database/triggers/trg_erp_tdi_bu.sql
@@../database/triggers/trg_erp_prs_bu.sql
@@../database/triggers/trg_erp_prdi_bu.sql
@@../database/triggers/trg_erp_prco_bu.sql
@@../database/triggers/trg_erp_par_bu.sql
@@../database/triggers/trg_erp_peri_bu.sql

prompt == Tipos
@@../database/types/erp_impuesto_calc_typ.sql
@@../database/types/erp_impuesto_calc_tab.sql

prompt == Paquetes (especificaciones)
@@../database/packages/erp_gen_parametro_ctr.pks
@@../database/packages/erp_gen_periodo_ctr.pks
@@../database/packages/erp_gen_persona_ctr.pks
@@../database/packages/erp_gen_moneda_reg.pks
@@../database/packages/erp_gen_impuesto_reg.pks
@@../database/packages/erp_gen_periodo_reg.pks
@@../database/packages/erp_gen_persona_reg.pks
@@../database/packages/erp_gen_parametro_api.pks
@@../database/packages/erp_gen_moneda_api.pks
@@../database/packages/erp_gen_impuesto_api.pks
@@../database/packages/erp_gen_periodo_api.pks
@@../database/packages/erp_gen_persona_api.pks

prompt == Paquetes (cuerpos)
@@../database/packages/erp_gen_parametro_ctr.pkb
@@../database/packages/erp_gen_periodo_ctr.pkb
@@../database/packages/erp_gen_persona_ctr.pkb
@@../database/packages/erp_gen_moneda_reg.pkb
@@../database/packages/erp_gen_impuesto_reg.pkb
@@../database/packages/erp_gen_periodo_reg.pkb
@@../database/packages/erp_gen_persona_reg.pkb
@@../database/packages/erp_gen_parametro_api.pkb
@@../database/packages/erp_gen_moneda_api.pkb
@@../database/packages/erp_gen_impuesto_api.pkb
@@../database/packages/erp_gen_periodo_api.pkb
@@../database/packages/erp_gen_persona_api.pkb

prompt == Registro en seguridad central
@@../database/data/erp_seg_registro.sql

prompt == Datos iniciales
@@../database/data/erp_gen_datos_iniciales.sql
@@../database/data/erp_gen_mensajes_error.sql

prompt == Objetos inválidos (debe estar vacío)
select object_name, object_type from user_objects
 where status = 'INVALID' and (object_name like 'ERP\_%' escape '\' or object_name like 'TRG\_ERP\_%' escape '\');

prompt == Instalación ERP completa
