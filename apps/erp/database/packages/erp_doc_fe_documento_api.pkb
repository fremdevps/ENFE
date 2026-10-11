create or replace package body erp_doc_fe_documento_api
as

    c_si                  constant varchar2(1)  := 'S';
    c_estado_activo       constant varchar2(1)  := 'A';
    c_emision_electronica constant varchar2(1)  := 'E';
    c_zona_defecto        constant varchar2(30) := 'America/Asuncion';

    procedure emitir (
        i_empresa_id         in  number,
        i_origen_modulo      in  varchar2,
        i_origen_tipo        in  varchar2,
        i_origen_id          in  number,
        i_tipo_documento_id  in  number,
        i_datos              in  clob,
        i_frase              in  varchar2,
        i_numerador_id       in  number default null,
        o_fe_documento_id    out number,
        o_cdc                out varchar2
    ) is
        r_config        erp_doc_fe_config%rowtype := erp_doc_fe_config_ctr.obtener(i_empresa_id => i_empresa_id);
        r_certificado   erp_doc_fe_certificado%rowtype;
        r_de            erp_doc_fe_de_reg.t_de;
        r_documento     erp_doc_fe_documento%rowtype;
        v_tipo_emision  erp_doc_tipo_documento.tipo_emision%type;
        v_codigo_sifen  erp_doc_tipo_documento.codigo_sifen%type;
        v_zona          varchar2(64);
        v_ahora         timestamp;
        v_ahora_utc     timestamp := sys_extract_utc(systimestamp);
    begin
        if r_config.fe_config_id is null or r_config.estado <> c_estado_activo then
            raise_application_error(c_err_config, 'La empresa no tiene activa la facturación electrónica.');
        end if;
        if r_config.fe_certificado_id is null or r_config.id_csc is null or r_config.csc_cifrado is null then
            raise_application_error(c_err_config, 'Faltan el certificado digital o el CSC en la configuración de facturación electrónica.');
        end if;
        r_certificado := erp_doc_fe_certificado_ctr.obtener(i_fe_certificado_id => r_config.fe_certificado_id);
        if r_certificado.estado <> c_estado_activo or v_ahora_utc not between r_certificado.fecha_desde and r_certificado.fecha_hasta then
            raise_application_error(erp_doc_fe_firma_utl.c_err_clave_invalida,
                'El certificado digital está inactivo o fuera de su período de validez ('
                || to_char(r_certificado.fecha_desde, 'DD/MM/YYYY') || ' al ' || to_char(r_certificado.fecha_hasta, 'DD/MM/YYYY') || ').');
        end if;
        -- el comportamiento sale de los atributos del tipo de documento, nunca de su código
        select max(tipo_emision), max(codigo_sifen)
          into v_tipo_emision, v_codigo_sifen
          from erp_doc_tipo_documento
         where tipo_documento_id = i_tipo_documento_id
           and empresa_id = i_empresa_id;
        if v_tipo_emision is null or v_tipo_emision <> c_emision_electronica then
            raise_application_error(c_err_config, 'El tipo de documento no es de emisión electrónica.');
        end if;

        -- fecha de la firma en la hora local de la empresa (la base puede estar en UTC)
        select coalesce(max(zona_horaria), c_zona_defecto) into v_zona from adm_gen_empresa where empresa_id = i_empresa_id;
        v_ahora := cast(systimestamp at time zone v_zona as timestamp);

        r_de := erp_doc_fe_de_reg.generar_de(i_datos            => i_datos,
                                             i_codigo_seguridad => null,
                                             i_fecha_firma      => v_ahora,
                                             i_version_formato  => r_config.version_formato);
        if r_de.tipo_de <> v_codigo_sifen then
            raise_application_error(erp_doc_fe_de_reg.c_err_dato_invalido,
                'Datos del documento electrónico: el tipo de DE (' || r_de.tipo_de || ') no coincide con el del tipo de documento ('
                || v_codigo_sifen || ').');
        end if;

        erp_doc_fe_de_reg.generar_rde(
            i_de              => r_de,
            i_clave_privada   => utl_raw.cast_to_varchar2(
                                     erp_doc_fe_secreto_utl.descifrar(i_cifrado => dbms_lob.substr(r_certificado.clave_privada_cifrada, 32767, 1),
                                                                      i_frase   => i_frase)),
            i_certificado     => dbms_lob.substr(r_certificado.certificado, 32767, 1),
            i_id_csc          => r_config.id_csc,
            i_csc             => utl_raw.cast_to_varchar2(erp_doc_fe_secreto_utl.descifrar(i_cifrado => r_config.csc_cifrado, i_frase => i_frase)),
            i_url_consulta_qr => coalesce(r_config.url_consulta_qr, erp_doc_fe_qr_utl.obtener_url_consulta(i_ambiente => r_config.ambiente)),
            i_declara_esquema => r_config.debe_declarar_esquema = c_si,
            o_xml             => r_documento.xml_firmado,
            o_resumen         => r_documento.digest_value,
            o_url_qr          => r_documento.url_qr);

        r_documento.empresa_id         := i_empresa_id;
        r_documento.origen_modulo      := i_origen_modulo;
        r_documento.origen_tipo        := i_origen_tipo;
        r_documento.origen_id          := i_origen_id;
        r_documento.tipo_documento_id  := i_tipo_documento_id;
        r_documento.numerador_id       := i_numerador_id;
        r_documento.fe_certificado_id  := r_certificado.fe_certificado_id;
        r_documento.tipo_de            := r_de.tipo_de;
        r_documento.timbrado           := r_de.timbrado;
        r_documento.establecimiento    := r_de.establecimiento;
        r_documento.punto_expedicion   := r_de.punto_expedicion;
        r_documento.numero             := r_de.numero;
        r_documento.serie              := r_de.serie;
        r_documento.tipo_emision       := r_de.tipo_emision;
        r_documento.cdc                := r_de.cdc;
        r_documento.codigo_seguridad   := r_de.codigo_seguridad;
        r_documento.version_formato    := r_de.version_formato;
        r_documento.ambiente           := r_config.ambiente;
        r_documento.fecha_emision      := r_de.fecha_emision;
        r_documento.fecha_firma        := r_de.fecha_firma;
        -- los plazos de la cola se llevan en la hora de la sesión de la base
        r_documento.fecha_limite_envio := localtimestamp + numtodsinterval(r_config.horas_limite_envio, 'HOUR');
        r_documento.receptor_documento := r_de.receptor_documento;
        r_documento.receptor_nombre    := r_de.receptor_nombre;
        r_documento.moneda             := r_de.moneda;
        r_documento.monto_total        := r_de.monto_total;
        r_documento.monto_impuesto     := r_de.monto_impuesto;
        r_documento.cantidad_items     := r_de.cantidad_items;
        r_documento.datos              := i_datos;
        r_documento.estado_envio       := erp_doc_fe_cola_reg.c_envio_pendiente;
        r_documento.estado_sifen       := erp_doc_fe_cola_reg.c_sifen_sin_resultado;
        r_documento.proximo_intento    := localtimestamp;
        begin
            erp_doc_fe_documento_ctr.insertar(i_registro => r_documento, o_fe_documento_id => o_fe_documento_id);
        exception
            when dup_val_on_index then
                raise_application_error(c_err_duplicado,
                    'Ya existe un documento electrónico para ese documento de origen o con ese código de control.', true);
        end;
        o_cdc := r_de.cdc;
    end emitir;

    function obtener_error_firma (
        i_fe_documento_id  in number
    ) return varchar2 is
        r_documento    erp_doc_fe_documento%rowtype := erp_doc_fe_documento_ctr.obtener(i_fe_documento_id => i_fe_documento_id);
        r_certificado  erp_doc_fe_certificado%rowtype;
    begin
        if r_documento.fe_documento_id is null then
            return 'El documento electrónico no existe.';
        end if;
        r_certificado := erp_doc_fe_certificado_ctr.obtener(i_fe_certificado_id => r_documento.fe_certificado_id);
        return erp_doc_fe_de_reg.obtener_error_firma(i_xml => r_documento.xml_firmado, i_clave_publica => r_certificado.clave_publica);
    end obtener_error_firma;

end erp_doc_fe_documento_api;
/
