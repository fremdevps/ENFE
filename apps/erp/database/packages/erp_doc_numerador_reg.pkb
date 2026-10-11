create or replace package body erp_doc_numerador_reg
as

    c_formato_numero  constant varchar2(40) := '^([0-9]{3})-([0-9]{3})-([0-9]{7})$';

    -- Datos del numerador que no están en su fila: timbrado y establecimiento/punto.
    type t_contexto is record (
        timbrado_numero    erp_doc_timbrado.numero%type,
        timbrado_tipo      erp_doc_timbrado.tipo%type,
        timbrado_estado    erp_doc_timbrado.estado%type,
        fecha_desde        erp_doc_timbrado.fecha_desde%type,
        fecha_hasta        erp_doc_timbrado.fecha_hasta%type,
        establecimiento    erp_gen_sucursal.establecimiento%type,
        punto_expedicion   erp_gen_punto_expedicion.codigo%type
    );

    function obtener_contexto (
        i_numerador  in erp_doc_numerador%rowtype
    ) return t_contexto is
        r_contexto  t_contexto;
    begin
        select t.numero, t.tipo, t.estado, t.fecha_desde, t.fecha_hasta, s.establecimiento, p.codigo
          into r_contexto
          from erp_doc_timbrado t
         cross join erp_gen_punto_expedicion p
          join erp_gen_sucursal s on s.sucursal_id = p.sucursal_id
         where t.timbrado_id         = i_numerador.timbrado_id
           and p.punto_expedicion_id = i_numerador.punto_expedicion_id;
        return r_contexto;
    end obtener_contexto;

    function formatear_numero (
        i_establecimiento   in varchar2,
        i_punto_expedicion  in varchar2,
        i_numero            in number
    ) return varchar2 is
        v_texto  varchar2(20);
    begin
        if i_numero is null or i_numero <> trunc(i_numero) or i_numero not between 1 and 9999999 then
            raise_application_error(c_err_formato_numero, 'El número del comprobante debe estar entre 1 y 9999999.');
        end if;
        v_texto := i_establecimiento || '-' || i_punto_expedicion || '-' || lpad(to_char(i_numero), 7, '0');
        if not regexp_like(v_texto, c_formato_numero) then
            raise_application_error(c_err_formato_numero,
                'El establecimiento y el punto de expedición deben tener 3 dígitos (ej. 001-001-0000001).');
        end if;
        return v_texto;
    end formatear_numero;

    procedure validar_formato (
        i_numero_formateado  in  varchar2,
        o_establecimiento    out varchar2,
        o_punto_expedicion   out varchar2,
        o_numero             out number
    ) is
        v_texto  varchar2(40) := trim(i_numero_formateado);
    begin
        if v_texto is null or not regexp_like(v_texto, c_formato_numero) then
            raise_application_error(c_err_formato_numero,
                'El número del comprobante debe tener el formato 001-001-0000001.');
        end if;
        o_establecimiento  := regexp_substr(v_texto, c_formato_numero, 1, 1, null, 1);
        o_punto_expedicion := regexp_substr(v_texto, c_formato_numero, 1, 1, null, 2);
        o_numero           := to_number(regexp_substr(v_texto, c_formato_numero, 1, 1, null, 3));
        if o_numero = 0 then
            raise_application_error(c_err_formato_numero, 'El número del comprobante no puede ser cero.');
        end if;
    end validar_formato;

    function obtener_numerador (
        i_punto_expedicion_id  in erp_doc_numerador.punto_expedicion_id%type,
        i_tipo_documento_id    in erp_doc_numerador.tipo_documento_id%type,
        i_fecha                in date
    ) return erp_doc_numerador.numerador_id%type is
        v_numerador_id  erp_doc_numerador.numerador_id%type;
    begin
        -- el de la serie más alta con números disponibles; a igual serie, el timbrado más nuevo
        select max(n.numerador_id) keep (dense_rank first order by n.serie desc nulls last, t.fecha_desde desc)
          into v_numerador_id
          from erp_doc_numerador n
          join erp_doc_timbrado t on t.timbrado_id = n.timbrado_id
         where n.punto_expedicion_id = i_punto_expedicion_id
           and n.tipo_documento_id   = i_tipo_documento_id
           and n.estado              = c_estado_activo
           and n.numero_actual       < n.numero_hasta
           and t.estado              = c_estado_activo
           and trunc(i_fecha) between t.fecha_desde and coalesce(t.fecha_hasta, trunc(i_fecha));
        if v_numerador_id is null then
            raise_application_error(c_err_numerador_invalido,
                'No hay un numerador activo con timbrado vigente y números disponibles para ese punto de expedición y tipo de documento.');
        end if;
        return v_numerador_id;
    end obtener_numerador;

    procedure validar_usuario (
        i_numerador  in erp_doc_numerador%rowtype,
        i_usuario    in varchar2
    ) is
        v_usuario   varchar2(255) := coalesce(i_usuario, sys_context('APEX$SESSION', 'APP_USER'));
        v_cantidad  pls_integer;
    begin
        -- sin usuario identificado (job o script del propio esquema) no se restringe
        if i_numerador.es_restringido <> c_si or v_usuario is null then
            return;
        end if;
        select count(*)
          into v_cantidad
          from erp_doc_numerador_usuario nu
          join adm_seg_usuario u on u.usuario_id = nu.usuario_id
         where nu.numerador_id = i_numerador.numerador_id
           and nu.estado       = c_estado_activo
           and upper(u.username) = upper(v_usuario);
        if v_cantidad = 0 then
            raise_application_error(c_err_usuario_no_autoriz, 'No está autorizado a emitir comprobantes con este numerador.');
        end if;
    end validar_usuario;

    procedure tomar_siguiente (
        i_numerador_id       in  erp_doc_numerador.numerador_id%type,
        i_fecha              in  date,
        i_usuario            in  varchar2,
        i_espera_segundos    in  pls_integer,
        o_numero             out erp_doc_numerador.numero_actual%type,
        o_numero_formateado  out varchar2
    ) is
        r_numerador  erp_doc_numerador%rowtype;
        r_contexto   t_contexto;
        v_fecha      date := trunc(coalesce(i_fecha, current_date));
        v_numero     number;
        v_fin_rango  number;
    begin
        begin
            r_numerador := erp_doc_numerador_ctr.bloquear(i_numerador_id    => i_numerador_id,
                                                          i_espera_segundos => coalesce(i_espera_segundos, c_espera_segundos));
        exception
            when erp_doc_numerador_ctr.e_recurso_ocupado then
                raise_application_error(c_err_numerador_ocupado,
                    'Otro usuario está emitiendo con este numerador. Intente de nuevo en unos segundos.');
        end;
        if r_numerador.numerador_id is null or r_numerador.estado <> c_estado_activo then
            raise_application_error(c_err_numerador_invalido, 'El numerador no existe o está inactivo.');
        end if;
        r_contexto := obtener_contexto(i_numerador => r_numerador);
        if r_contexto.timbrado_estado <> c_estado_activo
           or v_fecha < r_contexto.fecha_desde
           or v_fecha > coalesce(r_contexto.fecha_hasta, v_fecha) then
            raise_application_error(c_err_timbrado_no_vigente,
                'El timbrado ' || r_contexto.timbrado_numero || ' no está vigente el ' || to_char(v_fecha, 'DD/MM/YYYY')
                || ' (vigencia: ' || to_char(r_contexto.fecha_desde, 'DD/MM/YYYY')
                || case when r_contexto.fecha_hasta is not null then ' al ' || to_char(r_contexto.fecha_hasta, 'DD/MM/YYYY') end || ').');
        end if;
        validar_usuario(i_numerador => r_numerador, i_usuario => i_usuario);

        -- siguiente número, saltando los rangos anulados o inutilizados
        v_numero := r_numerador.numero_actual + 1;
        loop
            exit when v_numero > r_numerador.numero_hasta;
            v_fin_rango := erp_doc_numero_inutilizado_ctr.obtener_fin_rango(i_numerador_id => i_numerador_id, i_numero => v_numero);
            exit when v_fin_rango is null;
            v_numero := v_fin_rango + 1;
        end loop;
        if v_numero > r_numerador.numero_hasta then
            raise_application_error(c_err_rango_agotado,
                'Se agotó la numeración del timbrado ' || r_contexto.timbrado_numero || ' para '
                || r_contexto.establecimiento || '-' || r_contexto.punto_expedicion
                || ' (último número autorizado: ' || r_numerador.numero_hasta || ').');
        end if;

        erp_doc_numerador_ctr.actualizar_numero(i_numerador_id => i_numerador_id, i_numero_actual => v_numero);
        o_numero            := v_numero;
        o_numero_formateado := formatear_numero(i_establecimiento  => r_contexto.establecimiento,
                                                i_punto_expedicion => r_contexto.punto_expedicion,
                                                i_numero           => v_numero);
    end tomar_siguiente;

    function obtener_aviso (
        i_numerador_id  in erp_doc_numerador.numerador_id%type,
        i_fecha         in date
    ) return varchar2 is
        r_numerador   erp_doc_numerador%rowtype := erp_doc_numerador_ctr.obtener(i_numerador_id => i_numerador_id);
        r_contexto    t_contexto;
        v_fecha       date := trunc(coalesce(i_fecha, current_date));
        v_dias        number;
        v_disponible  number;
        v_usado       number;
        v_aviso       varchar2(400);
    begin
        if r_numerador.numerador_id is null then
            return null;
        end if;
        r_contexto := obtener_contexto(i_numerador => r_numerador);
        if r_contexto.fecha_hasta is not null then
            v_dias := r_contexto.fecha_hasta - v_fecha;
            if v_dias < 0 then
                v_aviso := 'El timbrado ' || r_contexto.timbrado_numero || ' venció el ' || to_char(r_contexto.fecha_hasta, 'DD/MM/YYYY') || '.';
            elsif v_dias <= r_numerador.dias_aviso_vencimiento then
                v_aviso := 'El timbrado ' || r_contexto.timbrado_numero || ' vence en ' || v_dias || ' día(s) ('
                           || to_char(r_contexto.fecha_hasta, 'DD/MM/YYYY') || ').';
            end if;
        end if;
        v_disponible := r_numerador.numero_hasta - r_numerador.numero_actual;
        v_usado      := (r_numerador.numero_actual - r_numerador.numero_desde + 1) * 100
                        / (r_numerador.numero_hasta - r_numerador.numero_desde + 1);
        if v_disponible = 0 then
            v_aviso := v_aviso || case when v_aviso is not null then ' ' end || 'La numeración está agotada.';
        elsif v_usado >= r_numerador.porcentaje_aviso then
            v_aviso := v_aviso || case when v_aviso is not null then ' ' end
                       || 'Quedan ' || v_disponible || ' número(s) disponibles (' || round(v_usado, 1) || ' % usado).';
        end if;
        return v_aviso;
    end obtener_aviso;

    procedure inutilizar (
        i_numerador_id           in  erp_doc_numerador.numerador_id%type,
        i_numero_desde           in  number,
        i_numero_hasta           in  number,
        i_tipo                   in  varchar2,
        i_motivo_id              in  number,
        i_motivo                 in  varchar2,
        i_fecha                  in  date,
        o_numero_inutilizado_id  out erp_doc_numero_inutilizado.numero_inutilizado_id%type
    ) is
        r_numerador  erp_doc_numerador%rowtype;
        r_contexto   t_contexto;
        v_hasta      number := coalesce(i_numero_hasta, i_numero_desde);
        v_cantidad   pls_integer;
    begin
        -- se bloquea el numerador para que nadie tome un número del rango mientras se registra
        begin
            r_numerador := erp_doc_numerador_ctr.bloquear(i_numerador_id => i_numerador_id, i_espera_segundos => c_espera_segundos);
        exception
            when erp_doc_numerador_ctr.e_recurso_ocupado then
                raise_application_error(c_err_numerador_ocupado,
                    'Otro usuario está emitiendo con este numerador. Intente de nuevo en unos segundos.');
        end;
        if r_numerador.numerador_id is null then
            raise_application_error(c_err_numerador_invalido, 'El numerador no existe.');
        end if;
        if i_tipo is null or i_tipo not in (c_tipo_anulado, c_tipo_inutilizado, c_tipo_extraviado) then
            raise_application_error(c_err_inutilizacion, 'Indique si los números se anulan, se inutilizan o se extraviaron.');
        end if;
        if i_motivo is null or length(trim(i_motivo)) < c_largo_minimo_motivo then
            raise_application_error(c_err_inutilizacion, 'El motivo es obligatorio (al menos ' || c_largo_minimo_motivo || ' caracteres).');
        end if;
        if i_numero_desde is null or i_numero_desde <> trunc(i_numero_desde) or v_hasta <> trunc(v_hasta)
           or v_hasta < i_numero_desde
           or i_numero_desde < r_numerador.numero_desde or v_hasta > r_numerador.numero_hasta then
            raise_application_error(c_err_inutilizacion,
                'El rango debe estar dentro de la numeración autorizada (' || r_numerador.numero_desde || ' a ' || r_numerador.numero_hasta || ').');
        end if;
        r_contexto := obtener_contexto(i_numerador => r_numerador);
        if r_contexto.timbrado_tipo = c_timbrado_electronico and v_hasta - i_numero_desde + 1 > c_max_rango_electronico then
            raise_application_error(c_err_inutilizacion,
                'En comprobantes electrónicos se inutilizan hasta ' || c_max_rango_electronico || ' números por vez.');
        end if;
        if erp_doc_numero_inutilizado_ctr.existe_solapado(i_numerador_id => i_numerador_id,
                                                          i_numero_desde => i_numero_desde,
                                                          i_numero_hasta => v_hasta) then
            raise_application_error(c_err_inutilizacion, 'Algún número del rango ya está anulado o inutilizado.');
        end if;
        -- un documento electrónico aprobado no se inutiliza: se cancela por evento
        select count(*)
          into v_cantidad
          from erp_doc_fe_documento
         where numerador_id = i_numerador_id
           and numero between i_numero_desde and v_hasta
           and estado_sifen in (erp_doc_fe_cola_reg.c_sifen_aprobado, erp_doc_fe_cola_reg.c_sifen_observado,
                                erp_doc_fe_cola_reg.c_sifen_cancelado);
        if v_cantidad > 0 then
            raise_application_error(c_err_inutilizacion,
                'El rango incluye documentos electrónicos aprobados; esos se cancelan, no se inutilizan.');
        end if;

        erp_doc_numero_inutilizado_ctr.insertar(
            i_empresa_id            => r_numerador.empresa_id,
            i_numerador_id          => i_numerador_id,
            i_numero_desde          => i_numero_desde,
            i_numero_hasta          => v_hasta,
            i_tipo                  => i_tipo,
            i_motivo_id             => i_motivo_id,
            i_motivo                => i_motivo,
            i_fecha                 => trunc(coalesce(i_fecha, current_date)),
            o_numero_inutilizado_id => o_numero_inutilizado_id);
    end inutilizar;

end erp_doc_numerador_reg;
/
