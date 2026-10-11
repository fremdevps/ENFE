create or replace package body erp_doc_tipo_documento_api
as

    -- Vigencia inicial de los códigos del registro mensual de comprobantes cargados por
    -- crear_base. VALIDAR contra la especificación técnica vigente del registro de comprobantes.
    c_fecha_codigo_fiscal  constant date := date '2022-01-01';

    procedure crear_base (
        i_empresa_id  in number
    ) is
    begin
        -- Plantilla: una fila por tipo. Columnas en el orden del insert.
        merge into erp_doc_tipo_documento t
        using (
            select i_empresa_id empresa_id, c.clase_documento_id, p.*
              from (
                select 'FE' codigo, 'FACTURA' clase, 'Factura electrónica' nombre, 'FE' abreviatura, 'VEN' modulo, 'E' origen,
                       'C' tipo_cuenta, 'D' signo_cuenta, 'N' tiene_saldo_aplicable, -1 signo_stock, 'N' debe_valorizar_costo,
                       'S' es_legal, 'E' tipo_emision, 'S' debe_exigir_timbrado, 1 codigo_sifen, 'V' libro_iva, 1 signo_libro_iva,
                       'S' debe_calcular_impuesto, 'N' debe_exigir_ruc, 'N' debe_exigir_motivo, 'N' debe_exigir_cuenta_fondo,
                       'N' requiere_documento_origen, 'VENTAS' grupo_estadistico, 1 signo_estadistica, 'S' debe_generar_asiento
                  from dual union all
                select 'NCE', 'NOTA_CREDITO', 'Nota de crédito electrónica', 'NCE', 'VEN', 'E', 'C', 'C', 'S', 1, 'N',
                       'S', 'E', 'S', 5, 'V', -1, 'S', 'N', 'S', 'N', 'S', 'VENTAS', -1, 'S' from dual union all
                select 'NDE', 'NOTA_DEBITO', 'Nota de débito electrónica', 'NDE', 'VEN', 'E', 'C', 'D', 'N', 0, 'N',
                       'S', 'E', 'S', 6, 'V', 1, 'S', 'N', 'S', 'N', 'S', 'VENTAS', 1, 'S' from dual union all
                select 'NRE', 'REMISION', 'Nota de remisión electrónica', 'NRE', 'STK', 'E', 'N', 'N', 'N', 0, 'N',
                       'S', 'E', 'S', 7, 'N', 1, 'N', 'N', 'N', 'N', 'N', null, 0, 'N' from dual union all
                select 'AFE', 'AUTOFACTURA', 'Autofactura electrónica', 'AFE', 'COM', 'E', 'P', 'C', 'N', 1, 'S',
                       'S', 'E', 'S', 4, 'C', 1, 'S', 'N', 'N', 'N', 'N', 'COMPRAS', 1, 'S' from dual union all
                select 'FAC', 'FACTURA', 'Factura preimpresa', 'FAC', 'VEN', 'E', 'C', 'D', 'N', -1, 'N',
                       'S', 'P', 'S', null, 'V', 1, 'S', 'N', 'N', 'N', 'N', 'VENTAS', 1, 'S' from dual union all
                select 'NCR', 'NOTA_CREDITO', 'Nota de crédito preimpresa', 'NC', 'VEN', 'E', 'C', 'C', 'S', 1, 'N',
                       'S', 'P', 'S', null, 'V', -1, 'S', 'N', 'S', 'N', 'S', 'VENTAS', -1, 'S' from dual union all
                select 'NDB', 'NOTA_DEBITO', 'Nota de débito preimpresa', 'ND', 'VEN', 'E', 'C', 'D', 'N', 0, 'N',
                       'S', 'P', 'S', null, 'V', 1, 'S', 'N', 'S', 'N', 'S', 'VENTAS', 1, 'S' from dual union all
                select 'FCP', 'FACTURA', 'Factura de proveedor', 'FCP', 'COM', 'R', 'P', 'C', 'N', 1, 'S',
                       'S', 'P', 'S', null, 'C', 1, 'S', 'S', 'N', 'N', 'N', 'COMPRAS', 1, 'S' from dual union all
                select 'NCP', 'NOTA_CREDITO', 'Nota de crédito de proveedor', 'NCP', 'COM', 'R', 'P', 'D', 'S', -1, 'S',
                       'S', 'P', 'S', null, 'C', -1, 'S', 'S', 'N', 'N', 'S', 'COMPRAS', -1, 'S' from dual union all
                select 'REC', 'RECIBO', 'Recibo de dinero', 'REC', 'FIN', 'E', 'C', 'C', 'N', 0, 'N',
                       'N', 'I', 'N', null, 'N', 1, 'N', 'N', 'N', 'S', 'N', null, 0, 'S' from dual union all
                select 'OPG', 'ORDEN_PAGO', 'Orden de pago', 'OP', 'FIN', 'E', 'P', 'D', 'N', 0, 'N',
                       'N', 'I', 'N', null, 'N', 1, 'N', 'N', 'N', 'S', 'N', null, 0, 'S' from dual union all
                select 'ANT', 'ANTICIPO', 'Anticipo de cliente', 'ANT', 'FIN', 'E', 'C', 'C', 'S', 0, 'N',
                       'N', 'I', 'N', null, 'N', 1, 'N', 'N', 'N', 'S', 'N', null, 0, 'S' from dual
              ) p
              join erp_doc_clase_documento c on c.codigo = p.clase
        ) s
           on (t.empresa_id = s.empresa_id and t.codigo = s.codigo)
         when not matched then
            insert (empresa_id, clase_documento_id, codigo, nombre, abreviatura, modulo, origen,
                    tipo_cuenta, signo_cuenta, tiene_saldo_aplicable, signo_stock, debe_valorizar_costo,
                    es_legal, tipo_emision, debe_exigir_timbrado, codigo_sifen, libro_iva, signo_libro_iva,
                    debe_calcular_impuesto, debe_exigir_ruc, debe_exigir_motivo, debe_exigir_cuenta_fondo,
                    requiere_documento_origen, grupo_estadistico, signo_estadistica, debe_generar_asiento)
            values (s.empresa_id, s.clase_documento_id, s.codigo, s.nombre, s.abreviatura, s.modulo, s.origen,
                    s.tipo_cuenta, s.signo_cuenta, s.tiene_saldo_aplicable, s.signo_stock, s.debe_valorizar_costo,
                    s.es_legal, s.tipo_emision, s.debe_exigir_timbrado, s.codigo_sifen, s.libro_iva, s.signo_libro_iva,
                    s.debe_calcular_impuesto, s.debe_exigir_ruc, s.debe_exigir_motivo, s.debe_exigir_cuenta_fondo,
                    s.requiere_documento_origen, s.grupo_estadistico, s.signo_estadistica, s.debe_generar_asiento);

        -- Código en el registro mensual de comprobantes, por clase, para los tipos legales
        -- que todavía no tienen ninguno.
        merge into erp_doc_tipo_doc_fiscal t
        using (
            select d.tipo_documento_id, f.codigo_registro, f.descripcion
              from erp_doc_tipo_documento d
              join erp_doc_clase_documento c on c.clase_documento_id = d.clase_documento_id
              join (select 'AUTOFACTURA' clase, '101' codigo_registro, 'Autofactura' descripcion from dual union all
                    select 'FACTURA',      '109', 'Factura'          from dual union all
                    select 'NOTA_CREDITO', '110', 'Nota de crédito'  from dual union all
                    select 'NOTA_DEBITO',  '111', 'Nota de débito'   from dual) f on f.clase = c.codigo
             where d.empresa_id = i_empresa_id
               and d.es_legal = 'S'
        ) s
           on (t.tipo_documento_id = s.tipo_documento_id)
         when not matched then
            insert (tipo_documento_id, codigo_registro, descripcion, fecha_desde)
            values (s.tipo_documento_id, s.codigo_registro, s.descripcion, c_fecha_codigo_fiscal);
    end crear_base;

    function obtener_codigo_fiscal (
        i_tipo_documento_id  in number,
        i_fecha              in date default current_date
    ) return varchar2 is
        v_codigo  erp_doc_tipo_doc_fiscal.codigo_registro%type;
    begin
        select max(codigo_registro) keep (dense_rank last order by fecha_desde)
          into v_codigo
          from erp_doc_tipo_doc_fiscal
         where tipo_documento_id = i_tipo_documento_id
           and fecha_desde <= coalesce(i_fecha, current_date);
        return v_codigo;
    end obtener_codigo_fiscal;

end erp_doc_tipo_documento_api;
/
