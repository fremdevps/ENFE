create or replace package body erp_doc_fe_config_api
as

    c_si               constant varchar2(1) := 'S';
    c_estado_activo    constant varchar2(1) := 'A';
    c_ambiente_test    constant varchar2(1) := 'T';
    c_persona_fisica   constant varchar2(1) := 'F';
    c_texto_prueba     constant varchar2(40) := 'comprobación de clave y certificado';

    procedure validar_permiso (
        i_empresa_id  in number
    ) is
        v_usuario  varchar2(255) := sys_context('APEX$SESSION', 'APP_USER');
    begin
        if v_usuario is null then
            return;
        end if;
        if not adm_seg_seguridad_reg.tiene_permiso(i_username       => v_usuario,
                                                   i_permiso_codigo => c_permiso_configurar,
                                                   i_empresa_id     => i_empresa_id) then
            raise_application_error(c_err_sin_permiso, 'No tiene permiso para configurar la facturación electrónica.');
        end if;
    end validar_permiso;

    procedure registrar_certificado (
        i_empresa_id         in  number,
        i_nombre             in  varchar2,
        i_certificado        in  clob,
        i_clave_privada      in  clob,
        i_frase              in  varchar2,
        i_es_prueba          in  varchar2 default 'N',
        i_debe_asignar       in  varchar2 default 'S',
        o_fe_certificado_id  out number
    ) is
        r_certificado  erp_doc_fe_certificado%rowtype;
        v_certificado  varchar2(32767) := erp_doc_fe_firma_utl.limpiar_pem(i_pem => i_certificado);
        v_clave        varchar2(32767) := erp_doc_fe_firma_utl.limpiar_pem(i_pem => i_clave_privada);
    begin
        validar_permiso(i_empresa_id => i_empresa_id);
        if v_certificado is null or v_clave is null or i_nombre is null then
            raise_application_error(c_err_config, 'Indique el nombre, el certificado y la clave privada.');
        end if;
        r_certificado.empresa_id    := i_empresa_id;
        r_certificado.nombre        := i_nombre;
        r_certificado.certificado   := v_certificado;
        r_certificado.clave_publica := erp_doc_fe_firma_utl.extraer_clave_publica(i_certificado => v_certificado);
        r_certificado.huella_sha256 := erp_doc_fe_firma_utl.calcular_huella(i_certificado => v_certificado);
        r_certificado.es_prueba     := coalesce(i_es_prueba, 'N');
        erp_doc_fe_firma_utl.extraer_vigencia(i_certificado => v_certificado,
                                              o_fecha_desde => r_certificado.fecha_desde,
                                              o_fecha_hasta => r_certificado.fecha_hasta);
        -- la clave privada debe ser la del certificado: se firma un texto y se verifica con su clave pública
        if not erp_doc_fe_firma_utl.es_firma_valida(
                   i_texto         => c_texto_prueba,
                   i_firma         => erp_doc_fe_firma_utl.firmar(i_texto => c_texto_prueba, i_clave_privada => v_clave),
                   i_clave_publica => r_certificado.clave_publica) then
            raise_application_error(erp_doc_fe_firma_utl.c_err_clave_invalida, 'La clave privada no corresponde al certificado.');
        end if;
        r_certificado.clave_privada_cifrada := erp_doc_fe_secreto_utl.cifrar(i_dato  => utl_raw.cast_to_raw(v_clave),
                                                                             i_frase => i_frase);
        erp_doc_fe_certificado_ctr.insertar(i_registro => r_certificado, o_fe_certificado_id => o_fe_certificado_id);
        if i_debe_asignar = c_si then
            erp_doc_fe_config_ctr.insertar(i_empresa_id => i_empresa_id);
            erp_doc_fe_config_ctr.actualizar_certificado(i_empresa_id => i_empresa_id, i_fe_certificado_id => o_fe_certificado_id);
        end if;
    end registrar_certificado;

    procedure asignar_csc (
        i_empresa_id  in number,
        i_id_csc      in varchar2,
        i_csc         in varchar2,
        i_frase       in varchar2
    ) is
    begin
        validar_permiso(i_empresa_id => i_empresa_id);
        if i_id_csc is null or not regexp_like(i_id_csc, '^[0-9]{1,4}$') or trim(i_csc) is null then
            raise_application_error(c_err_config, 'Indique el identificador (hasta 4 dígitos) y el valor del CSC.');
        end if;
        erp_doc_fe_config_ctr.insertar(i_empresa_id => i_empresa_id);
        erp_doc_fe_config_ctr.actualizar_csc(
            i_empresa_id  => i_empresa_id,
            i_id_csc      => i_id_csc,
            i_csc_cifrado => erp_doc_fe_secreto_utl.cifrar(i_dato => utl_raw.cast_to_raw(trim(i_csc)), i_frase => i_frase));
    end asignar_csc;

    -- {"codigo": …, "descripcion": …} de la ubicación del tipo pedido, subiendo desde la ciudad.
    function obtener_ubicacion (
        i_ubicacion_id  in number,
        i_tipo          in varchar2
    ) return json_object_t is
        v_objeto  json_object_t;
    begin
        for r in (select codigo_oficial, nombre
                    from erp_gen_ubicacion
                   where tipo = i_tipo
                   start with ubicacion_id = i_ubicacion_id
                 connect by ubicacion_id = prior ubicacion_id_padre
                   fetch first 1 row only) loop
            v_objeto := json_object_t();
            v_objeto.put('codigo', r.codigo_oficial);
            v_objeto.put('descripcion', r.nombre);
        end loop;
        return v_objeto;
    end obtener_ubicacion;

    function obtener_emisor (
        i_empresa_id           in number,
        i_punto_expedicion_id  in number
    ) return clob is
        r_config       erp_doc_fe_config%rowtype := erp_doc_fe_config_ctr.obtener(i_empresa_id => i_empresa_id);
        v_emisor       json_object_t := json_object_t();
        v_actividades  json_array_t := json_array_t();
        v_actividad    json_object_t;
        v_ubicacion    json_object_t;
        v_encontrado   boolean := false;
    begin
        if r_config.fe_config_id is null then
            raise_application_error(c_err_config, 'La empresa no tiene configurada la facturación electrónica.');
        end if;
        for r in (select e.razon_social, e.nro_documento, c.dv_ruc, c.tipo_contribuyente,
                         s.nombre sucursal, coalesce(s.direccion, c.direccion) direccion, s.numero_casa,
                         coalesce(s.ubicacion_id, c.ubicacion_id) ubicacion_id,
                         coalesce(s.telefono, c.telefono) telefono, coalesce(s.email, c.email) email
                    from erp_gen_punto_expedicion p
                    join erp_gen_sucursal s on s.sucursal_id = p.sucursal_id
                    join adm_gen_empresa e on e.empresa_id = s.empresa_id
                    join erp_gen_empresa_config c on c.empresa_id = e.empresa_id
                   where p.punto_expedicion_id = i_punto_expedicion_id
                     and s.empresa_id = i_empresa_id) loop
            v_encontrado := true;
            v_emisor.put('ruc', r.nro_documento);
            v_emisor.put('dv', r.dv_ruc);
            v_emisor.put('tipo_contribuyente', case when r.tipo_contribuyente = c_persona_fisica then 1 else 2 end);
            if r_config.tipo_regimen is not null then
                v_emisor.put('tipo_regimen', r_config.tipo_regimen);
            end if;
            v_emisor.put('razon_social', case when r_config.ambiente = c_ambiente_test then c_nombre_ambiente_prueba else r.razon_social end);
            v_emisor.put('nombre_fantasia', r_config.nombre_fantasia);
            v_emisor.put('direccion', r.direccion);
            v_emisor.put('numero_casa', coalesce(r.numero_casa, '0'));
            v_emisor.put('telefono', r.telefono);
            v_emisor.put('email', r.email);
            v_emisor.put('sucursal', substr(r.sucursal, 1, 30));
            v_ubicacion := obtener_ubicacion(i_ubicacion_id => r.ubicacion_id, i_tipo => 'DEP');
            if v_ubicacion is not null then v_emisor.put('departamento', v_ubicacion); end if;
            v_ubicacion := obtener_ubicacion(i_ubicacion_id => r.ubicacion_id, i_tipo => 'DIS');
            if v_ubicacion is not null then v_emisor.put('distrito', v_ubicacion); end if;
            v_ubicacion := obtener_ubicacion(i_ubicacion_id => r.ubicacion_id, i_tipo => 'CIU');
            if v_ubicacion is not null then v_emisor.put('ciudad', v_ubicacion); end if;
        end loop;
        if not v_encontrado then
            raise_application_error(c_err_config,
                'No se encontraron los datos del emisor: revise la configuración de la empresa y el punto de expedición.');
        end if;
        for r in (select codigo, descripcion
                    from erp_doc_fe_actividad
                   where empresa_id = i_empresa_id
                     and estado = c_estado_activo
                   order by orden, fe_actividad_id) loop
            v_actividad := json_object_t();
            v_actividad.put('codigo', r.codigo);
            v_actividad.put('descripcion', r.descripcion);
            v_actividades.append(v_actividad);
        end loop;
        v_emisor.put('actividades', v_actividades);
        return v_emisor.to_clob;
    end obtener_emisor;

end erp_doc_fe_config_api;
/
