create or replace package erp_doc_fe_firma_utl
    authid definer
as
-- =============================================================================
-- Paquete : erp_doc_fe_firma_utl   (capa utl)
-- Desc    : Firma digital XML (XMLDSig envuelta) de documentos electrónicos, nativa:
--           resumen SHA-256, SignedInfo, firma RSA-SHA256 con DBMS_CRYPTO.SIGN y
--           verificación con DBMS_CRYPTO.VERIFY (requiere Oracle 19.9 o superior).
--
--           Manual Técnico SIFEN v150 §7.6 y §7.7 (pág. 37-40), Schema XML 1:
--             CanonicalizationMethod  http://www.w3.org/TR/2001/REC-xml-c14n-20010315
--             SignatureMethod         http://www.w3.org/2001/04/xmldsig-more#rsa-sha256
--             Reference URI           "#" + CDC (atributo Id del elemento firmado)
--             Transforms (2)          http://www.w3.org/2000/09/xmldsig#enveloped-signature
--                                     http://www.w3.org/2001/10/xml-exc-c14n#
--             DigestMethod            http://www.w3.org/2001/04/xmlenc#sha256
--             KeyInfo                 solo X509Data/X509Certificate
--
--           Formato de claves comprobado en la base (ver docs/diseno-fase2-documentos-sifen.md):
--             clave privada : texto Base64 del PEM (PKCS#8 o PKCS#1), sin cabeceras ni saltos
--             clave pública : texto Base64 del SubjectPublicKeyInfo (o PKCS#1), igual
--           El binario DER directo y el certificado completo NO son aceptados por DBMS_CRYPTO.
-- =============================================================================

    c_err_clave_invalida  constant pls_integer := -20142;

    c_alg_canonico   constant varchar2(60) := 'http://www.w3.org/TR/2001/REC-xml-c14n-20010315';
    c_alg_firma      constant varchar2(60) := 'http://www.w3.org/2001/04/xmldsig-more#rsa-sha256';
    c_alg_envuelta   constant varchar2(60) := 'http://www.w3.org/2000/09/xmldsig#enveloped-signature';
    c_alg_exclusivo  constant varchar2(60) := 'http://www.w3.org/2001/10/xml-exc-c14n#';
    c_alg_resumen    constant varchar2(60) := 'http://www.w3.org/2001/04/xmlenc#sha256';

    -- Quita cabeceras "-----BEGIN…-----", saltos y espacios de un PEM; deja solo el Base64.
    function limpiar_pem (
        i_pem  in clob
    ) return varchar2;

    -- SHA-256 de los bytes UTF-8 del XML canónico, en Base64 (DigestValue).
    function calcular_resumen (
        i_xml_canonico  in clob
    ) return varchar2;

    -- Elemento SignedInfo. Con i_es_canonico = true devuelve la forma canónica (C14N 1.0
    -- inclusiva) que realmente se firma: lleva los namespaces heredados del documento
    -- (el de la firma y, si el rDE lo declara, xmlns:xsi). Con false, la forma que se
    -- escribe dentro de <Signature>.
    function generar_signed_info (
        i_id             in varchar2,
        i_resumen        in varchar2,
        i_es_canonico    in boolean,
        i_declara_xsi    in boolean
    ) return varchar2;

    -- Firma RSA-SHA256 (PKCS#1 v1.5) de los bytes UTF-8 del texto, en Base64.
    function firmar (
        i_texto          in varchar2,
        i_clave_privada  in varchar2
    ) return varchar2;

    function es_firma_valida (
        i_texto          in varchar2,
        i_firma          in varchar2,
        i_clave_publica  in varchar2
    ) return boolean;

    -- Elemento <Signature> completo para insertar en el documento después del elemento firmado.
    function generar_firma (
        i_id             in varchar2,
        i_resumen        in varchar2,
        i_clave_privada  in varchar2,
        i_certificado    in varchar2,
        i_declara_xsi    in boolean
    ) return varchar2;

    -- Clave pública (SubjectPublicKeyInfo en Base64) de un certificado X.509 en Base64.
    function extraer_clave_publica (
        i_certificado  in varchar2
    ) return varchar2;

    -- Período de validez del certificado (UTC).
    procedure extraer_vigencia (
        i_certificado  in  varchar2,
        o_fecha_desde  out timestamp,
        o_fecha_hasta  out timestamp
    );

    -- Huella SHA-256 del certificado, en hexadecimal.
    function calcular_huella (
        i_certificado  in varchar2
    ) return varchar2;

end erp_doc_fe_firma_utl;
/
