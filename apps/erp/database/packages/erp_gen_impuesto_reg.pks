create or replace package erp_gen_impuesto_reg
    authid definer
as
-- =============================================================================
-- Paquete : erp_gen_impuesto_reg   (capa reg)
-- Desc    : Motor de impuestos. Nada fijo en código: tasas, vigencias y
--           categorías fiscales son datos (ver docs/arquitectura-erp.md §3.2).
-- =============================================================================

    c_err_tasa_sin_vigencia   constant pls_integer := -20103;
    c_err_categoria_invalida  constant pls_integer := -20104;
    c_err_base_excedida       constant pls_integer := -20105;

    -- Porcentaje de la tasa vigente a la fecha (última vigencia con fecha_desde <= i_fecha).
    function calcular_porcentaje (
        i_impuesto_tasa_id  in erp_gen_impuesto_tasa.impuesto_tasa_id%type,
        i_fecha             in date
    ) return number;

    -- Desglosa un monto según la categoría fiscal.
    --   i_incluye_impuesto  S = i_monto ya incluye los impuestos (precio final)
    --                       N = i_monto es la base; el impuesto se suma
    --   i_decimales         null = decimales de la moneda
    -- Devuelve una línea por tasa y, si una parte del monto no está gravada por
    -- un impuesto, una línea con impuesto_tasa_id null (exento). Categoría sin
    -- tasas: una sola línea exenta con impuesto_id null.
    -- Sin categoría, monto o moneda devuelve una colección vacía.
    function calcular_impuestos (
        i_categoria_fiscal_id  in erp_gen_categoria_fiscal.categoria_fiscal_id%type,
        i_fecha                in date,
        i_monto                in number,
        i_incluye_impuesto     in varchar2,
        i_moneda_id            in erp_gen_moneda.moneda_id%type,
        i_decimales            in pls_integer default null
    ) return erp_impuesto_calc_tab;

end erp_gen_impuesto_reg;
/
