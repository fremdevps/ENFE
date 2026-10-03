create or replace package body adm_seg_password_utl
as

    c_iteraciones       constant pls_integer := 10000;
    c_password_min_len  constant pls_integer := 8;

    function generar_salt return raw is
    begin
        return dbms_crypto.randombytes(32);
    end generar_salt;

    function calcular_hash (
        i_password  in varchar2,
        i_salt      in raw
    ) return raw is
        v_clave  raw(2000);
        v_u      raw(64);
        v_t      raw(64);
    begin
        if i_password is null or i_salt is null then
            return null;
        end if;

        v_clave := utl_i18n.string_to_raw(i_password, 'AL32UTF8');
        v_u     := dbms_crypto.mac(utl_raw.concat(i_salt, hextoraw('00000001')),
                                   dbms_crypto.hmac_sh512, v_clave);
        v_t     := v_u;

        for i in 2 .. c_iteraciones loop
            v_u := dbms_crypto.mac(v_u, dbms_crypto.hmac_sh512, v_clave);
            v_t := utl_raw.bit_xor(v_t, v_u);
        end loop;

        return v_t;
    end calcular_hash;

    function es_valido (
        i_password  in varchar2,
        i_salt      in raw,
        i_hash      in raw
    ) return boolean is
        v_calculado  raw(64);
    begin
        v_calculado := calcular_hash(i_password => i_password, i_salt => i_salt);
        return v_calculado is not null
           and i_hash      is not null
           and utl_raw.compare(v_calculado, i_hash) = 0;
    end es_valido;

    procedure validar_politica (
        i_password  in varchar2
    ) is
    begin
        if i_password is null
           or length(i_password) < c_password_min_len
           or not regexp_like(i_password, '[0-9]')
           or not regexp_like(i_password, '[A-Za-z]')
        then
            raise_application_error(c_err_politica,
                'La contraseña debe tener al menos ' || c_password_min_len ||
                ' caracteres e incluir letras y números.');
        end if;
    end validar_politica;

end adm_seg_password_utl;
/
