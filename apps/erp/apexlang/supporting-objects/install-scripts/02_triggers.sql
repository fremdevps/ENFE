-- GENERADO por tools/build-supporting-objects.ps1 - NO EDITAR (fuente: apps/erp/database)

-- >>> apps/erp/database/triggers/trg_erp_mon_bu.sql
-- =============================================================================
-- Trigger : trg_erp_mon_bu
-- Tabla   : erp_gen_moneda
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_mon_bu
    before update on erp_gen_moneda
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_mon_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_pai_bu.sql
-- =============================================================================
-- Trigger : trg_erp_pai_bu
-- Tabla   : erp_gen_pais
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_pai_bu
    before update on erp_gen_pais
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_pai_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_ubi_bu.sql
-- =============================================================================
-- Trigger : trg_erp_ubi_bu
-- Tabla   : erp_gen_ubicacion
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_ubi_bu
    before update on erp_gen_ubicacion
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_ubi_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_imp_bu.sql
-- =============================================================================
-- Trigger : trg_erp_imp_bu
-- Tabla   : erp_gen_impuesto
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_imp_bu
    before update on erp_gen_impuesto
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_imp_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_imta_bu.sql
-- =============================================================================
-- Trigger : trg_erp_imta_bu
-- Tabla   : erp_gen_impuesto_tasa
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_imta_bu
    before update on erp_gen_impuesto_tasa
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_imta_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_itv_bu.sql
-- =============================================================================
-- Trigger : trg_erp_itv_bu
-- Tabla   : erp_gen_impuesto_tasa_vig
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_itv_bu
    before update on erp_gen_impuesto_tasa_vig
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_itv_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_cafi_bu.sql
-- =============================================================================
-- Trigger : trg_erp_cafi_bu
-- Tabla   : erp_gen_categoria_fiscal
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_cafi_bu
    before update on erp_gen_categoria_fiscal
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_cafi_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_cata_bu.sql
-- =============================================================================
-- Trigger : trg_erp_cata_bu
-- Tabla   : erp_gen_categoria_tasa
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_cata_bu
    before update on erp_gen_categoria_tasa
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_cata_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_cot_bu.sql
-- =============================================================================
-- Trigger : trg_erp_cot_bu
-- Tabla   : erp_gen_cotizacion
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_cot_bu
    before update on erp_gen_cotizacion
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_cot_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_func_bu.sql
-- =============================================================================
-- Trigger : trg_erp_func_bu
-- Tabla   : erp_gen_funcionalidad
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_func_bu
    before update on erp_gen_funcionalidad
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_func_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_rub_bu.sql
-- =============================================================================
-- Trigger : trg_erp_rub_bu
-- Tabla   : erp_gen_rubro
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_rub_bu
    before update on erp_gen_rubro
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_rub_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_rufu_bu.sql
-- =============================================================================
-- Trigger : trg_erp_rufu_bu
-- Tabla   : erp_gen_rubro_func
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_rufu_bu
    before update on erp_gen_rubro_func
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_rufu_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_emcf_bu.sql
-- =============================================================================
-- Trigger : trg_erp_emcf_bu
-- Tabla   : erp_gen_empresa_config
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_emcf_bu
    before update on erp_gen_empresa_config
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_emcf_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_emfu_bu.sql
-- =============================================================================
-- Trigger : trg_erp_emfu_bu
-- Tabla   : erp_gen_empresa_func
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_emfu_bu
    before update on erp_gen_empresa_func
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_emfu_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_suc_bu.sql
-- =============================================================================
-- Trigger : trg_erp_suc_bu
-- Tabla   : erp_gen_sucursal
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_suc_bu
    before update on erp_gen_sucursal
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_suc_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_dpto_bu.sql
-- =============================================================================
-- Trigger : trg_erp_dpto_bu
-- Tabla   : erp_gen_departamento
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_dpto_bu
    before update on erp_gen_departamento
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_dpto_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_ptex_bu.sql
-- =============================================================================
-- Trigger : trg_erp_ptex_bu
-- Tabla   : erp_gen_punto_expedicion
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_ptex_bu
    before update on erp_gen_punto_expedicion
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_ptex_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_ussu_bu.sql
-- =============================================================================
-- Trigger : trg_erp_ussu_bu
-- Tabla   : erp_gen_usuario_sucursal
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_ussu_bu
    before update on erp_gen_usuario_sucursal
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_ussu_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_dpo_bu.sql
-- =============================================================================
-- Trigger : trg_erp_dpo_bu
-- Tabla   : erp_stk_deposito
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_dpo_bu
    before update on erp_stk_deposito
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_dpo_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_tdi_bu.sql
-- =============================================================================
-- Trigger : trg_erp_tdi_bu
-- Tabla   : erp_gen_tipo_doc_identidad
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_tdi_bu
    before update on erp_gen_tipo_doc_identidad
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_tdi_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_prs_bu.sql
-- =============================================================================
-- Trigger : trg_erp_prs_bu
-- Tabla   : erp_gen_persona
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_prs_bu
    before update on erp_gen_persona
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_prs_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_prdi_bu.sql
-- =============================================================================
-- Trigger : trg_erp_prdi_bu
-- Tabla   : erp_gen_persona_direccion
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_prdi_bu
    before update on erp_gen_persona_direccion
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_prdi_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_prco_bu.sql
-- =============================================================================
-- Trigger : trg_erp_prco_bu
-- Tabla   : erp_gen_persona_contacto
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_prco_bu
    before update on erp_gen_persona_contacto
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_prco_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_tirl_bu.sql
-- =============================================================================
-- Trigger : trg_erp_tirl_bu
-- Tabla   : erp_gen_tipo_rol
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_tirl_bu
    before update on erp_gen_tipo_rol
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_tirl_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_prro_bu.sql
-- =============================================================================
-- Trigger : trg_erp_prro_bu
-- Tabla   : erp_gen_persona_rol
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_prro_bu
    before update on erp_gen_persona_rol
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_prro_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_par_bu.sql
-- =============================================================================
-- Trigger : trg_erp_par_bu
-- Tabla   : erp_gen_parametro
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_par_bu
    before update on erp_gen_parametro
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_par_bu;
/

-- >>> apps/erp/database/triggers/trg_erp_peri_bu.sql
-- =============================================================================
-- Trigger : trg_erp_peri_bu
-- Tabla   : erp_gen_periodo
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_erp_peri_bu
    before update on erp_gen_periodo
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_erp_peri_bu;
/
