-- =============================================================================
-- Crea el primer usuario SUPERADMIN. Ejecutar UNA vez por ambiente, a mano
-- (SQLcl / SQL Developer). La contraseña se pide por consola y NO se guarda
-- en el repositorio. El usuario deberá cambiarla en su primer ingreso.
-- =============================================================================
set verify off
accept v_username char prompt 'Usuario administrador: '
accept v_email    char prompt 'Email: '
accept v_nombres  char prompt 'Nombres: '
accept v_password char prompt 'Contraseña inicial (min 8, letras y números): ' hide

declare
    V_USUARIO_ID  number;
    V_ROL_ID      number;
begin
    adm_usuario_ctr.P_INSERTAR(
        I_USERNAME   => '&v_username',
        I_EMAIL      => '&v_email',
        I_NOMBRES    => '&v_nombres',
        I_PASSWORD   => '&v_password',
        O_USUARIO_ID => V_USUARIO_ID);

    select rol_id into V_ROL_ID from adm_seg_rol where codigo = 'SUPERADMIN';

    adm_usuario_ctr.P_ASIGNAR_ROL(
        I_USUARIO_ID => V_USUARIO_ID,
        I_ROL_ID     => V_ROL_ID);

    commit;
    dbms_output.put_line('Usuario SUPERADMIN creado: ' || upper('&v_username'));
end;
/
undefine v_password
