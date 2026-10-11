create or replace package body erp_doc_fe_config_ctr
as

    function obtener (
        i_empresa_id  in erp_doc_fe_config.empresa_id%type
    ) return erp_doc_fe_config%rowtype is
        r_config  erp_doc_fe_config%rowtype;
    begin
        select *
          into r_config
          from erp_doc_fe_config
         where empresa_id = i_empresa_id;
        return r_config;
    exception
        when no_data_found then
            return r_config;
    end obtener;

    procedure insertar (
        i_empresa_id  in erp_doc_fe_config.empresa_id%type
    ) is
    begin
        merge into erp_doc_fe_config t
        using (select i_empresa_id empresa_id from dual) s
           on (t.empresa_id = s.empresa_id)
         when not matched then
            insert (empresa_id) values (s.empresa_id);
    end insertar;

    procedure actualizar_csc (
        i_empresa_id   in erp_doc_fe_config.empresa_id%type,
        i_id_csc       in erp_doc_fe_config.id_csc%type,
        i_csc_cifrado  in erp_doc_fe_config.csc_cifrado%type
    ) is
    begin
        update erp_doc_fe_config
           set id_csc      = i_id_csc,
               csc_cifrado = i_csc_cifrado
         where empresa_id = i_empresa_id;
    end actualizar_csc;

    procedure actualizar_certificado (
        i_empresa_id         in erp_doc_fe_config.empresa_id%type,
        i_fe_certificado_id  in erp_doc_fe_config.fe_certificado_id%type
    ) is
    begin
        update erp_doc_fe_config
           set fe_certificado_id = i_fe_certificado_id
         where empresa_id = i_empresa_id;
    end actualizar_certificado;

end erp_doc_fe_config_ctr;
/
