# Abreviaturas de tablas — app ERP

Usadas en constraints, índices, triggers y secuencias (`<tipo>_erp_<abrev>_...`, ver docs/ESTANDAR.md §0.2).
Diseño de cada módulo: `docs/arquitectura-erp.md`.

## General (`gen`)

| Tabla | Abrev. |
|---|---|
| erp_gen_moneda | mon |
| erp_gen_pais | pai |
| erp_gen_feriado | feri |
| erp_gen_ubicacion | ubi |
| erp_gen_impuesto | imp |
| erp_gen_impuesto_tasa | imta |
| erp_gen_impuesto_tasa_vig | itv |
| erp_gen_categoria_fiscal | cafi |
| erp_gen_categoria_tasa | cata |
| erp_gen_cotizacion | cot |
| erp_gen_funcionalidad | func |
| erp_gen_rubro | rub |
| erp_gen_rubro_func | rufu |
| erp_gen_empresa_config | emcf |
| erp_gen_empresa_func | emfu |
| erp_gen_sucursal | suc |
| erp_gen_departamento | dpto |
| erp_gen_punto_expedicion | ptex |
| erp_gen_usuario_sucursal | ussu |
| erp_gen_tipo_doc_identidad | tdi |
| erp_gen_persona | prs |
| erp_gen_persona_documento | prdo |
| erp_gen_persona_direccion | prdi |
| erp_gen_persona_contacto | prco |
| erp_gen_tipo_rol | tirl |
| erp_gen_persona_rol | prro |
| erp_gen_parametro | par |
| erp_gen_periodo | peri |
| erp_gen_periodo_habilita | peha |

## Inventario (`stk`)

| Tabla | Abrev. |
|---|---|
| erp_stk_deposito | dpo |

Referencias a ADM: `adm_gen_empresa` → `emp`, `adm_seg_usuario` → `usu` (ej. `fk_erp_suc_emp`).
