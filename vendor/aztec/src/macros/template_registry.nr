//! Registry that stores pre-generated `Quoted` values for contract templates.
//!
//! The `#[contract_template(...)]` macro stores:
//!
//! - internals + contract library methods by template key
//! - external function wrappers by `(template_key, function_signature)` pair
//! - external ABI exports by `(template_key, function_signature)` pair
//! - template virtual function markers
//! - template module references
//!
//! This enables host-side composition to replay only the specific template entries that are not
//! overridden and remain safe under the cross-crate restrictions.

use crate::utils::cmap::CHashMap;

// Key is a stable hash derived from a user-specified template id.
comptime mut global TEMPLATE_NON_EXTERNAL_FUNCTIONS_QUOTED: CHashMap<Field, Quoted> = CHashMap::new();
comptime mut global TEMPLATE_MODULES: CHashMap<Field, Module> = CHashMap::new();

comptime mut global TEMPLATE_EXTERNAL_FN_WRAPPERS: CHashMap<(Field, Field), Quoted> = CHashMap::new();
comptime mut global TEMPLATE_EXTERNAL_FN_ABI_EXPORTS: CHashMap<(Field, Field), Quoted> = CHashMap::new();
comptime mut global TEMPLATE_VIRTUAL_EXTERNAL_FN_KEYS: CHashMap<(Field, Field), bool> = CHashMap::new();

pub(crate) comptime fn template_key(template_id: CtString) -> Field {
    let template_id_str: str<_> = template_id.as_quoted_str!();
    let template_id_bytes = template_id_str.as_bytes();
    let mut acc: Field = template_id_bytes.len() as Field + 1;
    for i in 0..template_id_bytes.len() {
        acc = acc * 16777619 + template_id_bytes[i] as Field + 1;
    }
    acc
}

/// Registers template-level non-external functions and module metadata.
pub(crate) comptime fn register_template(template_id: CtString, non_external_functions: Quoted, m: Module) {
    let template_key = template_key(template_id);
    TEMPLATE_NON_EXTERNAL_FUNCTIONS_QUOTED.insert(template_key, non_external_functions);
    TEMPLATE_MODULES.insert(template_key, m);
}

/// Registers one external function wrapper/ABI pair for a template and marks it virtual if needed.
pub(crate) comptime fn register_external_function(
    template_key: Field,
    function_key: Field,
    wrapper: Quoted,
    abi_export: Quoted,
    is_virtual: bool,
) {
    let registry_key = (template_key, function_key);
    TEMPLATE_EXTERNAL_FN_WRAPPERS.insert(registry_key, wrapper);
    TEMPLATE_EXTERNAL_FN_ABI_EXPORTS.insert(registry_key, abi_export);
    if is_virtual {
        TEMPLATE_VIRTUAL_EXTERNAL_FN_KEYS.insert(registry_key, true);
    }
}

pub(crate) comptime fn get_template_functions(template_key: Field) -> Option<Quoted> {
    TEMPLATE_NON_EXTERNAL_FUNCTIONS_QUOTED.get(template_key)
}

pub(crate) comptime fn get_template_external_function_wrapper(template_key: Field, function_key: Field) -> Option<Quoted> {
    TEMPLATE_EXTERNAL_FN_WRAPPERS.get((template_key, function_key))
}

pub(crate) comptime fn get_template_external_function_abi_export(template_key: Field, function_key: Field) -> Option<Quoted> {
    TEMPLATE_EXTERNAL_FN_ABI_EXPORTS.get((template_key, function_key))
}

pub(crate) comptime fn is_template_external_function_virtual(template_key: Field, function_key: Field) -> bool {
    TEMPLATE_VIRTUAL_EXTERNAL_FN_KEYS.get((template_key, function_key)).is_some()
}

pub(crate) comptime fn get_template_module(template_key: Field) -> Option<Module> {
    TEMPLATE_MODULES.get(template_key)
}
