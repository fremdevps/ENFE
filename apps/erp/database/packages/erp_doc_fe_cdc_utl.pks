create or replace package erp_doc_fe_cdc_utl
    authid definer
as
-- =============================================================================
-- Paquete : erp_doc_fe_cdc_utl   (capa utl)
-- Desc    : Código de control (CDC) de 44 dígitos de los documentos electrónicos,
--           su dígito verificador y el código de seguridad aleatorio.
--           Manual Técnico SIFEN v150 §10.1 a §10.3 (pág. 56-57).
--
--           CDC = tipo de documento (2) + RUC del emisor (8) + DV del RUC (1)
--               + establecimiento (3) + punto de expedición (3) + número (7)
--               + tipo de contribuyente (1) + fecha de emisión AAAAMMDD (8)
--               + tipo de emisión (1) + código de seguridad (9) + dígito verificador (1)
--
--           Ejemplo del manual: 01 44444401 7 001 001 0014528 2 20170125 1 587326098 8
-- =============================================================================

    c_err_dato_invalido  constant pls_integer := -20140;

    -- Dígito verificador módulo 11 (factores 2 a 11 de derecha a izquierda). Las letras se
    -- reemplazan por su código ASCII (nota del campo A002, pág. 61).
    function calcular_dv (
        i_base  in varchar2
    ) return varchar2;

    -- Número aleatorio de 9 dígitos entre 000000001 y 999999999, distinto del número del
    -- documento y sin relación con sus datos (§10.3).
    function generar_codigo_seguridad (
        i_numero_documento  in number default null
    ) return varchar2;

    function generar_cdc (
        i_tipo_de             in number,
        i_ruc                 in varchar2,
        i_dv_ruc              in varchar2,
        i_establecimiento     in varchar2,
        i_punto_expedicion    in varchar2,
        i_numero              in number,
        i_tipo_contribuyente  in number,
        i_fecha_emision       in date,
        i_tipo_emision        in number,
        i_codigo_seguridad    in varchar2
    ) return varchar2;

    -- 'S' si tiene 44 dígitos y su dígito verificador es correcto.
    function es_valido_sn (
        i_cdc  in varchar2
    ) return varchar2;

    -- Grupos de cuatro dígitos separados por un espacio, como se muestra en el KuDE.
    function formatear_cdc (
        i_cdc  in varchar2
    ) return varchar2;

end erp_doc_fe_cdc_utl;
/
