create or replace package body erp_doc_fe_de_reg
as

    c_moneda_local  constant varchar2(3) := 'PYG';

    -- -------------------------------------------------------------------------
    -- Utilitarios de validación y lectura del JSON
    -- -------------------------------------------------------------------------
    procedure exigir (
        i_condicion  in boolean,
        i_mensaje    in varchar2
    ) is
    begin
        if i_condicion is null or not i_condicion then
            raise_application_error(c_err_dato_invalido, 'Datos del documento electrónico: ' || i_mensaje);
        end if;
    end exigir;

    function obtener_objeto (
        i_objeto  in json_object_t,
        i_clave   in varchar2
    ) return json_object_t is
    begin
        if i_objeto is null or not i_objeto.has(i_clave) or not i_objeto.get(i_clave).is_object then
            return null;
        end if;
        return i_objeto.get_object(i_clave);
    end obtener_objeto;

    function obtener_arreglo (
        i_objeto  in json_object_t,
        i_clave   in varchar2
    ) return json_array_t is
    begin
        if i_objeto is null or not i_objeto.has(i_clave) or not i_objeto.get(i_clave).is_array then
            return null;
        end if;
        return i_objeto.get_array(i_clave);
    end obtener_arreglo;

    function obtener_texto (
        i_objeto  in json_object_t,
        i_clave   in varchar2
    ) return varchar2 is
        v_elemento  json_element_t;
    begin
        if i_objeto is null or not i_objeto.has(i_clave) then
            return null;
        end if;
        v_elemento := i_objeto.get(i_clave);
        if v_elemento.is_string then
            return erp_doc_fe_xml_utl.limpiar_valor(i_valor => i_objeto.get_string(i_clave));
        elsif v_elemento.is_number then
            return erp_doc_fe_xml_utl.formatear_numero(i_valor => i_objeto.get_number(i_clave));
        end if;
        return null;
    end obtener_texto;

    function obtener_numero (
        i_objeto  in json_object_t,
        i_clave   in varchar2
    ) return number is
        v_elemento  json_element_t;
    begin
        if i_objeto is null or not i_objeto.has(i_clave) then
            return null;
        end if;
        v_elemento := i_objeto.get(i_clave);
        if v_elemento.is_number then
            return i_objeto.get_number(i_clave);
        elsif v_elemento.is_string then
            return to_number(trim(i_objeto.get_string(i_clave)), '99999999999999999990D99999999', 'nls_numeric_characters=''.,''');
        end if;
        return null;
    exception
        when value_error or invalid_number then
            raise_application_error(c_err_dato_invalido,
                'Datos del documento electrónico: "' || i_clave || '" debe ser un número con punto decimal.');
    end obtener_numero;

    -- Fechas AAAA-MM-DD o AAAA-MM-DDThh:mm:ss.
    function obtener_fecha (
        i_objeto  in json_object_t,
        i_clave   in varchar2
    ) return timestamp is
        v_texto  varchar2(40) := obtener_texto(i_objeto => i_objeto, i_clave => i_clave);
    begin
        if v_texto is null then
            return null;
        end if;
        if length(v_texto) = 10 then
            return to_timestamp(v_texto, 'YYYY-MM-DD');
        end if;
        return to_timestamp(substr(v_texto, 1, 19), 'YYYY-MM-DD"T"HH24:MI:SS');
    exception
        when others then
            raise_application_error(c_err_dato_invalido,
                'Datos del documento electrónico: "' || i_clave || '" debe ser una fecha AAAA-MM-DD o AAAA-MM-DDThh:mm:ss.');
    end obtener_fecha;

    -- -------------------------------------------------------------------------
    -- Utilitarios de escritura
    -- -------------------------------------------------------------------------
    procedure abrir (io_xml in out nocopy clob, i_nombre in varchar2) is
    begin
        erp_doc_fe_xml_utl.agregar(io_xml => io_xml, i_texto => '<' || i_nombre || '>');
    end abrir;

    procedure cerrar (io_xml in out nocopy clob, i_nombre in varchar2) is
    begin
        erp_doc_fe_xml_utl.agregar(io_xml => io_xml, i_texto => '</' || i_nombre || '>');
    end cerrar;

    procedure agregar_texto (io_xml in out nocopy clob, i_nombre in varchar2, i_valor in varchar2) is
    begin
        erp_doc_fe_xml_utl.agregar_elemento(io_xml => io_xml, i_nombre => i_nombre, i_valor => i_valor);
    end agregar_texto;

    -- Los numéricos opcionales en cero no se informan (§7.2.4); los obligatorios sí.
    procedure agregar_numero (
        io_xml          in out nocopy clob,
        i_nombre        in varchar2,
        i_valor         in number,
        i_obligatorio   in boolean default false
    ) is
    begin
        if i_valor is null or (i_valor = 0 and not i_obligatorio) then
            if i_obligatorio then
                agregar_texto(io_xml => io_xml, i_nombre => i_nombre, i_valor => '0');
            end if;
            return;
        end if;
        exigir(i_valor >= 0, 'no se admiten valores negativos (' || i_nombre || ').');
        agregar_texto(io_xml => io_xml, i_nombre => i_nombre, i_valor => erp_doc_fe_xml_utl.formatear_numero(i_valor => i_valor));
    end agregar_numero;

    -- {"codigo": 1, "descripcion": "CAPITAL"} -> <c…>1</c…><dDes…>CAPITAL</dDes…>
    procedure agregar_codigo (
        io_xml         in out nocopy clob,
        i_objeto       in json_object_t,
        i_nombre_cod   in varchar2,
        i_nombre_desc  in varchar2
    ) is
    begin
        if i_objeto is null or obtener_texto(i_objeto => i_objeto, i_clave => 'codigo') is null then
            return;
        end if;
        exigir(obtener_texto(i_objeto => i_objeto, i_clave => 'descripcion') is not null,
               'falta la descripción de ' || i_nombre_cod || '.');
        agregar_texto(io_xml => io_xml, i_nombre => i_nombre_cod, i_valor => obtener_texto(i_objeto => i_objeto, i_clave => 'codigo'));
        agregar_texto(io_xml => io_xml, i_nombre => i_nombre_desc, i_valor => obtener_texto(i_objeto => i_objeto, i_clave => 'descripcion'));
    end agregar_codigo;

    -- -------------------------------------------------------------------------
    -- Descripciones oficiales de los códigos (Manual Técnico SIFEN v150)
    -- -------------------------------------------------------------------------
    function describir (
        i_tabla   in varchar2,
        i_codigo  in number
    ) return varchar2 is
    begin
        return case i_tabla
            when 'TIPO_DE' then                                  -- C003 (pág. 63)
                case i_codigo when 1 then 'Factura electrónica' when 4 then 'Autofactura electrónica'
                              when 5 then 'Nota de crédito electrónica' when 6 then 'Nota de débito electrónica'
                              when 7 then 'Nota de remisión electrónica' end
            when 'TIPO_EMISION' then                             -- B003 (pág. 62)
                case i_codigo when 1 then 'Normal' when 2 then 'Contingencia' end
            when 'TIPO_TRANSACCION' then                         -- D012 (pág. 66)
                case i_codigo when 1 then 'Venta de mercadería' when 2 then 'Prestación de servicios'
                              when 3 then 'Mixto (Venta de mercadería y servicios)' when 4 then 'Venta de activo fijo'
                              when 5 then 'Venta de divisas' when 6 then 'Compra de divisas'
                              when 7 then 'Promoción o entrega de muestras' when 8 then 'Donación'
                              when 9 then 'Anticipo' when 10 then 'Compra de productos'
                              when 11 then 'Compra de servicios' when 12 then 'Venta de crédito fiscal'
                              when 13 then 'Muestras médicas (Art. 3 RG 24/2014)' end
            when 'TIPO_IMPUESTO' then                            -- D014 (pág. 67)
                case i_codigo when 1 then 'IVA' when 2 then 'ISC' when 3 then 'Renta'
                              when 4 then 'Ninguno' when 5 then 'IVA - Renta' end
            when 'CONDICION_ANTICIPO' then                       -- D020 (pág. 67)
                case i_codigo when 1 then 'Anticipo Global' when 2 then 'Anticipo por Ítem' end
            when 'TIPO_IDENTIDAD' then                           -- D209 (pág. 72)
                case i_codigo when 1 then 'Cédula paraguaya' when 2 then 'Pasaporte'
                              when 3 then 'Cédula extranjera' when 4 then 'Carnet de residencia'
                              when 5 then 'Innominado' when 6 then 'Tarjeta Diplomática de exoneración fiscal' end
            when 'INDICADOR_PRESENCIA' then                      -- E012 (pág. 74)
                case i_codigo when 1 then 'Operación presencial' when 2 then 'Operación electrónica'
                              when 3 then 'Operación telemarketing' when 4 then 'Venta a domicilio'
                              when 5 then 'Operación bancaria' when 6 then 'Operación cíclica' end
            when 'MOTIVO_NOTA' then                              -- E402 (pág. 77)
                case i_codigo when 1 then 'Devolución y Ajuste de precios' when 2 then 'Devolución'
                              when 3 then 'Descuento' when 4 then 'Bonificación'
                              when 5 then 'Crédito incobrable' when 6 then 'Recupero de costo'
                              when 7 then 'Recupero de gasto' when 8 then 'Ajuste de precio' end
            when 'CONDICION_OPERACION' then                      -- E602 (pág. 80)
                case i_codigo when 1 then 'Contado' when 2 then 'Crédito' end
            when 'CONDICION_CREDITO' then                        -- E642 (pág. 84)
                case i_codigo when 1 then 'Plazo' when 2 then 'Cuota' end
            when 'TIPO_PAGO' then                                -- E607 (pág. 82)
                case i_codigo when 1 then 'Efectivo' when 2 then 'Cheque' when 3 then 'Tarjeta de crédito'
                              when 4 then 'Tarjeta de débito' when 5 then 'Transferencia' when 6 then 'Giro'
                              when 7 then 'Billetera electrónica' when 8 then 'Tarjeta empresarial'
                              when 9 then 'Vale' when 10 then 'Retención' when 11 then 'Pago por anticipo'
                              when 12 then 'Valor fiscal' when 13 then 'Valor comercial'
                              when 14 then 'Compensación' when 15 then 'Permuta' when 16 then 'Pago bancario'
                              when 17 then 'Pago Móvil' when 18 then 'Donación' when 19 then 'Promoción'
                              when 20 then 'Consumo Interno' when 21 then 'Pago Electrónico' end
            when 'AFECTACION_IVA' then                           -- E732 (pág. 90)
                case i_codigo when 1 then 'Gravado IVA' when 2 then 'Exonerado (Art. 83- Ley 125/91)'
                              when 3 then 'Exento' when 4 then 'Gravado parcial (Grav- Exento)' end
            when 'DOCUMENTO_ASOCIADO' then                       -- H003 (pág. 108)
                case i_codigo when 1 then 'Electrónico' when 2 then 'Impreso' when 3 then 'Constancia Electrónica' end
            when 'DOCUMENTO_IMPRESO' then                        -- H010 (pág. 109)
                case i_codigo when 1 then 'Factura' when 2 then 'Nota de crédito' when 3 then 'Nota de débito'
                              when 4 then 'Nota de remisión' when 5 then 'Comprobante de retención' end
        end;
    end describir;

    -- Descripción oficial o, si el código admite texto libre (9 / 99), la que envía el llamador.
    function describir_o_tomar (
        i_tabla        in varchar2,
        i_codigo       in number,
        i_descripcion  in varchar2
    ) return varchar2 is
        v_descripcion  varchar2(200) := coalesce(describir(i_tabla => i_tabla, i_codigo => i_codigo), i_descripcion);
    begin
        exigir(v_descripcion is not null, 'el código ' || i_codigo || ' de ' || lower(replace(i_tabla, '_', ' ')) || ' no es válido o le falta la descripción.');
        return v_descripcion;
    end describir_o_tomar;

    -- Nombre de la moneda: el que envía el llamador o el del catálogo de monedas.
    function describir_moneda (
        i_codigo       in varchar2,
        i_descripcion  in varchar2
    ) return varchar2 is
        v_nombre  erp_gen_moneda.nombre%type;
    begin
        if i_descripcion is not null then
            return i_descripcion;
        end if;
        select max(nombre) into v_nombre from erp_gen_moneda where codigo = i_codigo;
        exigir(v_nombre is not null, 'la moneda ' || i_codigo || ' no existe en el catálogo y no se envió su descripción.');
        return substr(v_nombre, 1, 20);
    end describir_moneda;

    -- -------------------------------------------------------------------------
    -- Grupos del DE
    -- -------------------------------------------------------------------------
    -- D2. gEmis (pág. 67-69)
    procedure agregar_emisor (
        io_xml    in out nocopy clob,
        i_emisor  in json_object_t
    ) is
        v_actividades  json_array_t := obtener_arreglo(i_objeto => i_emisor, i_clave => 'actividades');
        v_actividad    json_object_t;
    begin
        exigir(obtener_texto(i_emisor, 'razon_social') is not null, 'falta la razón social del emisor.');
        exigir(obtener_texto(i_emisor, 'direccion') is not null, 'falta la dirección del emisor.');
        exigir(obtener_texto(i_emisor, 'telefono') is not null, 'falta el teléfono del emisor.');
        exigir(obtener_texto(i_emisor, 'email') is not null, 'falta el correo electrónico del emisor.');
        exigir(obtener_objeto(i_emisor, 'departamento') is not null and obtener_objeto(i_emisor, 'ciudad') is not null,
               'faltan el departamento y la ciudad del emisor.');
        exigir(v_actividades is not null and v_actividades.get_size between 1 and 9,
               'el emisor debe tener entre 1 y 9 actividades económicas.');

        abrir(io_xml, 'gEmis');
        agregar_texto(io_xml, 'dRucEm', obtener_texto(i_emisor, 'ruc'));
        agregar_texto(io_xml, 'dDVEmi', obtener_texto(i_emisor, 'dv'));
        agregar_numero(io_xml, 'iTipCont', obtener_numero(i_emisor, 'tipo_contribuyente'), true);
        agregar_numero(io_xml, 'cTipReg', obtener_numero(i_emisor, 'tipo_regimen'));
        agregar_texto(io_xml, 'dNomEmi', obtener_texto(i_emisor, 'razon_social'));
        agregar_texto(io_xml, 'dNomFanEmi', obtener_texto(i_emisor, 'nombre_fantasia'));
        agregar_texto(io_xml, 'dDirEmi', obtener_texto(i_emisor, 'direccion'));
        agregar_texto(io_xml, 'dNumCas', coalesce(obtener_texto(i_emisor, 'numero_casa'), '0'));
        agregar_texto(io_xml, 'dCompDir1', obtener_texto(i_emisor, 'complemento_direccion_1'));
        agregar_texto(io_xml, 'dCompDir2', obtener_texto(i_emisor, 'complemento_direccion_2'));
        agregar_codigo(io_xml, obtener_objeto(i_emisor, 'departamento'), 'cDepEmi', 'dDesDepEmi');
        agregar_codigo(io_xml, obtener_objeto(i_emisor, 'distrito'), 'cDisEmi', 'dDesDisEmi');
        agregar_codigo(io_xml, obtener_objeto(i_emisor, 'ciudad'), 'cCiuEmi', 'dDesCiuEmi');
        agregar_texto(io_xml, 'dTelEmi', obtener_texto(i_emisor, 'telefono'));
        agregar_texto(io_xml, 'dEmailE', obtener_texto(i_emisor, 'email'));
        agregar_texto(io_xml, 'dDenSuc', obtener_texto(i_emisor, 'sucursal'));
        for v_i in 0 .. v_actividades.get_size - 1 loop
            v_actividad := treat(v_actividades.get(v_i) as json_object_t);
            exigir(obtener_texto(v_actividad, 'codigo') is not null and obtener_texto(v_actividad, 'descripcion') is not null,
                   'cada actividad económica lleva código y descripción.');
            abrir(io_xml, 'gActEco');
            agregar_texto(io_xml, 'cActEco', obtener_texto(v_actividad, 'codigo'));
            agregar_texto(io_xml, 'dDesActEco', obtener_texto(v_actividad, 'descripcion'));
            cerrar(io_xml, 'gActEco');
        end loop;
        cerrar(io_xml, 'gEmis');
    end agregar_emisor;

    -- D3. gDatRec (pág. 70-73)
    procedure agregar_receptor (
        io_xml      in out nocopy clob,
        i_receptor  in json_object_t,
        io_de       in out nocopy t_de
    ) is
        v_naturaleza   number := obtener_numero(i_receptor, 'naturaleza');
        v_operacion    number := obtener_numero(i_receptor, 'tipo_operacion');
        v_tipo_ident   number := obtener_numero(i_receptor, 'tipo_documento');
        v_pais         varchar2(3) := upper(obtener_texto(i_receptor, 'pais'));
        v_pais_nombre  varchar2(100) := obtener_texto(i_receptor, 'pais_descripcion');
    begin
        exigir(v_naturaleza in (1, 2), 'la naturaleza del receptor debe ser 1 (contribuyente) o 2 (no contribuyente).');
        exigir(v_operacion in (1, 2, 3, 4), 'el tipo de operación del receptor debe ser 1 (B2B), 2 (B2C), 3 (B2G) o 4 (B2F).');
        exigir(v_pais is not null, 'falta el país del receptor.');
        exigir(obtener_texto(i_receptor, 'razon_social') is not null, 'falta el nombre o razón social del receptor.');
        if v_pais_nombre is null then
            select max(nombre) into v_pais_nombre from erp_gen_pais where codigo_iso3 = v_pais;
            exigir(v_pais_nombre is not null, 'el país ' || v_pais || ' no existe en el catálogo y no se envió su descripción.');
        end if;

        io_de.es_receptor_contribuyente := v_naturaleza = 1;
        io_de.receptor_nombre           := substr(obtener_texto(i_receptor, 'razon_social'), 1, 255);

        abrir(io_xml, 'gDatRec');
        agregar_numero(io_xml, 'iNatRec', v_naturaleza, true);
        agregar_numero(io_xml, 'iTiOpe', v_operacion, true);
        agregar_texto(io_xml, 'cPaisRec', v_pais);
        agregar_texto(io_xml, 'dDesPaisRe', substr(v_pais_nombre, 1, 30));
        if v_naturaleza = 1 then
            exigir(obtener_numero(i_receptor, 'tipo_contribuyente') in (1, 2), 'falta el tipo de contribuyente del receptor (1 física, 2 jurídica).');
            exigir(obtener_texto(i_receptor, 'ruc') is not null and regexp_like(obtener_texto(i_receptor, 'dv'), '^[0-9]$'),
                   'faltan el RUC y el dígito verificador del receptor.');
            io_de.receptor_documento := obtener_texto(i_receptor, 'ruc');
            agregar_numero(io_xml, 'iTiContRec', obtener_numero(i_receptor, 'tipo_contribuyente'), true);
            agregar_texto(io_xml, 'dRucRec', obtener_texto(i_receptor, 'ruc'));
            agregar_texto(io_xml, 'dDVRec', obtener_texto(i_receptor, 'dv'));
        elsif v_operacion <> 4 then
            exigir(v_tipo_ident in (1, 2, 3, 4, 5, 6, 9), 'el tipo de documento de identidad del receptor no es válido.');
            -- innominado: número 0 (campo D210, pág. 72)
            io_de.receptor_documento := case when v_tipo_ident = 5 then '0' else obtener_texto(i_receptor, 'numero_documento') end;
            exigir(io_de.receptor_documento is not null, 'falta el número de documento del receptor.');
            agregar_numero(io_xml, 'iTipIDRec', v_tipo_ident, true);
            agregar_texto(io_xml, 'dDTipIDRec',
                          describir_o_tomar('TIPO_IDENTIDAD', v_tipo_ident, obtener_texto(i_receptor, 'tipo_documento_descripcion')));
            agregar_texto(io_xml, 'dNumIDRec', io_de.receptor_documento);
        end if;
        agregar_texto(io_xml, 'dNomRec', obtener_texto(i_receptor, 'razon_social'));
        agregar_texto(io_xml, 'dNomFanRec', obtener_texto(i_receptor, 'nombre_fantasia'));
        if obtener_texto(i_receptor, 'direccion') is not null then
            agregar_texto(io_xml, 'dDirRec', obtener_texto(i_receptor, 'direccion'));
            agregar_texto(io_xml, 'dNumCasRec', coalesce(obtener_texto(i_receptor, 'numero_casa'), '0'));
            if v_operacion <> 4 then
                exigir(obtener_objeto(i_receptor, 'departamento') is not null and obtener_objeto(i_receptor, 'ciudad') is not null,
                       'si se informa la dirección del receptor también van su departamento y su ciudad.');
                agregar_codigo(io_xml, obtener_objeto(i_receptor, 'departamento'), 'cDepRec', 'dDesDepRec');
                agregar_codigo(io_xml, obtener_objeto(i_receptor, 'distrito'), 'cDisRec', 'dDesDisRec');
                agregar_codigo(io_xml, obtener_objeto(i_receptor, 'ciudad'), 'cCiuRec', 'dDesCiuRec');
            end if;
        else
            exigir(v_operacion <> 4, 'la dirección del receptor es obligatoria en operaciones con el exterior (B2F).');
        end if;
        agregar_texto(io_xml, 'dTelRec', obtener_texto(i_receptor, 'telefono'));
        agregar_texto(io_xml, 'dCelRec', obtener_texto(i_receptor, 'celular'));
        agregar_texto(io_xml, 'dEmailRec', obtener_texto(i_receptor, 'email'));
        agregar_texto(io_xml, 'dCodCliente', obtener_texto(i_receptor, 'codigo_cliente'));
        cerrar(io_xml, 'gDatRec');
    end agregar_receptor;

    -- E7. gCamCond (pág. 80-85)
    procedure agregar_condicion (
        io_xml       in out nocopy clob,
        i_condicion  in json_object_t,
        i_moneda     in varchar2
    ) is
        v_tipo      number := obtener_numero(i_condicion, 'tipo');
        v_pagos     json_array_t := obtener_arreglo(i_condicion, 'pagos');
        v_pago      json_object_t;
        v_credito   json_object_t := obtener_objeto(i_condicion, 'credito');
        v_cuotas    json_array_t;
        v_cuota     json_object_t;
        v_moneda    varchar2(3);
    begin
        exigir(v_tipo in (1, 2), 'la condición de la operación debe ser 1 (contado) o 2 (crédito).');
        exigir(v_tipo <> 1 or (v_pagos is not null and v_pagos.get_size > 0), 'una operación al contado lleva al menos una forma de pago.');
        exigir(v_tipo <> 2 or v_credito is not null, 'una operación a crédito lleva los datos del crédito.');

        abrir(io_xml, 'gCamCond');
        agregar_numero(io_xml, 'iCondOpe', v_tipo, true);
        agregar_texto(io_xml, 'dDCondOpe', describir('CONDICION_OPERACION', v_tipo));
        if v_pagos is not null then
            for v_i in 0 .. v_pagos.get_size - 1 loop
                v_pago   := treat(v_pagos.get(v_i) as json_object_t);
                v_moneda := coalesce(upper(obtener_texto(v_pago, 'moneda')), i_moneda);
                exigir(obtener_numero(v_pago, 'monto') > 0, 'cada forma de pago lleva un monto mayor que cero.');
                exigir(v_moneda = c_moneda_local or obtener_numero(v_pago, 'tipo_cambio') > 0,
                       'un pago en moneda extranjera lleva su tipo de cambio.');
                abrir(io_xml, 'gPaConEIni');
                agregar_numero(io_xml, 'iTiPago', obtener_numero(v_pago, 'tipo'), true);
                agregar_texto(io_xml, 'dDesTiPag',
                              describir_o_tomar('TIPO_PAGO', obtener_numero(v_pago, 'tipo'), obtener_texto(v_pago, 'descripcion')));
                agregar_numero(io_xml, 'dMonTiPag', obtener_numero(v_pago, 'monto'), true);
                agregar_texto(io_xml, 'cMoneTiPag', v_moneda);
                agregar_texto(io_xml, 'dDMoneTiPag', describir_moneda(v_moneda, obtener_texto(v_pago, 'moneda_descripcion')));
                if v_moneda <> c_moneda_local then
                    agregar_numero(io_xml, 'dTiCamTiPag', obtener_numero(v_pago, 'tipo_cambio'), true);
                end if;
                cerrar(io_xml, 'gPaConEIni');
            end loop;
        end if;
        if v_tipo = 2 then
            v_cuotas := obtener_arreglo(v_credito, 'cuotas');
            exigir(obtener_numero(v_credito, 'tipo') in (1, 2), 'la condición del crédito debe ser 1 (plazo) o 2 (cuota).');
            exigir(obtener_numero(v_credito, 'tipo') <> 1 or obtener_texto(v_credito, 'plazo') is not null,
                   'un crédito a plazo lleva el plazo (ej. "30 días").');
            exigir(obtener_numero(v_credito, 'tipo') <> 2 or (v_cuotas is not null and v_cuotas.get_size > 0),
                   'un crédito en cuotas lleva el detalle de las cuotas.');
            abrir(io_xml, 'gPagCred');
            agregar_numero(io_xml, 'iCondCred', obtener_numero(v_credito, 'tipo'), true);
            agregar_texto(io_xml, 'dDCondCred', describir('CONDICION_CREDITO', obtener_numero(v_credito, 'tipo')));
            if obtener_numero(v_credito, 'tipo') = 1 then
                agregar_texto(io_xml, 'dPlazoCre', obtener_texto(v_credito, 'plazo'));
            else
                agregar_numero(io_xml, 'dCuotas', v_cuotas.get_size, true);
            end if;
            agregar_numero(io_xml, 'dMonEnt', obtener_numero(v_credito, 'entrega_inicial'));
            if obtener_numero(v_credito, 'tipo') = 2 then
                for v_i in 0 .. v_cuotas.get_size - 1 loop
                    v_cuota  := treat(v_cuotas.get(v_i) as json_object_t);
                    v_moneda := coalesce(upper(obtener_texto(v_cuota, 'moneda')), i_moneda);
                    exigir(obtener_numero(v_cuota, 'monto') > 0, 'cada cuota lleva un monto mayor que cero.');
                    abrir(io_xml, 'gCuotas');
                    agregar_texto(io_xml, 'cMoneCuo', v_moneda);
                    agregar_texto(io_xml, 'dDMoneCuo', describir_moneda(v_moneda, obtener_texto(v_cuota, 'moneda_descripcion')));
                    agregar_numero(io_xml, 'dMonCuota', obtener_numero(v_cuota, 'monto'), true);
                    agregar_texto(io_xml, 'dVencCuo', erp_doc_fe_xml_utl.formatear_fecha(obtener_fecha(v_cuota, 'vencimiento')));
                    cerrar(io_xml, 'gCuotas');
                end loop;
            end if;
            cerrar(io_xml, 'gPagCred');
        end if;
        cerrar(io_xml, 'gCamCond');
    end agregar_condicion;

    -- H. gCamDEAsoc (pág. 108-110)
    procedure agregar_asociados (
        io_xml       in out nocopy clob,
        i_asociados  in json_array_t
    ) is
        v_asociado  json_object_t;
        v_tipo      number;
    begin
        if i_asociados is null then
            return;
        end if;
        exigir(i_asociados.get_size <= 99, 'se admiten hasta 99 documentos asociados.');
        for v_i in 0 .. i_asociados.get_size - 1 loop
            v_asociado := treat(i_asociados.get(v_i) as json_object_t);
            v_tipo     := obtener_numero(v_asociado, 'tipo');
            exigir(v_tipo in (1, 2), 'el documento asociado debe ser 1 (electrónico) o 2 (impreso).');
            abrir(io_xml, 'gCamDEAsoc');
            agregar_numero(io_xml, 'iTipDocAso', v_tipo, true);
            agregar_texto(io_xml, 'dDesTipDocAso', describir('DOCUMENTO_ASOCIADO', v_tipo));
            if v_tipo = 1 then
                exigir(erp_doc_fe_cdc_utl.es_valido_sn(i_cdc => obtener_texto(v_asociado, 'cdc')) = 'S',
                       'el código de control del documento asociado no es válido.');
                agregar_texto(io_xml, 'dCdCDERef', obtener_texto(v_asociado, 'cdc'));
            else
                exigir(regexp_like(obtener_texto(v_asociado, 'timbrado'), '^[0-9]{8}$')
                       and regexp_like(obtener_texto(v_asociado, 'establecimiento'), '^[0-9]{3}$')
                       and regexp_like(obtener_texto(v_asociado, 'punto'), '^[0-9]{3}$')
                       and obtener_numero(v_asociado, 'numero') between 1 and 9999999
                       and obtener_fecha(v_asociado, 'fecha') is not null,
                       'el documento impreso asociado lleva timbrado, establecimiento, punto, número y fecha.');
                agregar_texto(io_xml, 'dNTimDI', obtener_texto(v_asociado, 'timbrado'));
                agregar_texto(io_xml, 'dEstDocAso', obtener_texto(v_asociado, 'establecimiento'));
                agregar_texto(io_xml, 'dPExpDocAso', obtener_texto(v_asociado, 'punto'));
                agregar_texto(io_xml, 'dNumDocAso', lpad(to_char(obtener_numero(v_asociado, 'numero')), 7, '0'));
                agregar_numero(io_xml, 'iTipoDocAso', obtener_numero(v_asociado, 'tipo_documento_impreso'), true);
                agregar_texto(io_xml, 'dDTipoDocAso',
                              describir_o_tomar('DOCUMENTO_IMPRESO', obtener_numero(v_asociado, 'tipo_documento_impreso'), null));
                agregar_texto(io_xml, 'dFecEmiDI', erp_doc_fe_xml_utl.formatear_fecha(obtener_fecha(v_asociado, 'fecha')));
            end if;
            cerrar(io_xml, 'gCamDEAsoc');
        end loop;
    end agregar_asociados;

    -- -------------------------------------------------------------------------
    -- DE completo
    -- -------------------------------------------------------------------------
    function generar_de (
        i_datos             in clob,
        i_codigo_seguridad  in varchar2,
        i_fecha_firma       in timestamp,
        i_version_formato   in varchar2 default '150'
    ) return t_de is
        r_de             t_de;
        v_datos          json_object_t;
        v_timbrado       json_object_t;
        v_operacion      json_object_t;
        v_emisor         json_object_t;
        v_receptor       json_object_t;
        v_items          json_array_t;
        v_item           json_object_t;
        v_iva            json_object_t;
        v_totales        json_object_t;
        v_xml            clob;
        v_tipo_impuesto  number;
        v_cond_cambio    number;
        v_tipo_cambio    number;
        v_decimales      pls_integer;
        -- por ítem
        v_cantidad       number;
        v_precio         number;
        v_descuento      number;
        v_desc_global    number;
        v_anticipo       number;
        v_ant_global     number;
        v_total_item     number;
        v_cambio_item    number;
        v_afectacion     number;
        v_proporcion     number;
        v_tasa           number;
        v_base           number;
        v_liquidacion    number;
        -- acumulados del grupo F
        v_sub_exenta     number := 0;
        v_sub_exonerada  number := 0;
        v_sub_5          number := 0;
        v_sub_10         number := 0;
        v_tot_desc       number := 0;
        v_tot_desc_glo   number := 0;
        v_tot_ant        number := 0;
        v_tot_ant_glo    number := 0;
        v_iva_5          number := 0;
        v_iva_10         number := 0;
        v_base_5         number := 0;
        v_base_10        number := 0;
        v_total_gs_item  number := 0;
        v_total_bruto    number;
        v_redondeo       number;
        v_comision       number;
        v_liq_red_5      number := 0;
        v_liq_red_10     number := 0;
        v_con_iva        boolean;
    begin
        begin
            v_datos := json_object_t.parse(i_datos);
        exception
            when others then
                raise_application_error(c_err_dato_invalido, 'Datos del documento electrónico: el JSON no es válido.', true);
        end;
        v_timbrado  := obtener_objeto(v_datos, 'timbrado');
        v_operacion := obtener_objeto(v_datos, 'operacion');
        v_emisor    := obtener_objeto(v_datos, 'emisor');
        v_receptor  := obtener_objeto(v_datos, 'receptor');
        v_items     := obtener_arreglo(v_datos, 'items');
        v_totales   := obtener_objeto(v_datos, 'totales');

        exigir(v_timbrado is not null and v_operacion is not null and v_emisor is not null and v_receptor is not null,
               'faltan los grupos timbrado, operacion, emisor o receptor.');
        exigir(v_items is not null and v_items.get_size between 1 and 999, 'el documento lleva entre 1 y 999 ítems.');
        exigir(i_fecha_firma is not null, 'falta la fecha de la firma.');
        exigir(regexp_like(i_version_formato, '^[0-9]{3}$'), 'la versión del formato debe tener 3 dígitos.');

        r_de.version_formato  := i_version_formato;
        r_de.codigo_seguridad := i_codigo_seguridad;
        -- sin fracción de segundos: el formato del manual llega hasta el segundo
        r_de.fecha_firma      := to_timestamp(to_char(i_fecha_firma, 'YYYYMMDDHH24MISS'), 'YYYYMMDDHH24MISS');
        r_de.tipo_de          := obtener_numero(v_datos, 'tipo_de');
        r_de.tipo_emision     := coalesce(obtener_numero(v_datos, 'tipo_emision'), 1);
        r_de.fecha_emision    := obtener_fecha(v_datos, 'fecha_emision');
        r_de.timbrado         := obtener_texto(v_timbrado, 'numero');
        r_de.establecimiento  := obtener_texto(v_timbrado, 'establecimiento');
        r_de.punto_expedicion := obtener_texto(v_timbrado, 'punto');
        r_de.numero           := obtener_numero(v_timbrado, 'numero_documento');
        r_de.serie            := upper(obtener_texto(v_timbrado, 'serie'));
        r_de.moneda           := upper(obtener_texto(v_operacion, 'moneda'));
        r_de.cantidad_items   := v_items.get_size;

        exigir(r_de.tipo_de in (1, 5, 6),
               'en esta etapa se generan facturas (1), notas de crédito (5) y notas de débito (6) electrónicas.');
        exigir(r_de.fecha_emision is not null, 'falta la fecha de emisión.');
        exigir(regexp_like(r_de.timbrado, '^[0-9]{8}$'), 'el timbrado debe tener 8 dígitos.');
        exigir(obtener_fecha(v_timbrado, 'fecha_inicio') is not null, 'falta la fecha de inicio de vigencia del timbrado.');
        exigir(r_de.serie is null or regexp_like(r_de.serie, '^[A-Z]{2}$'), 'la serie son dos letras mayúsculas.');
        exigir(regexp_like(r_de.moneda, '^[A-Z]{3}$'), 'falta la moneda de la operación (ISO 4217).');

        v_tipo_impuesto := obtener_numero(v_operacion, 'tipo_impuesto');
        v_cond_cambio   := obtener_numero(v_operacion, 'condicion_cambio');
        v_tipo_cambio   := obtener_numero(v_operacion, 'tipo_cambio');
        v_decimales     := coalesce(obtener_numero(v_operacion, 'decimales'), case when r_de.moneda = c_moneda_local then 0 else 2 end);
        v_con_iva       := v_tipo_impuesto in (1, 5);
        exigir(v_tipo_impuesto in (1, 3, 4, 5), 'el tipo de impuesto debe ser 1 (IVA), 3 (renta), 4 (ninguno) o 5 (IVA - renta).');
        exigir(v_decimales between 0 and 8, 'los decimales de los importes deben estar entre 0 y 8.');
        if r_de.moneda = c_moneda_local then
            v_cond_cambio := null;
            v_tipo_cambio := null;
        else
            v_cond_cambio := coalesce(v_cond_cambio, 1);
            exigir(v_cond_cambio in (1, 2), 'la condición del tipo de cambio debe ser 1 (global) o 2 (por ítem).');
            exigir(v_cond_cambio <> 1 or v_tipo_cambio > 0, 'falta el tipo de cambio de la operación.');
        end if;

        -- El CDC valida RUC, establecimiento, punto, número, contribuyente y código de seguridad.
        r_de.cdc := erp_doc_fe_cdc_utl.generar_cdc(
                        i_tipo_de            => r_de.tipo_de,
                        i_ruc                => obtener_texto(v_emisor, 'ruc'),
                        i_dv_ruc             => obtener_texto(v_emisor, 'dv'),
                        i_establecimiento    => r_de.establecimiento,
                        i_punto_expedicion   => r_de.punto_expedicion,
                        i_numero             => r_de.numero,
                        i_tipo_contribuyente => obtener_numero(v_emisor, 'tipo_contribuyente'),
                        i_fecha_emision      => cast(r_de.fecha_emision as date),
                        i_tipo_emision       => r_de.tipo_emision,
                        i_codigo_seguridad   => i_codigo_seguridad);

        dbms_lob.createtemporary(v_xml, true, dbms_lob.session);

        -- A. Campos firmados (pág. 61-62)
        agregar_texto(v_xml, 'dDVId', substr(r_de.cdc, 44, 1));
        agregar_texto(v_xml, 'dFecFirma', erp_doc_fe_xml_utl.formatear_fecha_hora(r_de.fecha_firma));
        agregar_texto(v_xml, 'dSisFact', '1');

        -- B. gOpeDE (pág. 62-63)
        abrir(v_xml, 'gOpeDE');
        agregar_numero(v_xml, 'iTipEmi', r_de.tipo_emision, true);
        agregar_texto(v_xml, 'dDesTipEmi', describir('TIPO_EMISION', r_de.tipo_emision));
        agregar_texto(v_xml, 'dCodSeg', i_codigo_seguridad);
        agregar_texto(v_xml, 'dInfoEmi', obtener_texto(v_datos, 'info_emisor'));
        agregar_texto(v_xml, 'dInfoFisc', obtener_texto(v_datos, 'info_fisco'));
        cerrar(v_xml, 'gOpeDE');

        -- C. gTimb (pág. 63-64)
        abrir(v_xml, 'gTimb');
        agregar_numero(v_xml, 'iTiDE', r_de.tipo_de, true);
        agregar_texto(v_xml, 'dDesTiDE', describir('TIPO_DE', r_de.tipo_de));
        agregar_texto(v_xml, 'dNumTim', r_de.timbrado);
        agregar_texto(v_xml, 'dEst', r_de.establecimiento);
        agregar_texto(v_xml, 'dPunExp', r_de.punto_expedicion);
        agregar_texto(v_xml, 'dNumDoc', lpad(to_char(r_de.numero), 7, '0'));
        agregar_texto(v_xml, 'dSerieNum', r_de.serie);
        agregar_texto(v_xml, 'dFeIniT', erp_doc_fe_xml_utl.formatear_fecha(obtener_fecha(v_timbrado, 'fecha_inicio')));
        agregar_texto(v_xml, 'dFeFinT', erp_doc_fe_xml_utl.formatear_fecha(obtener_fecha(v_timbrado, 'fecha_fin')));
        cerrar(v_xml, 'gTimb');

        -- D. gDatGralOpe (pág. 65-73)
        abrir(v_xml, 'gDatGralOpe');
        agregar_texto(v_xml, 'dFeEmiDE', erp_doc_fe_xml_utl.formatear_fecha_hora(r_de.fecha_emision));
        abrir(v_xml, 'gOpeCom');
        if r_de.tipo_de = 1 then
            agregar_numero(v_xml, 'iTipTra', obtener_numero(v_operacion, 'tipo_transaccion'), true);
            agregar_texto(v_xml, 'dDesTipTra', describir_o_tomar('TIPO_TRANSACCION', obtener_numero(v_operacion, 'tipo_transaccion'), null));
        end if;
        agregar_numero(v_xml, 'iTImp', v_tipo_impuesto, true);
        agregar_texto(v_xml, 'dDesTImp', describir('TIPO_IMPUESTO', v_tipo_impuesto));
        agregar_texto(v_xml, 'cMoneOpe', r_de.moneda);
        agregar_texto(v_xml, 'dDesMoneOpe', describir_moneda(r_de.moneda, obtener_texto(v_operacion, 'moneda_descripcion')));
        agregar_numero(v_xml, 'dCondTiCam', v_cond_cambio);
        if v_cond_cambio = 1 then
            agregar_numero(v_xml, 'dTiCam', v_tipo_cambio, true);
        end if;
        if obtener_numero(v_operacion, 'condicion_anticipo') is not null then
            agregar_numero(v_xml, 'iCondAnt', obtener_numero(v_operacion, 'condicion_anticipo'), true);
            agregar_texto(v_xml, 'dDesCondAnt', describir_o_tomar('CONDICION_ANTICIPO', obtener_numero(v_operacion, 'condicion_anticipo'), null));
        end if;
        cerrar(v_xml, 'gOpeCom');
        agregar_emisor(io_xml => v_xml, i_emisor => v_emisor);
        agregar_receptor(io_xml => v_xml, i_receptor => v_receptor, io_de => r_de);
        cerrar(v_xml, 'gDatGralOpe');

        -- E. gDtipDE (pág. 73-93)
        abrir(v_xml, 'gDtipDE');
        if r_de.tipo_de = 1 then
            abrir(v_xml, 'gCamFE');
            agregar_numero(v_xml, 'iIndPres', coalesce(obtener_numero(obtener_objeto(v_datos, 'factura'), 'indicador_presencia'), 1), true);
            agregar_texto(v_xml, 'dDesIndPres',
                          describir_o_tomar('INDICADOR_PRESENCIA',
                                            coalesce(obtener_numero(obtener_objeto(v_datos, 'factura'), 'indicador_presencia'), 1),
                                            obtener_texto(obtener_objeto(v_datos, 'factura'), 'indicador_presencia_descripcion')));
            agregar_texto(v_xml, 'dFecEmNR',
                          erp_doc_fe_xml_utl.formatear_fecha(obtener_fecha(obtener_objeto(v_datos, 'factura'), 'fecha_envio_mercaderia')));
            cerrar(v_xml, 'gCamFE');
            exigir(obtener_objeto(v_datos, 'condicion') is not null, 'la factura lleva la condición de la operación.');
            agregar_condicion(io_xml => v_xml, i_condicion => obtener_objeto(v_datos, 'condicion'), i_moneda => r_de.moneda);
        else
            exigir(obtener_numero(obtener_objeto(v_datos, 'nota'), 'motivo') between 1 and 8,
                   'la nota de crédito o débito lleva el motivo de emisión (1 a 8).');
            exigir(obtener_arreglo(v_datos, 'documentos_asociados') is not null
                   and obtener_arreglo(v_datos, 'documentos_asociados').get_size > 0,
                   'la nota de crédito o débito lleva al menos un documento asociado.');
            abrir(v_xml, 'gCamNCDE');
            agregar_numero(v_xml, 'iMotEmi', obtener_numero(obtener_objeto(v_datos, 'nota'), 'motivo'), true);
            agregar_texto(v_xml, 'dDesMotEmi', describir('MOTIVO_NOTA', obtener_numero(obtener_objeto(v_datos, 'nota'), 'motivo')));
            cerrar(v_xml, 'gCamNCDE');
        end if;

        -- E8. gCamItem (pág. 85-90)
        for v_i in 0 .. v_items.get_size - 1 loop
            v_item        := treat(v_items.get(v_i) as json_object_t);
            v_iva         := obtener_objeto(v_item, 'iva');
            v_cantidad    := obtener_numero(v_item, 'cantidad');
            v_precio      := obtener_numero(v_item, 'precio_unitario');
            v_descuento   := coalesce(obtener_numero(v_item, 'descuento'), 0);
            v_desc_global := coalesce(obtener_numero(v_item, 'descuento_global'), 0);
            v_anticipo    := coalesce(obtener_numero(v_item, 'anticipo'), 0);
            v_ant_global  := coalesce(obtener_numero(v_item, 'anticipo_global'), 0);
            v_cambio_item := case when v_cond_cambio = 2 then obtener_numero(v_item, 'tipo_cambio') end;

            exigir(obtener_texto(v_item, 'codigo') is not null and obtener_texto(v_item, 'descripcion') is not null,
                   'el ítem ' || (v_i + 1) || ' lleva código y descripción.');
            exigir(obtener_numero(v_item, 'unidad_medida') is not null and obtener_texto(v_item, 'unidad_medida_descripcion') is not null,
                   'el ítem ' || (v_i + 1) || ' lleva la unidad de medida (código y representación).');
            exigir(v_cantidad > 0 and v_precio >= 0, 'el ítem ' || (v_i + 1) || ' lleva cantidad mayor que cero y precio no negativo.');
            exigir(v_descuento >= 0 and v_desc_global >= 0 and v_anticipo >= 0 and v_ant_global >= 0
                   and v_descuento + v_desc_global + v_anticipo + v_ant_global <= v_precio,
                   'los descuentos y anticipos del ítem ' || (v_i + 1) || ' no pueden superar su precio.');
            exigir(v_cond_cambio is null or v_cond_cambio <> 2 or v_cambio_item > 0,
                   'el ítem ' || (v_i + 1) || ' lleva su tipo de cambio.');

            -- EA008 = (precio - descuentos - anticipos) * cantidad (pág. 89)
            v_total_item := round((v_precio - v_descuento - v_desc_global - v_anticipo - v_ant_global) * v_cantidad, 8);

            abrir(v_xml, 'gCamItem');
            agregar_texto(v_xml, 'dCodInt', obtener_texto(v_item, 'codigo'));
            agregar_texto(v_xml, 'dParAranc', obtener_texto(v_item, 'partida_arancelaria'));
            agregar_texto(v_xml, 'dNCM', obtener_texto(v_item, 'ncm'));
            agregar_texto(v_xml, 'dGtin', obtener_texto(v_item, 'gtin'));
            agregar_texto(v_xml, 'dGtinPq', obtener_texto(v_item, 'gtin_paquete'));
            agregar_texto(v_xml, 'dDesProSer', obtener_texto(v_item, 'descripcion'));
            agregar_numero(v_xml, 'cUniMed', obtener_numero(v_item, 'unidad_medida'), true);
            agregar_texto(v_xml, 'dDesUniMed', obtener_texto(v_item, 'unidad_medida_descripcion'));
            agregar_numero(v_xml, 'dCantProSer', v_cantidad, true);
            if obtener_texto(v_item, 'pais_origen') is not null then
                exigir(obtener_texto(v_item, 'pais_origen_descripcion') is not null,
                       'el ítem ' || (v_i + 1) || ' lleva la descripción del país de origen.');
                agregar_texto(v_xml, 'cPaisOrig', upper(obtener_texto(v_item, 'pais_origen')));
                agregar_texto(v_xml, 'dDesPaisOrig', obtener_texto(v_item, 'pais_origen_descripcion'));
            end if;
            agregar_texto(v_xml, 'dInfItem', obtener_texto(v_item, 'info'));

            abrir(v_xml, 'gValorItem');
            agregar_numero(v_xml, 'dPUniProSer', v_precio, true);
            agregar_numero(v_xml, 'dTiCamIt', v_cambio_item);
            agregar_numero(v_xml, 'dTotBruOpeItem', round(v_precio * v_cantidad, 8), true);
            abrir(v_xml, 'gValorRestaItem');
            agregar_numero(v_xml, 'dDescItem', v_descuento, true);
            if v_descuento > 0 then
                agregar_numero(v_xml, 'dPorcDesIt', round(v_descuento * 100 / v_precio, 8), true);
            end if;
            agregar_numero(v_xml, 'dDescGloItem', v_desc_global);
            agregar_numero(v_xml, 'dAntPreUniIt', v_anticipo, true);
            agregar_numero(v_xml, 'dAntGloPreUniIt', v_ant_global, true);
            agregar_numero(v_xml, 'dTotOpeItem', v_total_item, true);
            if v_cambio_item is not null then
                agregar_numero(v_xml, 'dTotOpeGs', round(v_total_item * v_cambio_item, 8), true);
                v_total_gs_item := v_total_gs_item + round(v_total_item * v_cambio_item, 8);
            end if;
            cerrar(v_xml, 'gValorRestaItem');
            cerrar(v_xml, 'gValorItem');

            -- E8.2 gCamIVA (pág. 89-90)
            exigir(v_iva is not null, 'el ítem ' || (v_i + 1) || ' lleva la afectación del IVA.');
            v_afectacion := obtener_numero(v_iva, 'afectacion');
            v_tasa       := coalesce(obtener_numero(v_iva, 'tasa'), 0);
            exigir(v_afectacion in (1, 2, 3, 4), 'la afectación del IVA del ítem ' || (v_i + 1) || ' debe ser 1, 2, 3 o 4.');
            if v_afectacion in (2, 3) then
                v_tasa       := 0;
                v_proporcion := 0;
                v_base       := 0;
                v_liquidacion := 0;
            else
                v_proporcion := coalesce(obtener_numero(v_iva, 'proporcion'), 100);
                exigir(v_tasa in (5, 10), 'la tasa del IVA del ítem ' || (v_i + 1) || ' debe ser 5 o 10.');
                exigir(v_proporcion > 0 and v_proporcion <= 100 and (v_afectacion = 4 or v_proporcion = 100),
                       'la proporción gravada del ítem ' || (v_i + 1) || ' no es válida.');
                -- E735 = [EA008 * (E733/100)] / 1,1 o 1,05 ; E736 = E735 * (E734/100)
                v_base        := round(v_total_item * (v_proporcion / 100) / (1 + v_tasa / 100), v_decimales);
                v_liquidacion := round(v_base * v_tasa / 100, v_decimales);
            end if;
            abrir(v_xml, 'gCamIVA');
            agregar_numero(v_xml, 'iAfecIVA', v_afectacion, true);
            agregar_texto(v_xml, 'dDesAfecIVA', describir('AFECTACION_IVA', v_afectacion));
            agregar_numero(v_xml, 'dPropIVA', v_proporcion, true);
            agregar_numero(v_xml, 'dTasaIVA', v_tasa, true);
            agregar_numero(v_xml, 'dBasGravIVA', v_base, true);
            agregar_numero(v_xml, 'dLiqIVAItem', v_liquidacion, true);
            cerrar(v_xml, 'gCamIVA');
            cerrar(v_xml, 'gCamItem');

            -- acumulados del grupo F
            if v_afectacion = 3 then
                v_sub_exenta := v_sub_exenta + v_total_item;
            elsif v_afectacion = 2 then
                v_sub_exonerada := v_sub_exonerada + v_total_item;
            elsif v_tasa = 5 then
                v_sub_5  := v_sub_5 + v_total_item;
                v_iva_5  := v_iva_5 + v_liquidacion;
                v_base_5 := v_base_5 + v_base;
            else
                v_sub_10  := v_sub_10 + v_total_item;
                v_iva_10  := v_iva_10 + v_liquidacion;
                v_base_10 := v_base_10 + v_base;
            end if;
            v_tot_desc     := v_tot_desc + v_descuento;
            v_tot_desc_glo := v_tot_desc_glo + v_desc_global;
            v_tot_ant      := v_tot_ant + v_anticipo;
            v_tot_ant_glo  := v_tot_ant_glo + v_ant_global;
        end loop;
        cerrar(v_xml, 'gDtipDE');

        -- F. gTotSub (pág. 102-106)
        v_total_bruto := v_sub_exenta + v_sub_exonerada + v_sub_5 + v_sub_10;
        v_redondeo    := coalesce(obtener_numero(v_totales, 'redondeo'), 0);
        v_comision    := obtener_numero(v_totales, 'comision');
        exigir(v_redondeo >= 0 and v_redondeo <= v_total_bruto, 'el redondeo no es válido.');
        r_de.monto_total := v_total_bruto - v_redondeo + coalesce(v_comision, 0);
        if v_con_iva and v_redondeo > 0 then
            -- F036 / F037: IVA contenido en el redondeo, a la tasa de la operación
            if v_sub_10 > 0 then
                v_liq_red_10 := round(v_redondeo / 1.1, v_decimales);
            elsif v_sub_5 > 0 then
                v_liq_red_5 := round(v_redondeo / 1.05, v_decimales);
            end if;
        end if;
        r_de.monto_impuesto := case when v_con_iva
                                    then v_iva_5 + v_iva_10 - v_liq_red_5 - v_liq_red_10
                                         + coalesce(obtener_numero(v_totales, 'iva_comision'), 0)
                                    else 0 end;

        abrir(v_xml, 'gTotSub');
        agregar_numero(v_xml, 'dSubExe', v_sub_exenta);
        agregar_numero(v_xml, 'dSubExo', v_sub_exonerada);
        if v_tipo_impuesto = 1 then
            agregar_numero(v_xml, 'dSub5', v_sub_5);
            agregar_numero(v_xml, 'dSub10', v_sub_10);
        end if;
        agregar_numero(v_xml, 'dTotOpe', v_total_bruto, true);
        agregar_numero(v_xml, 'dTotDesc', v_tot_desc, true);
        agregar_numero(v_xml, 'dTotDescGlotem', v_tot_desc_glo, true);
        agregar_numero(v_xml, 'dTotAntItem', v_tot_ant, true);
        agregar_numero(v_xml, 'dTotAnt', v_tot_ant_glo, true);
        agregar_numero(v_xml, 'dPorcDescTotal', coalesce(obtener_numero(v_totales, 'porcentaje_descuento_global'), 0), true);
        agregar_numero(v_xml, 'dDescTotal', v_tot_desc + v_tot_desc_glo, true);
        agregar_numero(v_xml, 'dAnticipo', v_tot_ant + v_tot_ant_glo, true);
        agregar_numero(v_xml, 'dRedon', v_redondeo, true);
        agregar_numero(v_xml, 'dComi', v_comision);
        agregar_numero(v_xml, 'dTotGralOpe', r_de.monto_total, true);
        if v_con_iva then
            agregar_numero(v_xml, 'dIVA5', v_iva_5);
            agregar_numero(v_xml, 'dIVA10', v_iva_10);
            agregar_numero(v_xml, 'dLiqTotIVA5', v_liq_red_5);
            agregar_numero(v_xml, 'dLiqTotIVA10', v_liq_red_10);
            agregar_numero(v_xml, 'dIVAComi', obtener_numero(v_totales, 'iva_comision'));
            agregar_numero(v_xml, 'dTotIVA', r_de.monto_impuesto, true);
            agregar_numero(v_xml, 'dBaseGrav5', v_base_5);
            agregar_numero(v_xml, 'dBaseGrav10', v_base_10);
            agregar_numero(v_xml, 'dTBasGraIVA', v_base_5 + v_base_10, true);
        end if;
        if v_cond_cambio = 1 then
            agregar_numero(v_xml, 'dTotalGs', round(r_de.monto_total * v_tipo_cambio, 8), true);
        elsif v_cond_cambio = 2 then
            agregar_numero(v_xml, 'dTotalGs', v_total_gs_item, true);
        end if;
        cerrar(v_xml, 'gTotSub');

        -- H. gCamDEAsoc
        agregar_asociados(io_xml => v_xml, i_asociados => obtener_arreglo(v_datos, 'documentos_asociados'));

        r_de.contenido := v_xml;
        return r_de;
    end generar_de;

    function obtener_de_canonico (
        i_cdc        in varchar2,
        i_contenido  in clob
    ) return clob is
        v_xml  clob;
    begin
        dbms_lob.createtemporary(v_xml, true, dbms_lob.call);
        -- C14N exclusiva: el namespace usado por el elemento se declara en él, antes del atributo
        erp_doc_fe_xml_utl.agregar(io_xml => v_xml, i_texto => '<DE xmlns="' || erp_doc_fe_xml_utl.c_ns_sifen || '" Id="' || i_cdc || '">');
        dbms_lob.append(v_xml, i_contenido);
        erp_doc_fe_xml_utl.agregar(io_xml => v_xml, i_texto => '</DE>');
        return v_xml;
    end obtener_de_canonico;

    procedure generar_rde (
        i_de                in  t_de,
        i_clave_privada     in  varchar2,
        i_certificado       in  varchar2,
        i_id_csc            in  varchar2,
        i_csc               in  varchar2,
        i_url_consulta_qr   in  varchar2,
        i_declara_esquema   in  boolean,
        o_xml               out nocopy clob,
        o_resumen           out varchar2,
        o_url_qr            out varchar2
    ) is
        v_declara  boolean := coalesce(i_declara_esquema, true);
    begin
        exigir(i_certificado is not null, 'falta el certificado digital.');
        o_resumen := erp_doc_fe_firma_utl.calcular_resumen(
                         i_xml_canonico => obtener_de_canonico(i_cdc => i_de.cdc, i_contenido => i_de.contenido));
        o_url_qr  := erp_doc_fe_qr_utl.generar_url(
                         i_url_consulta     => i_url_consulta_qr,
                         i_version          => i_de.version_formato,
                         i_cdc              => i_de.cdc,
                         i_fecha_emision    => i_de.fecha_emision,
                         i_receptor         => i_de.receptor_documento,
                         i_es_contribuyente => i_de.es_receptor_contribuyente,
                         i_total            => i_de.monto_total,
                         i_total_iva        => i_de.monto_impuesto,
                         i_cantidad_items   => i_de.cantidad_items,
                         i_resumen          => o_resumen,
                         i_id_csc           => i_id_csc,
                         i_csc              => i_csc);

        dbms_lob.createtemporary(o_xml, true, dbms_lob.session);
        erp_doc_fe_xml_utl.agregar(
            io_xml  => o_xml,
            i_texto => '<rDE xmlns="' || erp_doc_fe_xml_utl.c_ns_sifen || '"'
                       || case when v_declara
                               then ' xmlns:xsi="' || erp_doc_fe_xml_utl.c_ns_xsi || '"'
                                    || ' xsi:schemaLocation="' || erp_doc_fe_xml_utl.c_ns_sifen
                                    || ' siRecepDE_v' || i_de.version_formato || '.xsd"' end
                       || '>'
                       || '<dVerFor>' || i_de.version_formato || '</dVerFor>'
                       || '<DE Id="' || i_de.cdc || '">');
        dbms_lob.append(o_xml, i_de.contenido);
        erp_doc_fe_xml_utl.agregar(io_xml => o_xml, i_texto => '</DE>');
        erp_doc_fe_xml_utl.agregar(
            io_xml  => o_xml,
            i_texto => erp_doc_fe_firma_utl.generar_firma(i_id            => i_de.cdc,
                                                         i_resumen       => o_resumen,
                                                         i_clave_privada => i_clave_privada,
                                                         i_certificado   => i_certificado,
                                                         i_declara_xsi   => v_declara));
        -- J. gCamFuFD (pág. 110): fuera de la firma
        abrir(o_xml, 'gCamFuFD');
        agregar_texto(o_xml, 'dCarQR', o_url_qr);
        cerrar(o_xml, 'gCamFuFD');
        cerrar(o_xml, 'rDE');
    end generar_rde;

    -- Texto entre dos marcas (sin incluirlas); null si no están.
    function extraer_entre (
        i_xml     in clob,
        i_inicio  in varchar2,
        i_fin     in varchar2
    ) return varchar2 is
        v_desde  integer := dbms_lob.instr(i_xml, i_inicio);
        v_hasta  integer;
    begin
        if coalesce(v_desde, 0) = 0 then
            return null;
        end if;
        v_desde := v_desde + length(i_inicio);
        v_hasta := dbms_lob.instr(i_xml, i_fin, v_desde);
        if coalesce(v_hasta, 0) = 0 or v_hasta - v_desde > 32000 then
            return null;
        end if;
        return dbms_lob.substr(i_xml, v_hasta - v_desde, v_desde);
    end extraer_entre;

    function obtener_error_firma (
        i_xml            in clob,
        i_clave_publica  in varchar2 default null
    ) return varchar2 is
        c_marca_de   constant varchar2(10) := '<DE Id="';
        v_inicio     integer;
        v_fin        integer;
        v_cdc        varchar2(44);
        v_contenido  clob;
        v_resumen    varchar2(100);
        v_firma      varchar2(2000);
        v_declara    boolean;
        v_clave      varchar2(32767) := i_clave_publica;
    begin
        if i_xml is null then
            return 'No hay XML para verificar.';
        end if;
        v_inicio := dbms_lob.instr(i_xml, c_marca_de);
        v_fin    := dbms_lob.instr(i_xml, '</DE>');
        if coalesce(v_inicio, 0) = 0 or coalesce(v_fin, 0) = 0 then
            return 'No se encontró el elemento DE.';
        end if;
        v_cdc := dbms_lob.substr(i_xml, 44, v_inicio + length(c_marca_de));
        if erp_doc_fe_cdc_utl.es_valido_sn(i_cdc => v_cdc) <> 'S'
           or dbms_lob.substr(i_xml, 2, v_inicio + length(c_marca_de) + 44) <> '">' then
            return 'El identificador del DE no es un código de control válido.';
        end if;
        v_inicio    := v_inicio + length(c_marca_de) + 46;
        v_contenido := substr(i_xml, v_inicio, v_fin - v_inicio);
        v_resumen   := extraer_entre(i_xml => i_xml, i_inicio => '<DigestValue>', i_fin => '</DigestValue>');
        v_firma     := extraer_entre(i_xml => i_xml, i_inicio => '<SignatureValue>', i_fin => '</SignatureValue>');
        if v_resumen is null or v_firma is null then
            return 'El documento no está firmado.';
        end if;
        if v_resumen <> erp_doc_fe_firma_utl.calcular_resumen(
                            i_xml_canonico => obtener_de_canonico(i_cdc => v_cdc, i_contenido => v_contenido)) then
            return 'El contenido del DE no coincide con el resumen firmado (DigestValue).';
        end if;
        -- el rDE declara xmlns:xsi si aparece en su etiqueta de apertura
        v_declara := instr(dbms_lob.substr(i_xml, dbms_lob.instr(i_xml, '>'), 1), 'xmlns:xsi=') > 0;
        if coalesce(extraer_entre(i_xml => i_xml, i_inicio => '<Signature xmlns="' || erp_doc_fe_xml_utl.c_ns_dsig || '">',
                                  i_fin => '<SignatureValue>'), '-')
           <> erp_doc_fe_firma_utl.generar_signed_info(i_id => v_cdc, i_resumen => v_resumen,
                                                       i_es_canonico => false, i_declara_xsi => v_declara) then
            return 'El SignedInfo no tiene la forma esperada.';
        end if;
        if v_clave is null then
            v_clave := erp_doc_fe_firma_utl.extraer_clave_publica(
                           i_certificado => extraer_entre(i_xml => i_xml, i_inicio => '<X509Certificate>', i_fin => '</X509Certificate>'));
        end if;
        if not erp_doc_fe_firma_utl.es_firma_valida(
                   i_texto         => erp_doc_fe_firma_utl.generar_signed_info(i_id => v_cdc, i_resumen => v_resumen,
                                                                               i_es_canonico => true, i_declara_xsi => v_declara),
                   i_firma         => v_firma,
                   i_clave_publica => v_clave) then
            return 'La firma digital no es válida para la clave pública indicada.';
        end if;
        return null;
    end obtener_error_firma;

    procedure validar_firma (
        i_xml            in clob,
        i_clave_publica  in varchar2 default null
    ) is
        v_error  varchar2(400) := obtener_error_firma(i_xml => i_xml, i_clave_publica => i_clave_publica);
    begin
        if v_error is not null then
            raise_application_error(c_err_firma_invalida, v_error);
        end if;
    end validar_firma;

end erp_doc_fe_de_reg;
/
