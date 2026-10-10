-- GENERADO por tools/build-supporting-objects.ps1 - NO EDITAR (fuente: apps/erp/database)

-- >>> apps/erp/database/types/erp_impuesto_calc_typ.sql
-- =============================================================================
-- Tipo    : erp_impuesto_calc_typ
-- Desc    : Una línea del cálculo de impuestos de un monto (una por tasa, más la
--           parte exenta/no gravada si la hay). Lo devuelve erp_gen_impuesto_api.
-- =============================================================================
create or replace type erp_impuesto_calc_typ force as object (
    impuesto_id       number,          -- null = monto sin impuestos (categoría exenta)
    impuesto_tasa_id  number,          -- null = parte exenta/no gravada del impuesto
    codigo_tasa       varchar2(10),
    porcentaje        number,          -- tasa aplicada (10 = 10 %)
    porcentaje_base   number,          -- % del monto afectado por la tasa
    monto             number,          -- parte del monto original que corresponde a la línea
    monto_base        number,          -- base imponible (o monto exento)
    monto_impuesto    number           -- impuesto liquidado
);
/

-- >>> apps/erp/database/types/erp_impuesto_calc_tab.sql
-- =============================================================================
-- Tipo    : erp_impuesto_calc_tab
-- Desc    : Colección de erp_impuesto_calc_typ (usable en SQL con table()).
-- =============================================================================
create or replace type erp_impuesto_calc_tab force as table of erp_impuesto_calc_typ;
/
