create or replace package adm_seg_password_utl
    authid definer
as
-- =============================================================================
-- Paquete : adm_seg_password_utl   (capa utl)
-- Desc    : Hash y política de contraseñas. Sin acceso a tablas.
--           PBKDF2-HMAC-SHA512 (1 bloque de 64 bytes) + salt aleatorio de 32 bytes.
-- Requiere: grant execute on dbms_crypto (install/00_prerequisitos_dba.sql)
-- =============================================================================

    c_err_politica  constant pls_integer := -20010;

    function generar_salt return raw;

    function calcular_hash (
        i_password  in varchar2,
        i_salt      in raw
    ) return raw;

    -- NULL-safe: password, salt o hash nulos nunca validan.
    function es_valido (
        i_password  in varchar2,
        i_salt      in raw,
        i_hash      in raw
    ) return boolean;

    -- Lanza c_err_politica si la contraseña no cumple la política.
    procedure validar_politica (
        i_password  in varchar2
    );

end adm_seg_password_utl;
/
