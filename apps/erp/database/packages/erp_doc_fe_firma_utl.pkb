create or replace package body erp_doc_fe_firma_utl
as

    -- Elemento DER (ASN.1): posición y largo de su contenido dentro del certificado.
    type t_der is record (
        etiqueta   pls_integer,
        inicio     pls_integer,   -- primer byte del elemento (la etiqueta)
        contenido  pls_integer,   -- primer byte del contenido
        largo      pls_integer    -- bytes del contenido
    );

    function limpiar_pem (
        i_pem  in clob
    ) return varchar2 is
        v_texto  varchar2(32767) := dbms_lob.substr(i_pem, 32767, 1);
    begin
        v_texto := regexp_replace(v_texto, '-----[^-]+-----');
        return regexp_replace(v_texto, '[[:space:]]');
    end limpiar_pem;

    function calcular_resumen (
        i_xml_canonico  in clob
    ) return varchar2 is
    begin
        return erp_doc_fe_xml_utl.codificar_base64(
                   i_datos => dbms_crypto.hash(src => erp_doc_fe_xml_utl.convertir_a_utf8(i_xml => i_xml_canonico),
                                               typ => dbms_crypto.hash_sh256));
    end calcular_resumen;

    function generar_signed_info (
        i_id             in varchar2,
        i_resumen        in varchar2,
        i_es_canonico    in boolean,
        i_declara_xsi    in boolean
    ) return varchar2 is
        v_namespaces  varchar2(200);
    begin
        if i_es_canonico then
            -- C14N inclusiva: el elemento raíz del subconjunto lleva todos los namespaces en
            -- alcance (primero el por defecto, después los prefijos en orden alfabético).
            v_namespaces := ' xmlns="' || erp_doc_fe_xml_utl.c_ns_dsig || '"'
                            || case when i_declara_xsi then ' xmlns:xsi="' || erp_doc_fe_xml_utl.c_ns_xsi || '"' end;
        end if;
        return '<SignedInfo' || v_namespaces || '>'
               || '<CanonicalizationMethod Algorithm="' || c_alg_canonico || '"></CanonicalizationMethod>'
               || '<SignatureMethod Algorithm="' || c_alg_firma || '"></SignatureMethod>'
               || '<Reference URI="#' || erp_doc_fe_xml_utl.escapar_atributo(i_valor => i_id) || '">'
               || '<Transforms>'
               || '<Transform Algorithm="' || c_alg_envuelta || '"></Transform>'
               || '<Transform Algorithm="' || c_alg_exclusivo || '"></Transform>'
               || '</Transforms>'
               || '<DigestMethod Algorithm="' || c_alg_resumen || '"></DigestMethod>'
               || '<DigestValue>' || i_resumen || '</DigestValue>'
               || '</Reference>'
               || '</SignedInfo>';
    end generar_signed_info;

    function firmar (
        i_texto          in varchar2,
        i_clave_privada  in varchar2
    ) return varchar2 is
    begin
        if i_clave_privada is null then
            raise_application_error(c_err_clave_invalida, 'Falta la clave privada para firmar.');
        end if;
        return erp_doc_fe_xml_utl.codificar_base64(
                   i_datos => dbms_crypto.sign(src        => utl_i18n.string_to_raw(i_texto, 'AL32UTF8'),
                                               prv_key    => utl_raw.cast_to_raw(i_clave_privada),
                                               pubkey_alg => dbms_crypto.key_type_rsa,
                                               sign_alg   => dbms_crypto.sign_sha256_rsa));
    exception
        when others then
            if sqlcode = c_err_clave_invalida then
                raise;
            end if;
            -- ORA-28817 y similares: la clave no tiene el formato que acepta la base
            raise_application_error(c_err_clave_invalida,
                'No se pudo firmar: la clave privada no es válida (se espera RSA en Base64, PKCS#8 o PKCS#1).', true);
    end firmar;

    function es_firma_valida (
        i_texto          in varchar2,
        i_firma          in varchar2,
        i_clave_publica  in varchar2
    ) return boolean is
    begin
        if i_texto is null or i_firma is null or i_clave_publica is null then
            return false;
        end if;
        return dbms_crypto.verify(src        => utl_i18n.string_to_raw(i_texto, 'AL32UTF8'),
                                  sign       => erp_doc_fe_xml_utl.decodificar_base64(i_texto => i_firma),
                                  pub_key    => utl_raw.cast_to_raw(i_clave_publica),
                                  pubkey_alg => dbms_crypto.key_type_rsa,
                                  sign_alg   => dbms_crypto.sign_sha256_rsa);
    exception
        when others then
            -- una firma o clave mal formada no es una firma válida
            return false;
    end es_firma_valida;

    function generar_firma (
        i_id             in varchar2,
        i_resumen        in varchar2,
        i_clave_privada  in varchar2,
        i_certificado    in varchar2,
        i_declara_xsi    in boolean
    ) return varchar2 is
    begin
        return '<Signature xmlns="' || erp_doc_fe_xml_utl.c_ns_dsig || '">'
               || generar_signed_info(i_id => i_id, i_resumen => i_resumen, i_es_canonico => false, i_declara_xsi => i_declara_xsi)
               || '<SignatureValue>'
               || firmar(i_texto         => generar_signed_info(i_id => i_id, i_resumen => i_resumen,
                                                                i_es_canonico => true, i_declara_xsi => i_declara_xsi),
                         i_clave_privada => i_clave_privada)
               || '</SignatureValue>'
               || '<KeyInfo><X509Data><X509Certificate>' || i_certificado || '</X509Certificate></X509Data></KeyInfo>'
               || '</Signature>';
    end generar_firma;

    -- Lee la cabecera (etiqueta y largo) del elemento DER que empieza en i_posicion.
    function leer_der (
        i_datos     in raw,
        i_posicion  in pls_integer
    ) return t_der is
        r_der     t_der;
        v_byte    pls_integer;
        v_bytes   pls_integer;
    begin
        if i_posicion + 1 > utl_raw.length(i_datos) then
            raise_application_error(c_err_clave_invalida, 'El certificado no es un X.509 válido.');
        end if;
        r_der.inicio   := i_posicion;
        r_der.etiqueta := to_number(rawtohex(utl_raw.substr(i_datos, i_posicion, 1)), 'XX');
        v_byte         := to_number(rawtohex(utl_raw.substr(i_datos, i_posicion + 1, 1)), 'XX');
        if v_byte < 128 then
            r_der.largo     := v_byte;
            r_der.contenido := i_posicion + 2;
        else
            v_bytes         := v_byte - 128;
            if v_bytes not between 1 and 3 then
                raise_application_error(c_err_clave_invalida, 'El certificado no es un X.509 válido.');
            end if;
            r_der.largo     := to_number(rawtohex(utl_raw.substr(i_datos, i_posicion + 2, v_bytes)), 'XXXXXX');
            r_der.contenido := i_posicion + 2 + v_bytes;
        end if;
        if r_der.contenido + r_der.largo - 1 > utl_raw.length(i_datos) then
            raise_application_error(c_err_clave_invalida, 'El certificado no es un X.509 válido.');
        end if;
        return r_der;
    end leer_der;

    -- Ubica un campo de TBSCertificate. Orden (RFC 5280): [0] versión (opcional), número de
    -- serie, algoritmo, emisor, validez, sujeto, clave pública.
    function ubicar_campo (
        i_datos   in raw,
        i_numero  in pls_integer      -- 4 = validez, 6 = clave pública
    ) return t_der is
        r_der  t_der;
        v_pos  pls_integer;
    begin
        if i_datos is null then
            raise_application_error(c_err_clave_invalida, 'Falta el certificado.');
        end if;
        r_der := leer_der(i_datos => i_datos, i_posicion => 1);                -- Certificate
        r_der := leer_der(i_datos => i_datos, i_posicion => r_der.contenido);  -- TBSCertificate
        v_pos := r_der.contenido;
        r_der := leer_der(i_datos => i_datos, i_posicion => v_pos);
        if r_der.etiqueta = 160 then                                           -- [0] versión
            v_pos := r_der.contenido + r_der.largo;
            r_der := leer_der(i_datos => i_datos, i_posicion => v_pos);
        end if;
        for v_i in 2 .. i_numero loop
            v_pos := r_der.contenido + r_der.largo;
            r_der := leer_der(i_datos => i_datos, i_posicion => v_pos);
        end loop;
        if r_der.etiqueta <> 48 then                                           -- SEQUENCE
            raise_application_error(c_err_clave_invalida, 'El certificado no es un X.509 válido.');
        end if;
        return r_der;
    end ubicar_campo;

    function decodificar_certificado (
        i_certificado  in varchar2
    ) return raw is
    begin
        return erp_doc_fe_xml_utl.decodificar_base64(i_texto => i_certificado);
    exception
        when others then
            raise_application_error(c_err_clave_invalida, 'El certificado no está en Base64.', true);
    end decodificar_certificado;

    function extraer_clave_publica (
        i_certificado  in varchar2
    ) return varchar2 is
        v_datos  raw(32767) := decodificar_certificado(i_certificado => i_certificado);
        r_der    t_der;
    begin
        r_der := ubicar_campo(i_datos => v_datos, i_numero => 6);
        return erp_doc_fe_xml_utl.codificar_base64(
                   i_datos => utl_raw.substr(v_datos, r_der.inicio, r_der.contenido - r_der.inicio + r_der.largo));
    end extraer_clave_publica;

    -- UTCTime (AAMMDDhhmmssZ) o GeneralizedTime (AAAAMMDDhhmmssZ).
    function convertir_fecha_der (
        i_datos  in raw,
        i_der    in t_der
    ) return timestamp is
        v_texto  varchar2(30) := utl_raw.cast_to_varchar2(utl_raw.substr(i_datos, i_der.contenido, i_der.largo));
    begin
        if i_der.etiqueta = 23 then
            return to_timestamp(substr(v_texto, 1, 12), 'RRMMDDHH24MISS');
        end if;
        return to_timestamp(substr(v_texto, 1, 14), 'YYYYMMDDHH24MISS');
    end convertir_fecha_der;

    procedure extraer_vigencia (
        i_certificado  in  varchar2,
        o_fecha_desde  out timestamp,
        o_fecha_hasta  out timestamp
    ) is
        v_datos    raw(32767) := decodificar_certificado(i_certificado => i_certificado);
        r_validez  t_der;
        r_fecha    t_der;
    begin
        r_validez     := ubicar_campo(i_datos => v_datos, i_numero => 4);
        r_fecha       := leer_der(i_datos => v_datos, i_posicion => r_validez.contenido);
        o_fecha_desde := convertir_fecha_der(i_datos => v_datos, i_der => r_fecha);
        r_fecha       := leer_der(i_datos => v_datos, i_posicion => r_fecha.contenido + r_fecha.largo);
        o_fecha_hasta := convertir_fecha_der(i_datos => v_datos, i_der => r_fecha);
    end extraer_vigencia;

    function calcular_huella (
        i_certificado  in varchar2
    ) return varchar2 is
    begin
        return lower(rawtohex(dbms_crypto.hash(src => decodificar_certificado(i_certificado => i_certificado),
                                               typ => dbms_crypto.hash_sh256)));
    end calcular_huella;

end erp_doc_fe_firma_utl;
/
