create or replace package body erp_doc_fe_secreto_utl
as

    c_version        constant raw(1)      := hextoraw('01');
    c_iteraciones    constant pls_integer := 10000;
    c_largo_frase    constant pls_integer := 12;
    c_aes256_cbc     constant pls_integer := dbms_crypto.encrypt_aes256 + dbms_crypto.chain_cbc + dbms_crypto.pad_pkcs5;

    procedure validar_frase (
        i_frase  in varchar2
    ) is
    begin
        if i_frase is null or length(i_frase) < c_largo_frase then
            raise_application_error(c_err_frase_invalida,
                'La frase de cifrado debe tener al menos ' || c_largo_frase || ' caracteres.');
        end if;
    end validar_frase;

    -- PBKDF2-HMAC-SHA256 (RFC 8018): devuelve 64 bytes, 32 para cifrar y 32 para autenticar.
    function derivar_claves (
        i_frase  in varchar2,
        i_sal    in raw
    ) return raw is
        v_frase   raw(2000) := utl_i18n.string_to_raw(i_frase, 'AL32UTF8');
        v_salida  raw(64);
        v_u       raw(32);
        v_t       raw(32);
    begin
        for v_bloque in 1 .. 2 loop
            v_u := dbms_crypto.mac(src => utl_raw.concat(i_sal, hextoraw('0000000' || v_bloque)),
                                   typ => dbms_crypto.hmac_sh256,
                                   key => v_frase);
            v_t := v_u;
            for v_i in 2 .. c_iteraciones loop
                v_u := dbms_crypto.mac(src => v_u, typ => dbms_crypto.hmac_sh256, key => v_frase);
                v_t := utl_raw.bit_xor(v_t, v_u);
            end loop;
            v_salida := utl_raw.concat(v_salida, v_t);
        end loop;
        return v_salida;
    end derivar_claves;

    function cifrar (
        i_dato   in raw,
        i_frase  in varchar2
    ) return raw is
        v_sal     raw(16) := dbms_crypto.randombytes(16);
        v_iv      raw(16) := dbms_crypto.randombytes(16);
        v_claves  raw(64);
        v_cuerpo  raw(32767);
    begin
        validar_frase(i_frase => i_frase);
        if i_dato is null then
            return null;
        end if;
        v_claves := derivar_claves(i_frase => i_frase, i_sal => v_sal);
        v_cuerpo := utl_raw.concat(c_version, v_sal, v_iv,
                                   dbms_crypto.encrypt(src => i_dato,
                                                       typ => c_aes256_cbc,
                                                       key => utl_raw.substr(v_claves, 1, 32),
                                                       iv  => v_iv));
        return utl_raw.concat(v_cuerpo,
                              dbms_crypto.mac(src => v_cuerpo,
                                              typ => dbms_crypto.hmac_sh256,
                                              key => utl_raw.substr(v_claves, 33, 32)));
    end cifrar;

    function descifrar (
        i_cifrado  in raw,
        i_frase    in varchar2
    ) return raw is
        v_largo   pls_integer := coalesce(utl_raw.length(i_cifrado), 0);
        v_claves  raw(64);
        v_cuerpo  raw(32767);
    begin
        validar_frase(i_frase => i_frase);
        if i_cifrado is null then
            return null;
        end if;
        -- versión + sal + vector + al menos un bloque + autenticación
        if v_largo < 1 + 16 + 16 + 16 + 32 or utl_raw.substr(i_cifrado, 1, 1) <> c_version then
            raise_application_error(c_err_frase_invalida, 'El dato cifrado no tiene el formato esperado.');
        end if;
        v_cuerpo := utl_raw.substr(i_cifrado, 1, v_largo - 32);
        v_claves := derivar_claves(i_frase => i_frase, i_sal => utl_raw.substr(i_cifrado, 2, 16));
        if dbms_crypto.mac(src => v_cuerpo, typ => dbms_crypto.hmac_sh256, key => utl_raw.substr(v_claves, 33, 32))
           <> utl_raw.substr(i_cifrado, v_largo - 31, 32) then
            raise_application_error(c_err_frase_invalida, 'La frase de cifrado no es correcta o el dato fue alterado.');
        end if;
        return dbms_crypto.decrypt(src => utl_raw.substr(v_cuerpo, 34),
                                   typ => c_aes256_cbc,
                                   key => utl_raw.substr(v_claves, 1, 32),
                                   iv  => utl_raw.substr(v_cuerpo, 18, 16));
    end descifrar;

end erp_doc_fe_secreto_utl;
/
