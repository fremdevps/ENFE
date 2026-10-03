-- =============================================================================
-- Fija la contraseña del superadmin ADMIN (post-deploy o recuperación).
-- Ejecutar a mano conectado al esquema del workspace.
-- La contraseña se pide por consola y NO queda en el repositorio.
-- ADMIN deberá cambiarla en su primer ingreso; queda desbloqueado.
-- =============================================================================
set verify off
accept v_password char prompt 'Nueva contraseña para ADMIN (min 8, letras y números): ' hide

declare
    v_usuario_id  adm_seg_usuario.usuario_id%type;
begin
    select usuario_id into v_usuario_id from adm_seg_usuario where username = 'ADMIN';
    adm_seg_usuario_api.resetear_password(
        i_usuario_id     => v_usuario_id,
        i_password_nuevo => '&v_password');
    commit;
    dbms_output.put_line('Contraseña de ADMIN actualizada. Deberá cambiarla al ingresar.');
end;
/
undefine v_password
