create or replace package body erp_doc_fe_cola_reg
as

    c_estado_activo  constant varchar2(1) := 'A';

    -- Parámetros de la cola de la empresa (o los valores por defecto).
    type t_parametros is record (
        max_documentos_lote  pls_integer,
        max_intentos         pls_integer,
        minutos_reintento    pls_integer,
        horas_consulta_lote  pls_integer
    );

    function obtener_parametros (
        i_empresa_id  in number
    ) return t_parametros is
        r_parametros  t_parametros;
    begin
        select max_documentos_lote, max_intentos, minutos_reintento, horas_consulta_lote
          into r_parametros
          from erp_doc_fe_config
         where empresa_id = i_empresa_id;
        return r_parametros;
    exception
        when no_data_found then
            r_parametros.max_documentos_lote := c_max_documentos_lote;
            r_parametros.max_intentos        := c_max_intentos;
            r_parametros.minutos_reintento   := c_minutos_reintento;
            r_parametros.horas_consulta_lote := c_horas_consulta_lote;
            return r_parametros;
    end obtener_parametros;

    function es_transicion_valida (
        i_estado_desde  in varchar2,
        i_estado_hasta  in varchar2
    ) return boolean is
    begin
        return case i_estado_desde
            when c_envio_pendiente     then i_estado_hasta in (c_envio_en_lote, c_envio_enviado, c_envio_error)
            when c_envio_en_lote       then i_estado_hasta in (c_envio_enviado, c_envio_pendiente, c_envio_error, c_envio_concluido)
            when c_envio_enviado       then i_estado_hasta in (c_envio_concluido, c_envio_sin_respuesta, c_envio_error)
            when c_envio_sin_respuesta then i_estado_hasta in (c_envio_concluido, c_envio_pendiente, c_envio_error)
            when c_envio_error         then i_estado_hasta in (c_envio_en_lote, c_envio_enviado, c_envio_pendiente,
                                                               c_envio_detenido, c_envio_error)
            when c_envio_detenido      then i_estado_hasta in (c_envio_pendiente)
            else false                 -- concluido es final
        end;
    end es_transicion_valida;

    function calcular_espera (
        i_intentos       in number,
        i_minutos_base   in number
    ) return number is
    begin
        -- el exponente se acota para no desbordar con muchos intentos
        return least(coalesce(i_minutos_base, c_minutos_reintento) * power(2, least(greatest(coalesce(i_intentos, 1), 1), 20) - 1),
                     c_minutos_espera_max);
    end calcular_espera;

    function bloquear_documento (
        i_fe_documento_id  in number
    ) return erp_doc_fe_documento%rowtype is
        r_documento  erp_doc_fe_documento%rowtype := erp_doc_fe_documento_ctr.bloquear(i_fe_documento_id => i_fe_documento_id);
    begin
        if r_documento.fe_documento_id is null then
            raise_application_error(c_err_no_encontrado, 'El documento electrónico no existe.');
        end if;
        return r_documento;
    end bloquear_documento;

    procedure cambiar_estado (
        io_documento     in out nocopy erp_doc_fe_documento%rowtype,
        i_estado_hasta   in varchar2
    ) is
    begin
        if not es_transicion_valida(i_estado_desde => io_documento.estado_envio, i_estado_hasta => i_estado_hasta) then
            raise_application_error(c_err_transicion,
                'El documento electrónico ' || io_documento.cdc || ' no puede pasar del estado de envío '
                || io_documento.estado_envio || ' al ' || i_estado_hasta || '.');
        end if;
        io_documento.estado_envio := i_estado_hasta;
    end cambiar_estado;

    procedure encolar (
        i_fe_documento_id  in number
    ) is
        r_documento  erp_doc_fe_documento%rowtype := bloquear_documento(i_fe_documento_id => i_fe_documento_id);
    begin
        if r_documento.estado_envio = c_envio_pendiente then
            return;
        end if;
        if r_documento.estado_envio = c_envio_detenido then
            r_documento.intentos := 0;      -- revisado por una persona: empieza de nuevo
        end if;
        cambiar_estado(io_documento => r_documento, i_estado_hasta => c_envio_pendiente);
        r_documento.proximo_intento := localtimestamp;
        erp_doc_fe_documento_ctr.actualizar_ciclo(i_registro => r_documento);
    end encolar;

    function tomar_pendientes (
        i_empresa_id  in number,
        i_tipo_de     in number,
        i_cantidad    in number
    ) return sys.odcinumberlist is
        v_ids        sys.odcinumberlist;
        r_documento  erp_doc_fe_documento%rowtype;
    begin
        v_ids := erp_doc_fe_documento_ctr.bloquear_pendientes(i_empresa_id => i_empresa_id,
                                                              i_tipo_de    => i_tipo_de,
                                                              i_cantidad   => i_cantidad,
                                                              i_estado_1   => c_envio_pendiente,
                                                              i_estado_2   => c_envio_error);
        for v_i in 1 .. v_ids.count loop
            r_documento := erp_doc_fe_documento_ctr.obtener(i_fe_documento_id => v_ids(v_i));
            cambiar_estado(io_documento => r_documento, i_estado_hasta => c_envio_enviado);
            r_documento.fecha_envio := localtimestamp;
            erp_doc_fe_documento_ctr.actualizar_ciclo(i_registro => r_documento);
        end loop;
        return v_ids;
    end tomar_pendientes;

    procedure armar_lote (
        i_empresa_id  in  number,
        i_tipo_de     in  number,
        o_fe_lote_id  out number,
        o_cantidad    out number
    ) is
        r_parametros  t_parametros := obtener_parametros(i_empresa_id => i_empresa_id);
        r_documento   erp_doc_fe_documento%rowtype;
        r_lote        erp_doc_fe_lote%rowtype;
        v_tipo_de     number := i_tipo_de;
        v_ids         sys.odcinumberlist;
    begin
        o_cantidad := 0;
        if v_tipo_de is null then
            -- un lote lleva un solo tipo de DE: el del pendiente más urgente
            select max(tipo_de) keep (dense_rank first order by fecha_limite_envio, fe_documento_id)
              into v_tipo_de
              from erp_doc_fe_documento
             where empresa_id = i_empresa_id
               and estado_envio in (c_envio_pendiente, c_envio_error)
               and proximo_intento <= localtimestamp;
            if v_tipo_de is null then
                return;
            end if;
        end if;
        v_ids := erp_doc_fe_documento_ctr.bloquear_pendientes(i_empresa_id => i_empresa_id,
                                                              i_tipo_de    => v_tipo_de,
                                                              i_cantidad   => r_parametros.max_documentos_lote,
                                                              i_estado_1   => c_envio_pendiente,
                                                              i_estado_2   => c_envio_error);
        if v_ids.count = 0 then
            return;
        end if;
        erp_doc_fe_lote_ctr.insertar(i_empresa_id => i_empresa_id,
                                     i_tipo_de    => v_tipo_de,
                                     i_estado     => c_lote_pendiente,
                                     o_fe_lote_id => o_fe_lote_id);
        for v_i in 1 .. v_ids.count loop
            r_documento := erp_doc_fe_documento_ctr.obtener(i_fe_documento_id => v_ids(v_i));
            cambiar_estado(io_documento => r_documento, i_estado_hasta => c_envio_en_lote);
            r_documento.fe_lote_id := o_fe_lote_id;
            erp_doc_fe_documento_ctr.actualizar_ciclo(i_registro => r_documento);
            erp_doc_fe_lote_ctr.insertar_detalle(i_fe_lote_id => o_fe_lote_id, i_fe_documento_id => v_ids(v_i), i_orden => v_i);
        end loop;
        r_lote          := erp_doc_fe_lote_ctr.bloquear(i_fe_lote_id => o_fe_lote_id);
        r_lote.cantidad := v_ids.count;
        erp_doc_fe_lote_ctr.actualizar(i_registro => r_lote);
        o_cantidad := v_ids.count;
    end armar_lote;

    function generar_xml_lote (
        i_fe_lote_id  in number
    ) return clob is
        v_xml  clob;
    begin
        dbms_lob.createtemporary(v_xml, true, dbms_lob.session);
        erp_doc_fe_xml_utl.agregar(io_xml => v_xml, i_texto => '<rLoteDE>');
        for r in (select d.xml_firmado
                    from erp_doc_fe_lote_detalle ld
                    join erp_doc_fe_documento d on d.fe_documento_id = ld.fe_documento_id
                   where ld.fe_lote_id = i_fe_lote_id
                   order by ld.orden) loop
            dbms_lob.append(v_xml, r.xml_firmado);
        end loop;
        erp_doc_fe_xml_utl.agregar(io_xml => v_xml, i_texto => '</rLoteDE>');
        return v_xml;
    end generar_xml_lote;

    procedure registrar_error (
        i_fe_documento_id  in number,
        i_error            in varchar2
    ) is
        r_documento   erp_doc_fe_documento%rowtype := bloquear_documento(i_fe_documento_id => i_fe_documento_id);
        r_parametros  t_parametros := obtener_parametros(i_empresa_id => r_documento.empresa_id);
    begin
        cambiar_estado(io_documento => r_documento, i_estado_hasta => c_envio_error);
        r_documento.intentos     := r_documento.intentos + 1;
        r_documento.ultimo_error := substr(i_error, 1, 1000);
        if r_documento.intentos >= r_parametros.max_intentos then
            -- agotó los reintentos automáticos: queda para revisión y reencolado manual
            cambiar_estado(io_documento => r_documento, i_estado_hasta => c_envio_detenido);
            r_documento.proximo_intento := null;
        else
            r_documento.proximo_intento := localtimestamp
                + numtodsinterval(calcular_espera(i_intentos     => r_documento.intentos,
                                                  i_minutos_base => r_parametros.minutos_reintento), 'MINUTE');
        end if;
        erp_doc_fe_documento_ctr.actualizar_ciclo(i_registro => r_documento);
    end registrar_error;

    procedure registrar_envio_lote (
        i_fe_lote_id         in number,
        i_codigo_respuesta   in varchar2,
        i_mensaje_respuesta  in varchar2,
        i_numero_lote        in varchar2,
        i_tiempo_proceso     in number
    ) is
        r_lote        erp_doc_fe_lote%rowtype := erp_doc_fe_lote_ctr.bloquear(i_fe_lote_id => i_fe_lote_id);
        r_parametros  t_parametros;
        r_documento   erp_doc_fe_documento%rowtype;
    begin
        if r_lote.fe_lote_id is null then
            raise_application_error(c_err_lote, 'El lote no existe.');
        end if;
        if r_lote.estado <> c_lote_pendiente then
            raise_application_error(c_err_lote, 'El lote ' || i_fe_lote_id || ' ya fue enviado.');
        end if;
        if i_codigo_respuesta = c_cod_lote_recibido and i_numero_lote is null then
            raise_application_error(c_err_lote, 'Falta el número de lote devuelto por la recepción.');
        end if;
        r_parametros           := obtener_parametros(i_empresa_id => r_lote.empresa_id);
        r_lote.codigo_respuesta  := i_codigo_respuesta;
        r_lote.mensaje_respuesta := substr(i_mensaje_respuesta, 1, 255);
        r_lote.tiempo_proceso    := i_tiempo_proceso;
        r_lote.fecha_envio       := localtimestamp;
        r_lote.fecha_respuesta   := localtimestamp;
        if i_codigo_respuesta = c_cod_lote_recibido then
            r_lote.estado                := c_lote_enviado;
            r_lote.numero_lote           := i_numero_lote;
            r_lote.fecha_limite_consulta := localtimestamp + numtodsinterval(r_parametros.horas_consulta_lote, 'HOUR');
            r_lote.proximo_intento       := localtimestamp + numtodsinterval(coalesce(i_tiempo_proceso, 0), 'SECOND');
        else
            r_lote.estado          := c_lote_rechazado;
            r_lote.proximo_intento := null;
        end if;
        erp_doc_fe_lote_ctr.actualizar(i_registro => r_lote);

        for r in (select fe_documento_id from erp_doc_fe_lote_detalle where fe_lote_id = i_fe_lote_id order by orden) loop
            if r_lote.estado = c_lote_enviado then
                r_documento := bloquear_documento(i_fe_documento_id => r.fe_documento_id);
                cambiar_estado(io_documento => r_documento, i_estado_hasta => c_envio_enviado);
                r_documento.fecha_envio := r_lote.fecha_envio;
                erp_doc_fe_documento_ctr.actualizar_ciclo(i_registro => r_documento);
            else
                -- lote no encolado: cada documento vuelve a la cola con su espera
                registrar_error(i_fe_documento_id => r.fe_documento_id,
                                i_error           => 'Lote ' || i_fe_lote_id || ' no recibido: ' || i_codigo_respuesta || ' ' || i_mensaje_respuesta);
            end if;
        end loop;
    end registrar_envio_lote;

    procedure registrar_resultado (
        i_fe_documento_id    in number,
        i_codigo_respuesta   in varchar2,
        i_mensaje_respuesta  in varchar2,
        i_protocolo          in varchar2 default null,
        i_estado_resultado   in varchar2 default null
    ) is
        r_documento  erp_doc_fe_documento%rowtype := bloquear_documento(i_fe_documento_id => i_fe_documento_id);
        r_lote       erp_doc_fe_lote%rowtype;
        v_efecto     varchar2(1);
    begin
        -- nunca se interpreta el texto del mensaje: el efecto sale del código
        select max(efecto)
          into v_efecto
          from erp_doc_fe_cod_respuesta
         where codigo = i_codigo_respuesta
           and estado = c_estado_activo
           and efecto in (c_sifen_aprobado, c_sifen_observado, c_sifen_rechazado);
        v_efecto := coalesce(v_efecto, i_estado_resultado);
        if v_efecto is null or v_efecto not in (c_sifen_aprobado, c_sifen_observado, c_sifen_rechazado) then
            raise_application_error(c_err_transicion,
                'El código de respuesta ' || i_codigo_respuesta || ' no está catalogado como aprobación ni rechazo; '
                || 'indique el resultado o cargue el código en el catálogo.');
        end if;
        cambiar_estado(io_documento => r_documento, i_estado_hasta => c_envio_concluido);
        r_documento.estado_sifen      := v_efecto;
        r_documento.codigo_respuesta  := i_codigo_respuesta;
        r_documento.mensaje_respuesta := substr(i_mensaje_respuesta, 1, 255);
        r_documento.protocolo         := i_protocolo;
        r_documento.fecha_respuesta   := localtimestamp;
        r_documento.proximo_intento   := null;
        r_documento.ultimo_error      := null;
        erp_doc_fe_documento_ctr.actualizar_ciclo(i_registro => r_documento);

        if r_documento.fe_lote_id is not null then
            erp_doc_fe_lote_ctr.actualizar_detalle(i_fe_lote_id        => r_documento.fe_lote_id,
                                                   i_fe_documento_id   => i_fe_documento_id,
                                                   i_estado_resultado  => v_efecto,
                                                   i_codigo_respuesta  => i_codigo_respuesta,
                                                   i_mensaje_respuesta => substr(i_mensaje_respuesta, 1, 255));
            if erp_doc_fe_lote_ctr.contar_sin_resultado(i_fe_lote_id => r_documento.fe_lote_id) = 0 then
                r_lote                 := erp_doc_fe_lote_ctr.bloquear(i_fe_lote_id => r_documento.fe_lote_id);
                r_lote.estado          := c_lote_concluido;
                r_lote.fecha_respuesta := localtimestamp;
                r_lote.proximo_intento := null;
                erp_doc_fe_lote_ctr.actualizar(i_registro => r_lote);
            end if;
        end if;
    end registrar_resultado;

    procedure registrar_sin_respuesta (
        i_fe_documento_id  in number
    ) is
        r_documento   erp_doc_fe_documento%rowtype := bloquear_documento(i_fe_documento_id => i_fe_documento_id);
        r_parametros  t_parametros := obtener_parametros(i_empresa_id => r_documento.empresa_id);
    begin
        cambiar_estado(io_documento => r_documento, i_estado_hasta => c_envio_sin_respuesta);
        r_documento.proximo_intento := localtimestamp + numtodsinterval(r_parametros.minutos_reintento, 'MINUTE');
        erp_doc_fe_documento_ctr.actualizar_ciclo(i_registro => r_documento);
    end registrar_sin_respuesta;

    procedure registrar_evento (
        i_fe_documento_id  in number,
        i_estado_sifen     in varchar2
    ) is
        r_documento  erp_doc_fe_documento%rowtype := bloquear_documento(i_fe_documento_id => i_fe_documento_id);
    begin
        if (i_estado_sifen = c_sifen_cancelado and r_documento.estado_sifen in (c_sifen_aprobado, c_sifen_observado))
           or (i_estado_sifen = c_sifen_inutilizado and r_documento.estado_sifen in (c_sifen_sin_resultado, c_sifen_rechazado)) then
            r_documento.estado_sifen := i_estado_sifen;
            if r_documento.estado_envio <> c_envio_concluido then
                -- inutilizado antes de tener resultado: ya no se envía
                r_documento.estado_envio    := c_envio_concluido;
                r_documento.proximo_intento := null;
            end if;
            erp_doc_fe_documento_ctr.actualizar_ciclo(i_registro => r_documento);
        else
            raise_application_error(c_err_transicion,
                'El documento electrónico ' || r_documento.cdc || ' no admite ese evento: solo se cancela un documento '
                || 'aprobado y solo se inutiliza uno sin aprobar.');
        end if;
    end registrar_evento;

end erp_doc_fe_cola_reg;
/
