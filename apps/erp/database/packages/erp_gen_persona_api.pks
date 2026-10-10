create or replace package erp_gen_persona_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_persona_api   (capa api)
-- Desc    : Alta y modificación de personas para APEX / REST. Normaliza y valida
--           el documento (formato y dígito verificador) antes de guardar.
-- =============================================================================

    procedure crear (
        i_tipo_persona           in  erp_gen_persona.tipo_persona%type,
        i_tipo_doc_identidad_id  in  erp_gen_persona.tipo_doc_identidad_id%type,
        i_nro_documento          in  erp_gen_persona.nro_documento%type,
        i_dv                     in  erp_gen_persona.dv%type,
        i_razon_social           in  erp_gen_persona.razon_social%type,
        i_nombres                in  erp_gen_persona.nombres%type,
        i_apellidos              in  erp_gen_persona.apellidos%type,
        i_nombre_fantasia        in  erp_gen_persona.nombre_fantasia%type,
        i_es_contribuyente       in  erp_gen_persona.es_contribuyente%type,
        i_pais_id                in  erp_gen_persona.pais_id%type,
        i_fecha_nacimiento       in  erp_gen_persona.fecha_nacimiento%type,
        i_email                  in  erp_gen_persona.email%type,
        i_telefono               in  erp_gen_persona.telefono%type,
        i_observacion            in  erp_gen_persona.observacion%type,
        i_estado                 in  erp_gen_persona.estado%type,
        o_persona_id             out erp_gen_persona.persona_id%type
    );

    procedure modificar (
        i_persona_id             in erp_gen_persona.persona_id%type,
        i_tipo_persona           in erp_gen_persona.tipo_persona%type,
        i_tipo_doc_identidad_id  in erp_gen_persona.tipo_doc_identidad_id%type,
        i_nro_documento          in erp_gen_persona.nro_documento%type,
        i_dv                     in erp_gen_persona.dv%type,
        i_razon_social           in erp_gen_persona.razon_social%type,
        i_nombres                in erp_gen_persona.nombres%type,
        i_apellidos              in erp_gen_persona.apellidos%type,
        i_nombre_fantasia        in erp_gen_persona.nombre_fantasia%type,
        i_es_contribuyente       in erp_gen_persona.es_contribuyente%type,
        i_pais_id                in erp_gen_persona.pais_id%type,
        i_fecha_nacimiento       in erp_gen_persona.fecha_nacimiento%type,
        i_email                  in erp_gen_persona.email%type,
        i_telefono               in erp_gen_persona.telefono%type,
        i_observacion            in erp_gen_persona.observacion%type,
        i_estado                 in erp_gen_persona.estado%type
    );

    -- Valida formato y dígito verificador (documentos adicionales de la persona).
    procedure validar_documento (
        i_tipo_doc_identidad_id  in number,
        i_nro_documento          in varchar2,
        i_dv                     in varchar2
    );

    -- Para mostrar el DV sugerido en pantalla.
    function obtener_dv_ruc (
        i_numero  in varchar2
    ) return varchar2;

end erp_gen_persona_api;
/
