create or replace package body erp_doc_numero_inutilizado_ctr
as

    procedure insertar (
        i_empresa_id             in  erp_doc_numero_inutilizado.empresa_id%type,
        i_numerador_id           in  erp_doc_numero_inutilizado.numerador_id%type,
        i_numero_desde           in  erp_doc_numero_inutilizado.numero_desde%type,
        i_numero_hasta           in  erp_doc_numero_inutilizado.numero_hasta%type,
        i_tipo                   in  erp_doc_numero_inutilizado.tipo%type,
        i_motivo_id              in  erp_doc_numero_inutilizado.motivo_id%type,
        i_motivo                 in  erp_doc_numero_inutilizado.motivo%type,
        i_fecha                  in  erp_doc_numero_inutilizado.fecha%type,
        o_numero_inutilizado_id  out erp_doc_numero_inutilizado.numero_inutilizado_id%type
    ) is
    begin
        insert into erp_doc_numero_inutilizado
               (empresa_id, numerador_id, numero_desde, numero_hasta, tipo, motivo_id, motivo, fecha)
        values (i_empresa_id, i_numerador_id, i_numero_desde, i_numero_hasta, i_tipo, i_motivo_id, trim(i_motivo), i_fecha)
        returning numero_inutilizado_id into o_numero_inutilizado_id;
    end insertar;

    function existe_solapado (
        i_numerador_id  in erp_doc_numero_inutilizado.numerador_id%type,
        i_numero_desde  in erp_doc_numero_inutilizado.numero_desde%type,
        i_numero_hasta  in erp_doc_numero_inutilizado.numero_hasta%type
    ) return boolean is
        v_cantidad  pls_integer;
    begin
        select count(*)
          into v_cantidad
          from erp_doc_numero_inutilizado
         where numerador_id  = i_numerador_id
           and numero_desde <= i_numero_hasta
           and numero_hasta >= i_numero_desde;
        return v_cantidad > 0;
    end existe_solapado;

    function obtener_fin_rango (
        i_numerador_id  in erp_doc_numero_inutilizado.numerador_id%type,
        i_numero        in erp_doc_numero_inutilizado.numero_desde%type
    ) return erp_doc_numero_inutilizado.numero_hasta%type is
        v_numero_hasta  erp_doc_numero_inutilizado.numero_hasta%type;
    begin
        select max(numero_hasta)
          into v_numero_hasta
          from erp_doc_numero_inutilizado
         where numerador_id = i_numerador_id
           and i_numero between numero_desde and numero_hasta;
        return v_numero_hasta;
    end obtener_fin_rango;

end erp_doc_numero_inutilizado_ctr;
/
