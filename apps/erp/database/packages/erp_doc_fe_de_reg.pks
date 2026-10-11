create or replace package erp_doc_fe_de_reg
    authid definer
as
-- =============================================================================
-- Paquete : erp_doc_fe_de_reg   (capa reg)
-- Desc    : Armado del documento electrónico (DE) de SIFEN a partir de una estructura de
--           entrada JSON estable (documentada en docs/diseno-fase2-documentos-sifen.md §5),
--           firma y armado del rDE completo (DE + Signature + gCamFuFD con el QR), y
--           verificación de un rDE ya firmado. No lee ni escribe tablas de documentos:
--           recibe todo por parámetro (el módulo de ventas arma el JSON).
--
--           Manual Técnico SIFEN v150, Schema XML 18 DE_v150.xsd (pág. 61-111).
--           Tipos soportados en esta etapa: 1 factura, 5 nota de crédito y 6 nota de débito
--           electrónicas. Autofactura (4) y nota de remisión (7) quedan para la siguiente.
--
--           El XML se emite en forma canónica por construcción (erp_doc_fe_xml_utl); el
--           contenido del elemento DE se guarda aparte de su etiqueta porque la forma
--           canónica exclusiva del DE (lo que se resume) lleva el namespace en la etiqueta
--           y la forma dentro del rDE no.
-- =============================================================================

    c_err_dato_invalido   constant pls_integer := -20141;
    c_err_firma_invalida  constant pls_integer := -20143;

    type t_de is record (
        cdc                        varchar2(44),
        codigo_seguridad           varchar2(9),
        version_formato            varchar2(3),
        tipo_de                    number,
        timbrado                   varchar2(8),
        establecimiento            varchar2(3),
        punto_expedicion           varchar2(3),
        numero                     number,
        serie                      varchar2(2),
        tipo_emision               number,
        fecha_emision              timestamp,
        fecha_firma                timestamp,
        receptor_documento         varchar2(20),
        receptor_nombre            varchar2(255),
        es_receptor_contribuyente  boolean,
        moneda                     varchar2(3),
        monto_total                number,
        monto_impuesto             number,
        cantidad_items             pls_integer,
        contenido                  clob      -- contenido del elemento <DE>, sin su etiqueta
    );

    -- Valida los datos, calcula totales e impuestos según las fórmulas del manual, genera
    -- el CDC y arma el contenido del DE.
    function generar_de (
        i_datos             in clob,
        i_codigo_seguridad  in varchar2,
        i_fecha_firma       in timestamp,
        i_version_formato   in varchar2 default '150'
    ) return t_de;

    -- Forma canónica exclusiva del elemento DE: lo que se resume con SHA-256.
    function obtener_de_canonico (
        i_cdc        in varchar2,
        i_contenido  in clob
    ) return clob;

    -- Firma el DE y arma el rDE completo.
    procedure generar_rde (
        i_de                in  t_de,
        i_clave_privada     in  varchar2,
        i_certificado       in  varchar2,
        i_id_csc            in  varchar2,
        i_csc               in  varchar2,
        i_url_consulta_qr   in  varchar2,
        i_declara_esquema   in  boolean,
        o_xml               out nocopy clob,
        o_resumen           out varchar2,
        o_url_qr            out varchar2
    );

    -- Verifica un rDE generado por este paquete: resumen del DE, coherencia del SignedInfo
    -- y firma RSA. Devuelve null si es válido o el motivo si no lo es. Sin clave pública
    -- usa la del certificado incluido en el XML.
    function obtener_error_firma (
        i_xml            in clob,
        i_clave_publica  in varchar2 default null
    ) return varchar2;

    procedure validar_firma (
        i_xml            in clob,
        i_clave_publica  in varchar2 default null
    );

end erp_doc_fe_de_reg;
/
