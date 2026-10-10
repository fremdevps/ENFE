create or replace package body erp_stk_producto_ctr
as

    procedure insertar (
        i_producto     in  erp_stk_producto%rowtype,
        o_producto_id  out erp_stk_producto.producto_id%type
    ) is
    begin
        insert into erp_stk_producto (
            empresa_id, codigo, nombre, descripcion, descripcion_fe, tipo, unidad_id, unidad_id_compra, factor_compra,
            unidad_id_venta, factor_venta, categoria_fiscal_id, categoria_id, marca_id, tiene_lote, tiene_serie,
            tiene_vencimiento, dias_vida_util, meses_garantia, metodo_costo, porcentaje_descuento_max, peso_neto,
            peso_bruto, volumen, largo, ancho, alto, atributos, estado)
        values (
            i_producto.empresa_id, i_producto.codigo, i_producto.nombre, i_producto.descripcion, i_producto.descripcion_fe,
            i_producto.tipo, i_producto.unidad_id, i_producto.unidad_id_compra, i_producto.factor_compra,
            i_producto.unidad_id_venta, i_producto.factor_venta, i_producto.categoria_fiscal_id, i_producto.categoria_id,
            i_producto.marca_id, i_producto.tiene_lote, i_producto.tiene_serie, i_producto.tiene_vencimiento,
            i_producto.dias_vida_util, i_producto.meses_garantia, i_producto.metodo_costo,
            i_producto.porcentaje_descuento_max, i_producto.peso_neto, i_producto.peso_bruto, i_producto.volumen,
            i_producto.largo, i_producto.ancho, i_producto.alto, i_producto.atributos, i_producto.estado)
        returning producto_id into o_producto_id;
    end insertar;

    procedure actualizar (
        i_producto  in erp_stk_producto%rowtype
    ) is
    begin
        update erp_stk_producto
           set codigo                   = i_producto.codigo,
               nombre                   = i_producto.nombre,
               descripcion              = i_producto.descripcion,
               descripcion_fe           = i_producto.descripcion_fe,
               tipo                     = i_producto.tipo,
               unidad_id                = i_producto.unidad_id,
               unidad_id_compra         = i_producto.unidad_id_compra,
               factor_compra            = i_producto.factor_compra,
               unidad_id_venta          = i_producto.unidad_id_venta,
               factor_venta             = i_producto.factor_venta,
               categoria_fiscal_id      = i_producto.categoria_fiscal_id,
               categoria_id             = i_producto.categoria_id,
               marca_id                 = i_producto.marca_id,
               tiene_lote               = i_producto.tiene_lote,
               tiene_serie              = i_producto.tiene_serie,
               tiene_vencimiento        = i_producto.tiene_vencimiento,
               dias_vida_util           = i_producto.dias_vida_util,
               meses_garantia           = i_producto.meses_garantia,
               metodo_costo             = i_producto.metodo_costo,
               porcentaje_descuento_max = i_producto.porcentaje_descuento_max,
               peso_neto                = i_producto.peso_neto,
               peso_bruto               = i_producto.peso_bruto,
               volumen                  = i_producto.volumen,
               largo                    = i_producto.largo,
               ancho                    = i_producto.ancho,
               alto                     = i_producto.alto,
               atributos                = i_producto.atributos,
               estado                   = i_producto.estado
         where producto_id = i_producto.producto_id;
    end actualizar;

    function obtener (
        i_producto_id  in erp_stk_producto.producto_id%type
    ) return erp_stk_producto%rowtype is
        r_producto  erp_stk_producto%rowtype;
    begin
        select * into r_producto from erp_stk_producto where producto_id = i_producto_id;
        return r_producto;
    exception
        when no_data_found then
            return r_producto;
    end obtener;

end erp_stk_producto_ctr;
/
