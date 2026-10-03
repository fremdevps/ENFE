-- GENERADO por tools/build-supporting-objects.ps1 - NO EDITAR (fuente: apps/adm/database)

-- >>> apps/adm/database/triggers/trg_adm_emp_bu.sql
-- =============================================================================
-- Trigger : trg_adm_emp_bu
-- Tabla   : adm_gen_empresa
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_emp_bu
    before update on adm_gen_empresa
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_emp_bu;
/

-- >>> apps/adm/database/triggers/trg_adm_apl_bu.sql
-- =============================================================================
-- Trigger : trg_adm_apl_bu
-- Tabla   : adm_seg_aplicacion
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_apl_bu
    before update on adm_seg_aplicacion
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_apl_bu;
/

-- >>> apps/adm/database/triggers/trg_adm_mod_bu.sql
-- =============================================================================
-- Trigger : trg_adm_mod_bu
-- Tabla   : adm_seg_modulo
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_mod_bu
    before update on adm_seg_modulo
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_mod_bu;
/

-- >>> apps/adm/database/triggers/trg_adm_per_bu.sql
-- =============================================================================
-- Trigger : trg_adm_per_bu
-- Tabla   : adm_seg_permiso
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_per_bu
    before update on adm_seg_permiso
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_per_bu;
/

-- >>> apps/adm/database/triggers/trg_adm_rol_bu.sql
-- =============================================================================
-- Trigger : trg_adm_rol_bu
-- Tabla   : adm_seg_rol
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_rol_bu
    before update on adm_seg_rol
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_rol_bu;
/

-- >>> apps/adm/database/triggers/trg_adm_rope_bu.sql
-- =============================================================================
-- Trigger : trg_adm_rope_bu
-- Tabla   : adm_seg_rol_permiso
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_rope_bu
    before update on adm_seg_rol_permiso
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_rope_bu;
/

-- >>> apps/adm/database/triggers/trg_adm_usu_bu.sql
-- =============================================================================
-- Trigger : trg_adm_usu_bu
-- Tabla   : adm_seg_usuario
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_usu_bu
    before update on adm_seg_usuario
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;

    -- Desbloquear (B -> A) reinicia los intentos fallidos
    if :old.estado = 'B' and :new.estado = 'A' then
        :new.intentos_fallidos := 0;
    end if;
end trg_adm_usu_bu;
/

-- >>> apps/adm/database/triggers/trg_adm_mse_bu.sql
-- =============================================================================
-- Trigger : trg_adm_mse_bu
-- Tabla   : adm_gen_mensaje_error
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_mse_bu
    before update on adm_gen_mensaje_error
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_mse_bu;
/

-- >>> apps/adm/database/triggers/trg_adm_usro_bu.sql
-- =============================================================================
-- Trigger : trg_adm_usro_bu
-- Tabla   : adm_seg_usuario_rol
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_usro_bu
    before update on adm_seg_usuario_rol
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_usro_bu;
/
