-- =============================================================================
-- Fija la contraseña del superadmin ADMIN (post-deploy o recuperación).
-- Ejecutar a mano conectado al esquema del workspace (o como DBA con prefijo).
-- La contraseña se pide por consola y NO queda en el repositorio.
-- ADMIN deberá cambiarla en su primer ingreso.
-- =============================================================================
set verify off
accept v_password char prompt 'Nueva contraseña para ADMIN (min 8, letras y números): ' hide

declare
    V_USUARIO_ID  number;
begin
    select usuario_id into V_USUARIO_ID from adm_seg_usuario where username = 'ADMIN';
    adm_usuario_ctr.P_CAMBIAR_PASSWORD(
        I_USUARIO_ID     => V_USUARIO_ID,
        I_PASSWORD_NUEVO => '&v_password',
        I_DEBE_CAMBIAR   => 'S');
    adm_usuario_ctr.P_DESBLOQUEAR(I_USUARIO_ID => V_USUARIO_ID);
    update adm_seg_usuario set estado = 'A' where usuario_id = V_USUARIO_ID;
    commit;
    dbms_output.put_line('Contraseña de ADMIN actualizada. Deberá cambiarla al ingresar.');
end;
/
undefine v_password
