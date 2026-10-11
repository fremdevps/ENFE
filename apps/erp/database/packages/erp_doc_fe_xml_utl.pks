create or replace package erp_doc_fe_xml_utl
    authid definer
as
-- =============================================================================
-- Paquete : erp_doc_fe_xml_utl   (capa utl)
-- Desc    : Serializador XML para documentos electrónicos. Emite el XML YA EN FORMA
--           CANÓNICA (sin espacios entre etiquetas, sin prefijos, escape de C14N,
--           elementos vacíos nunca abreviados), porque la base no trae una función de
--           canonicalización. Codificación UTF-8, Base64 y hexadecimal.
--           Manual Técnico SIFEN v150 §7.2 (pág. 30-35): UTF-8, sin prefijos de
--           namespace, sin espacios ni saltos entre etiquetas, sin etiquetas vacías,
--           punto como separador decimal.
-- =============================================================================

    c_ns_sifen  constant varchar2(60) := 'http://ekuatia.set.gov.py/sifen/xsd';
    c_ns_dsig   constant varchar2(60) := 'http://www.w3.org/2000/09/xmldsig#';
    c_ns_xsi    constant varchar2(60) := 'http://www.w3.org/2001/XMLSchema-instance';

    -- Quita caracteres de control y espacios sobrantes (un valor nunca lleva saltos de línea).
    function limpiar_valor (
        i_valor  in varchar2
    ) return varchar2;

    -- Escape de texto de la forma canónica: & < >  (las comillas no se escapan en texto).
    function escapar_texto (
        i_valor  in varchar2
    ) return varchar2;

    -- Escape de valor de atributo de la forma canónica: & < "
    function escapar_atributo (
        i_valor  in varchar2
    ) return varchar2;

    -- Número con punto decimal, sin separador de miles ni ceros sobrantes (1105.13).
    function formatear_numero (
        i_valor         in number,
        i_decimales_max in pls_integer default 8
    ) return varchar2;

    -- AAAA-MM-DD
    function formatear_fecha (
        i_fecha  in date
    ) return varchar2;

    -- AAAA-MM-DDThh:mm:ss
    function formatear_fecha_hora (
        i_fecha  in timestamp
    ) return varchar2;

    -- Agrega texto ya serializado al documento.
    procedure agregar (
        io_xml   in out nocopy clob,
        i_texto  in varchar2
    );

    -- <nombre>valor</nombre> con el valor limpio y escapado. Si el valor es nulo no agrega
    -- nada (el manual prohíbe etiquetas sin valor).
    procedure agregar_elemento (
        io_xml    in out nocopy clob,
        i_nombre  in varchar2,
        i_valor   in varchar2
    );

    -- Bytes UTF-8 del documento (lo que se firma y se transmite).
    function convertir_a_utf8 (
        i_xml  in clob
    ) return blob;

    -- Base64 en una sola línea (sin saltos).
    function codificar_base64 (
        i_datos  in raw
    ) return varchar2;

    function codificar_base64 (
        i_datos  in blob
    ) return clob;

    function decodificar_base64 (
        i_texto  in varchar2
    ) return raw;

    -- Hexadecimal en minúsculas de los bytes UTF-8 del texto.
    function convertir_a_hex (
        i_texto  in varchar2
    ) return varchar2;

    -- 'S' si el analizador XML de la base acepta el documento.
    function es_bien_formado_sn (
        i_xml  in clob
    ) return varchar2;

end erp_doc_fe_xml_utl;
/
