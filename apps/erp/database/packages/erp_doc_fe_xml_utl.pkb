create or replace package body erp_doc_fe_xml_utl
as

    function limpiar_valor (
        i_valor  in varchar2
    ) return varchar2 is
    begin
        -- tabuladores, saltos de línea y demás caracteres de control pasan a un espacio
        return trim(regexp_replace(i_valor, '[[:cntrl:]]+', ' '));
    end limpiar_valor;

    function escapar_texto (
        i_valor  in varchar2
    ) return varchar2 is
    begin
        -- el & primero, para no volver a escapar las entidades generadas
        return replace(replace(replace(i_valor, '&', '&' || 'amp;'), '<', '&' || 'lt;'), '>', '&' || 'gt;');
    end escapar_texto;

    function escapar_atributo (
        i_valor  in varchar2
    ) return varchar2 is
    begin
        return replace(replace(replace(i_valor, '&', '&' || 'amp;'), '<', '&' || 'lt;'), '"', '&' || 'quot;');
    end escapar_atributo;

    function formatear_numero (
        i_valor         in number,
        i_decimales_max in pls_integer default 8
    ) return varchar2 is
        v_texto  varchar2(60);
    begin
        if i_valor is null then
            return null;
        end if;
        v_texto := to_char(round(i_valor, i_decimales_max), 'FM99999999999999999990D99999999', 'nls_numeric_characters=''.,''');
        return rtrim(v_texto, '.');
    end formatear_numero;

    function formatear_fecha (
        i_fecha  in date
    ) return varchar2 is
    begin
        return to_char(i_fecha, 'YYYY-MM-DD');
    end formatear_fecha;

    function formatear_fecha_hora (
        i_fecha  in timestamp
    ) return varchar2 is
    begin
        return to_char(i_fecha, 'YYYY-MM-DD"T"HH24:MI:SS');
    end formatear_fecha_hora;

    procedure agregar (
        io_xml   in out nocopy clob,
        i_texto  in varchar2
    ) is
    begin
        if i_texto is not null then
            dbms_lob.writeappend(io_xml, length(i_texto), i_texto);
        end if;
    end agregar;

    procedure agregar_elemento (
        io_xml    in out nocopy clob,
        i_nombre  in varchar2,
        i_valor   in varchar2
    ) is
        v_valor  varchar2(32767) := limpiar_valor(i_valor => i_valor);
    begin
        if v_valor is not null then
            agregar(io_xml  => io_xml,
                    i_texto => '<' || i_nombre || '>' || escapar_texto(i_valor => v_valor) || '</' || i_nombre || '>');
        end if;
    end agregar_elemento;

    function convertir_a_utf8 (
        i_xml  in clob
    ) return blob is
        v_blob          blob;
        v_destino       integer := 1;
        v_origen        integer := 1;
        v_contexto      integer := dbms_lob.default_lang_ctx;
        v_advertencia   integer;
    begin
        dbms_lob.createtemporary(v_blob, true, dbms_lob.call);
        if i_xml is not null and dbms_lob.getlength(i_xml) > 0 then
            dbms_lob.converttoblob(dest_lob     => v_blob,
                                   src_clob     => i_xml,
                                   amount       => dbms_lob.lobmaxsize,
                                   dest_offset  => v_destino,
                                   src_offset   => v_origen,
                                   blob_csid    => nls_charset_id('AL32UTF8'),
                                   lang_context => v_contexto,
                                   warning      => v_advertencia);
        end if;
        return v_blob;
    end convertir_a_utf8;

    function codificar_base64 (
        i_datos  in raw
    ) return varchar2 is
        c_bloque   constant pls_integer := 12000;   -- múltiplo de 3: los bloques se concatenan sin relleno intermedio
        v_salida   varchar2(32767);
        v_pos      pls_integer := 1;
        v_largo    pls_integer := coalesce(utl_raw.length(i_datos), 0);
    begin
        while v_pos <= v_largo loop
            v_salida := v_salida
                        || replace(replace(utl_raw.cast_to_varchar2(
                               utl_encode.base64_encode(utl_raw.substr(i_datos, v_pos, least(c_bloque, v_largo - v_pos + 1)))),
                               chr(13)), chr(10));
            v_pos := v_pos + c_bloque;
        end loop;
        return v_salida;
    end codificar_base64;

    function codificar_base64 (
        i_datos  in blob
    ) return clob is
        c_bloque   constant pls_integer := 12000;
        v_salida   clob;
        v_pos      integer := 1;
        v_largo    integer := coalesce(dbms_lob.getlength(i_datos), 0);
    begin
        dbms_lob.createtemporary(v_salida, true, dbms_lob.call);
        while v_pos <= v_largo loop
            agregar(io_xml  => v_salida,
                    i_texto => codificar_base64(i_datos => dbms_lob.substr(i_datos, c_bloque, v_pos)));
            v_pos := v_pos + c_bloque;
        end loop;
        return v_salida;
    end codificar_base64;

    function decodificar_base64 (
        i_texto  in varchar2
    ) return raw is
        c_bloque   constant pls_integer := 16000;   -- múltiplo de 4
        v_texto    varchar2(32767) := regexp_replace(i_texto, '[[:space:]]');
        v_salida   raw(32767);
        v_pos      pls_integer := 1;
    begin
        while v_pos <= length(v_texto) loop
            v_salida := utl_raw.concat(v_salida,
                                       utl_encode.base64_decode(utl_raw.cast_to_raw(substr(v_texto, v_pos, c_bloque))));
            v_pos := v_pos + c_bloque;
        end loop;
        return v_salida;
    end decodificar_base64;

    function convertir_a_hex (
        i_texto  in varchar2
    ) return varchar2 is
    begin
        return lower(rawtohex(utl_i18n.string_to_raw(i_texto, 'AL32UTF8')));
    end convertir_a_hex;

    function es_bien_formado_sn (
        i_xml  in clob
    ) return varchar2 is
        v_xml  xmltype;
    begin
        v_xml := xmltype(i_xml);
        return case when v_xml is not null then 'S' else 'N' end;
    exception
        when others then
            -- cualquier error del analizador significa que el documento no está bien formado
            return 'N';
    end es_bien_formado_sn;

end erp_doc_fe_xml_utl;
/
