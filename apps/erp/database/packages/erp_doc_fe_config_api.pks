create or replace package erp_doc_fe_config_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_doc_fe_config_api   (capa api)
-- Desc    : Configuración de facturación electrónica de la empresa: certificado digital,
--           CSC del QR y datos del emisor para el documento electrónico.
--           La clave privada y el CSC se guardan cifrados con una frase que entrega quien
--           invoca y que no se almacena (erp_doc_fe_secreto_utl).
--           Requiere el permiso ERP_DOC_FE_CONFIGURAR dentro de una sesión APEX.
-- =============================================================================

    c_err_sin_permiso  constant pls_integer := -20137;
    c_err_config       constant pls_integer := -20144;

    c_permiso_configurar  constant varchar2(30) := 'ERP_DOC_FE_CONFIGURAR';

    -- Literal obligatorio en la razón social del emisor en el ambiente de pruebas
    -- (Manual Técnico SIFEN v150, campo D105 dNomEmi, pág. 68).
    c_nombre_ambiente_prueba  constant varchar2(80) := 'DE generado en ambiente de prueba - sin valor comercial ni fiscal';

    -- Registra un certificado X.509 con su clave privada RSA (ambos en PEM o en Base64).
    -- Comprueba que la clave corresponde al certificado antes de guardarla cifrada.
    procedure registrar_certificado (
        i_empresa_id         in  number,
        i_nombre             in  varchar2,
        i_certificado        in  clob,
        i_clave_privada      in  clob,
        i_frase              in  varchar2,
        i_es_prueba          in  varchar2 default 'N',
        i_debe_asignar       in  varchar2 default 'S',
        o_fe_certificado_id  out number
    );

    -- Guarda el identificador y el valor del CSC (cifrado).
    procedure asignar_csc (
        i_empresa_id  in number,
        i_id_csc      in varchar2,
        i_csc         in varchar2,
        i_frase       in varchar2
    );

    -- Grupo "emisor" de la estructura de entrada del DE (JSON), armado con los datos de la
    -- empresa, la sucursal del punto de expedición y las actividades económicas.
    function obtener_emisor (
        i_empresa_id           in number,
        i_punto_expedicion_id  in number
    ) return clob;

end erp_doc_fe_config_api;
/
