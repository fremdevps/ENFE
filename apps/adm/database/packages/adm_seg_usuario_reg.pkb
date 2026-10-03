create or replace package body adm_seg_usuario_reg
as

    procedure validar_es_local (
        i_usuario_id  in adm_seg_usuario.usuario_id%type
    ) is
        r_usuario  adm_seg_usuario%rowtype;
    begin
        r_usuario := adm_seg_usuario_ctr.obtener(i_usuario_id => i_usuario_id);
        if r_usuario.tipo_autenticacion <> 'LOCAL' then
            raise_application_error(c_err_no_local,
                'El usuario ' || r_usuario.username || ' no usa autenticación local.');
        end if;
    end validar_es_local;

    procedure validar_cambio_password (
        i_usuario_id        in adm_seg_usuario.usuario_id%type,
        i_password_actual   in varchar2,
        i_password_nuevo    in varchar2,
        i_password_confirma in varchar2
    ) is
        r_usuario  adm_seg_usuario%rowtype;
    begin
        validar_es_local(i_usuario_id => i_usuario_id);
        r_usuario := adm_seg_usuario_ctr.obtener(i_usuario_id => i_usuario_id);

        if not adm_seg_password_utl.es_valido(i_password => i_password_actual,
                                              i_salt     => r_usuario.password_salt,
                                              i_hash     => r_usuario.password_hash)
        then
            raise_application_error(c_err_password_actual, 'La contraseña actual no es correcta.');
        end if;

        if i_password_nuevo is null or i_password_nuevo <> i_password_confirma then
            raise_application_error(c_err_confirmacion, 'La confirmación no coincide con la nueva contraseña.');
        end if;

        if i_password_actual = i_password_nuevo then
            raise_application_error(c_err_password_igual, 'La nueva contraseña debe ser distinta a la actual.');
        end if;

        adm_seg_password_utl.validar_politica(i_password => i_password_nuevo);
    end validar_cambio_password;

end adm_seg_usuario_reg;
/
