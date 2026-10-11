create or replace package body erp_doc_fe_certificado_ctr
as

    procedure insertar (
        i_registro           in  erp_doc_fe_certificado%rowtype,
        o_fe_certificado_id  out erp_doc_fe_certificado.fe_certificado_id%type
    ) is
    begin
        insert into erp_doc_fe_certificado
               (empresa_id, nombre, certificado, clave_publica, clave_privada_cifrada, huella_sha256,
                fecha_desde, fecha_hasta, es_prueba)
        values (i_registro.empresa_id, i_registro.nombre, i_registro.certificado, i_registro.clave_publica,
                i_registro.clave_privada_cifrada, i_registro.huella_sha256,
                i_registro.fecha_desde, i_registro.fecha_hasta, i_registro.es_prueba)
        returning fe_certificado_id into o_fe_certificado_id;
    end insertar;

    function obtener (
        i_fe_certificado_id  in erp_doc_fe_certificado.fe_certificado_id%type
    ) return erp_doc_fe_certificado%rowtype is
        r_certificado  erp_doc_fe_certificado%rowtype;
    begin
        select *
          into r_certificado
          from erp_doc_fe_certificado
         where fe_certificado_id = i_fe_certificado_id;
        return r_certificado;
    exception
        when no_data_found then
            return r_certificado;
    end obtener;

end erp_doc_fe_certificado_ctr;
/
