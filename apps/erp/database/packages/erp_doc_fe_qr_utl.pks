create or replace package erp_doc_fe_qr_utl
    authid definer
as
-- =============================================================================
-- Paquete : erp_doc_fe_qr_utl   (capa utl)
-- Desc    : Cadena y hash del código QR de los documentos electrónicos (campo J002 dCarQR).
--           Manual Técnico SIFEN v150 §13.8 (pág. 205-209):
--             1. datos = nVersion=…&Id=…&dFeEmiDE=<hex>&dRucRec|dNumIDRec=…&dTotGralOpe=…
--                        &dTotIVA=…&cItems=…&DigestValue=<hex>&IdCSC=…
--             2. hash  = SHA-256( datos || CSC ) en hexadecimal
--             3. URL   = dirección de consulta + datos + &cHashQR=<hash>
--           La fecha de emisión y el DigestValue van en hexadecimal; el CSC nunca viaja.
--           Al escribir la URL en el XML los "&" se escapan como en cualquier texto XML.
-- =============================================================================

    c_err_dato_invalido  constant pls_integer := -20150;

    c_url_produccion  constant varchar2(60) := 'https://ekuatia.set.gov.py/consultas/qr?';
    c_url_test        constant varchar2(60) := 'https://ekuatia.set.gov.py/consultas-test/qr?';

    -- Dirección de consulta del manual según el ambiente ('P' producción, 'T' test).
    function obtener_url_consulta (
        i_ambiente  in varchar2
    ) return varchar2;

    -- Paso 1: parámetros concatenados (sin la dirección y sin el hash).
    function generar_datos (
        i_version           in varchar2,
        i_cdc               in varchar2,
        i_fecha_emision     in timestamp,
        i_receptor          in varchar2,
        i_es_contribuyente  in boolean,
        i_total             in number,
        i_total_iva         in number,
        i_cantidad_items    in number,
        i_resumen           in varchar2,
        i_id_csc            in varchar2
    ) return varchar2;

    -- Pasos 2 y 3: SHA-256 de los datos más el CSC, en hexadecimal en minúsculas.
    function calcular_hash (
        i_datos  in varchar2,
        i_csc    in varchar2
    ) return varchar2;

    -- Paso 4: dirección completa para la imagen QR (sin escapar).
    function generar_url (
        i_url_consulta      in varchar2,
        i_version           in varchar2,
        i_cdc               in varchar2,
        i_fecha_emision     in timestamp,
        i_receptor          in varchar2,
        i_es_contribuyente  in boolean,
        i_total             in number,
        i_total_iva         in number,
        i_cantidad_items    in number,
        i_resumen           in varchar2,
        i_id_csc            in varchar2,
        i_csc               in varchar2
    ) return varchar2;

end erp_doc_fe_qr_utl;
/
