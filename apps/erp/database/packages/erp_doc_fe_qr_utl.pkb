create or replace package body erp_doc_fe_qr_utl
as

    function obtener_url_consulta (
        i_ambiente  in varchar2
    ) return varchar2 is
    begin
        return case when i_ambiente = 'P' then c_url_produccion else c_url_test end;
    end obtener_url_consulta;

    function generar_datos (
        i_version           in varchar2,
        i_cdc               in varchar2,
        i_fecha_emision     in timestamp,
        i_receptor          in varchar2,
        i_es_contribuyente  in boolean,
        i_total             in number,
        i_total_iva         in number,
        i_cantidad_items    in number,
        i_resumen           in varchar2,
        i_id_csc            in varchar2
    ) return varchar2 is
    begin
        if erp_doc_fe_cdc_utl.es_valido_sn(i_cdc => i_cdc) <> 'S' then
            raise_application_error(c_err_dato_invalido, 'No se puede generar el QR: el código de control no es válido.');
        end if;
        if i_version is null or i_fecha_emision is null or i_resumen is null
           or i_id_csc is null or not regexp_like(i_id_csc, '^[0-9]{1,4}$') then
            raise_application_error(c_err_dato_invalido,
                'No se puede generar el QR: faltan la versión, la fecha de emisión, el resumen de la firma o el identificador del CSC.');
        end if;
        -- los campos sin valor se completan con 0 (nota (*) de la tabla de parámetros, pág. 206)
        return 'nVersion=' || i_version
               || '&' || 'Id=' || i_cdc
               || '&' || 'dFeEmiDE=' || erp_doc_fe_xml_utl.convertir_a_hex(
                                            i_texto => erp_doc_fe_xml_utl.formatear_fecha_hora(i_fecha => i_fecha_emision))
               || '&' || case when i_es_contribuyente then 'dRucRec=' else 'dNumIDRec=' end || coalesce(trim(i_receptor), '0')
               || '&' || 'dTotGralOpe=' || coalesce(erp_doc_fe_xml_utl.formatear_numero(i_valor => i_total), '0')
               || '&' || 'dTotIVA=' || coalesce(erp_doc_fe_xml_utl.formatear_numero(i_valor => i_total_iva), '0')
               || '&' || 'cItems=' || coalesce(to_char(i_cantidad_items), '0')
               || '&' || 'DigestValue=' || erp_doc_fe_xml_utl.convertir_a_hex(i_texto => i_resumen)
               || '&' || 'IdCSC=' || lpad(i_id_csc, 4, '0');
    end generar_datos;

    function calcular_hash (
        i_datos  in varchar2,
        i_csc    in varchar2
    ) return varchar2 is
    begin
        if i_csc is null then
            raise_application_error(c_err_dato_invalido, 'No se puede generar el QR: falta el código de seguridad del contribuyente (CSC).');
        end if;
        return lower(rawtohex(dbms_crypto.hash(src => utl_i18n.string_to_raw(i_datos || i_csc, 'AL32UTF8'),
                                               typ => dbms_crypto.hash_sh256)));
    end calcular_hash;

    function generar_url (
        i_url_consulta      in varchar2,
        i_version           in varchar2,
        i_cdc               in varchar2,
        i_fecha_emision     in timestamp,
        i_receptor          in varchar2,
        i_es_contribuyente  in boolean,
        i_total             in number,
        i_total_iva         in number,
        i_cantidad_items    in number,
        i_resumen           in varchar2,
        i_id_csc            in varchar2,
        i_csc               in varchar2
    ) return varchar2 is
        v_datos  varchar2(2000);
    begin
        v_datos := generar_datos(i_version          => i_version,
                                 i_cdc              => i_cdc,
                                 i_fecha_emision    => i_fecha_emision,
                                 i_receptor         => i_receptor,
                                 i_es_contribuyente => i_es_contribuyente,
                                 i_total            => i_total,
                                 i_total_iva        => i_total_iva,
                                 i_cantidad_items   => i_cantidad_items,
                                 i_resumen          => i_resumen,
                                 i_id_csc           => i_id_csc);
        return i_url_consulta || v_datos || '&' || 'cHashQR=' || calcular_hash(i_datos => v_datos, i_csc => i_csc);
    end generar_url;

end erp_doc_fe_qr_utl;
/
