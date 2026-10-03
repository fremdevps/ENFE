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
