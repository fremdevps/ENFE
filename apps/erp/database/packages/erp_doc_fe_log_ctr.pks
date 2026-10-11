create or replace package erp_doc_fe_log_ctr
    authid definer
    accessible by (package erp_doc_fe_cola_api)
as
-- =============================================================================
-- Paquete : erp_doc_fe_log_ctr   (capa ctr)
-- Tabla   : erp_doc_fe_log
-- Desc    : Inserta en la bitácora en TRANSACCIÓN AUTÓNOMA (excepción del estándar para
--           bitácoras): el intercambio queda registrado aunque el envío se deshaga.
-- =============================================================================

    procedure insertar (
        i_registro   in  erp_doc_fe_log%rowtype,
        o_fe_log_id  out erp_doc_fe_log.fe_log_id%type
    );

end erp_doc_fe_log_ctr;
/
