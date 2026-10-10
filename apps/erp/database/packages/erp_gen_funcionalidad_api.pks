create or replace package erp_gen_funcionalidad_api
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_funcionalidad_api   (capa api)
-- Desc    : Funcionalidades activables por empresa: adaptan el ERP al rubro sin
--           tocar código (docs/arquitectura-erp.md §3.5).
--   Condición APEX: erp_gen_funcionalidad_api.es_activa_sn('LOTE', :APP_EMPRESA_ID) = 'S'
-- =============================================================================

    -- 'S' si la funcionalidad está activa (catálogo y empresa) para la empresa.
    function es_activa_sn (
        i_codigo      in varchar2,
        i_empresa_id  in number
    ) return varchar2;

    -- Activa en la empresa las funcionalidades de su rubro (erp_gen_empresa_config.rubro_id).
    -- No desactiva las que ya tenga: solo agrega.
    procedure crear_desde_rubro (
        i_empresa_id  in number
    );

end erp_gen_funcionalidad_api;
/
