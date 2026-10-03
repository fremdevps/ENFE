-- GENERADO por tools/build-supporting-objects.ps1 - NO EDITAR (fuente: apps/adm/database)

-- >>> apps/adm/database/triggers/trg_adm_gen_empresa_bu.sql
-- =============================================================================
-- Trigger : trg_adm_gen_empresa_bu
-- Tabla   : adm_gen_empresa
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_gen_empresa_bu
    before update on adm_gen_empresa
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_gen_empresa_bu;
/

-- >>> apps/adm/database/triggers/trg_adm_seg_aplicacion_bu.sql
-- =============================================================================
-- Trigger : trg_adm_seg_aplicacion_bu
-- Tabla   : adm_seg_aplicacion
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_seg_aplicacion_bu
    before update on adm_seg_aplicacion
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_seg_aplicacion_bu;
/

-- >>> apps/adm/database/triggers/trg_adm_seg_modulo_bu.sql
-- =============================================================================
-- Trigger : trg_adm_seg_modulo_bu
-- Tabla   : adm_seg_modulo
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_seg_modulo_bu
    before update on adm_seg_modulo
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_seg_modulo_bu;
/

-- >>> apps/adm/database/triggers/trg_adm_seg_permiso_bu.sql
-- =============================================================================
-- Trigger : trg_adm_seg_permiso_bu
-- Tabla   : adm_seg_permiso
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_seg_permiso_bu
    before update on adm_seg_permiso
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_seg_permiso_bu;
/

-- >>> apps/adm/database/triggers/trg_adm_seg_rol_bu.sql
-- =============================================================================
-- Trigger : trg_adm_seg_rol_bu
-- Tabla   : adm_seg_rol
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_seg_rol_bu
    before update on adm_seg_rol
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_seg_rol_bu;
/

-- >>> apps/adm/database/triggers/trg_adm_seg_rol_permiso_bu.sql
-- =============================================================================
-- Trigger : trg_adm_seg_rol_permiso_bu
-- Tabla   : adm_seg_rol_permiso
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_seg_rol_permiso_bu
    before update on adm_seg_rol_permiso
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_seg_rol_permiso_bu;
/

-- >>> apps/adm/database/triggers/trg_adm_seg_usuario_bu.sql
-- =============================================================================
-- Trigger : trg_adm_seg_usuario_bu
-- Tabla   : adm_seg_usuario
-- Desc    : Before Update - registra usuario y fecha de modificación.
--           Al desbloquear (B -> A) reinicia los intentos fallidos.
-- =============================================================================
create or replace trigger trg_adm_seg_usuario_bu
    before update on adm_seg_usuario
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;

    if :old.estado = 'B' and :new.estado = 'A' then
        :new.intentos_fallidos := 0;
    end if;
end trg_adm_seg_usuario_bu;
/

-- >>> apps/adm/database/triggers/trg_adm_seg_usuario_rol_bu.sql
-- =============================================================================
-- Trigger : trg_adm_seg_usuario_rol_bu
-- Tabla   : adm_seg_usuario_rol
-- Desc    : Before Update - registra usuario y fecha de modificación.
-- =============================================================================
create or replace trigger trg_adm_seg_usuario_rol_bu
    before update on adm_seg_usuario_rol
    for each row
begin
    :new.modificado_por     := coalesce(sys_context('APEX$SESSION','APP_USER'), user);
    :new.fecha_modificacion := systimestamp;
end trg_adm_seg_usuario_rol_bu;
/
