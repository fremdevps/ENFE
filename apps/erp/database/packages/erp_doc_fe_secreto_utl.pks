create or replace package erp_doc_fe_secreto_utl
    authid definer
as
-- =============================================================================
-- Paquete : erp_doc_fe_secreto_utl   (capa utl)
-- Desc    : Cifrado de los secretos de facturación electrónica que se guardan en tablas
--           (clave privada del certificado y CSC del QR). La frase de cifrado NO se guarda
--           en la base ni en el repositorio: la entrega quien invoca.
--
--           Formato del dato cifrado:
--             versión (1 byte = 01) + sal (16) + vector de inicialización (16)
--             + AES-256-CBC/PKCS5 del dato + HMAC-SHA256 de todo lo anterior (32)
--           Claves derivadas de la frase con PBKDF2-HMAC-SHA256 (una para cifrar y otra
--           para autenticar). Una frase incorrecta o un dato alterado se detectan por el HMAC.
-- =============================================================================

    c_err_frase_invalida  constant pls_integer := -20151;

    function cifrar (
        i_dato   in raw,
        i_frase  in varchar2
    ) return raw;

    function descifrar (
        i_cifrado  in raw,
        i_frase    in varchar2
    ) return raw;

end erp_doc_fe_secreto_utl;
/
