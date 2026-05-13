//! Registry that stores pre-generated Quoted code for contract templates.
//!
//! - template functions/abi exports/contract-library methods/events by template key
//! - external wrappers and abi exports by `(template_key, function_signature)` pair
//! - template module references and virtual markers

use crate::utils::cmap::CHashMap;

// Key is a stable hash derived from a user-specified template id.
comptime mut global TEMPLATE_FUNCTIONS_QUOTED: CHashMap<Field, Quoted> = CHashMap::new();
comptime mut global TEMPLATE_ABI_EXPORTS_QUOTED: CHashMap<Field, Quoted> = CHashMap::new();
comptime mut global TEMPLATE_CONTRACT_LIBRARY_METHODS_QUOTED: CHashMap<Field, Quoted> = CHashMap::new();
comptime mut global TEMPLATE_EVENTS_QUOTED: CHashMap<Field, Quoted> = CHashMap::new();
comptime mut global TEMPLATE_MODULES: CHashMap<Field, Module> = CHashMap::new();
comptime mut global TEMPLATE_COMPOSED_TEMPLATE_IDS_BY_MODULE: CHashMap<Module, [Field]> = CHashMap::new();

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

pub(crate) comptime fn register_template(
    template_id: CtString,
    functions: Quoted,
    abi_exports: Quoted,
    contract_library_methods: Quoted,
    events: Quoted,
    m: Module,
) {
    let template_key = template_key(template_id);
    TEMPLATE_FUNCTIONS_QUOTED.insert(template_key, functions);
    TEMPLATE_ABI_EXPORTS_QUOTED.insert(template_key, abi_exports);
    TEMPLATE_CONTRACT_LIBRARY_METHODS_QUOTED.insert(template_key, contract_library_methods);
    TEMPLATE_EVENTS_QUOTED.insert(template_key, events);
    TEMPLATE_MODULES.insert(template_key, m);
}

pub(crate) comptime fn register_composed_template_ids(m: Module, composed_template_ids: [Field]) {
    TEMPLATE_COMPOSED_TEMPLATE_IDS_BY_MODULE.insert(m, composed_template_ids);
}

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
    TEMPLATE_FUNCTIONS_QUOTED.get(template_key)
}

pub(crate) comptime fn get_template_abi_exports(template_key: Field) -> Option<Quoted> {
    TEMPLATE_ABI_EXPORTS_QUOTED.get(template_key)
}

pub(crate) comptime fn get_template_contract_library_methods(template_key: Field) -> Option<Quoted> {
    TEMPLATE_CONTRACT_LIBRARY_METHODS_QUOTED.get(template_key)
}

pub(crate) comptime fn get_template_events(template_key: Field) -> Option<Quoted> {
    TEMPLATE_EVENTS_QUOTED.get(template_key)
}

pub(crate) comptime fn get_template_module(template_key: Field) -> Option<Module> {
    TEMPLATE_MODULES.get(template_key)
}

pub(crate) comptime fn get_template_composed_template_ids(template_module: Module) -> Option<[Field]> {
    TEMPLATE_COMPOSED_TEMPLATE_IDS_BY_MODULE.get(template_module)
}

pub(crate) comptime fn get_template_external_function_wrapper(
    template_key: Field,
    function_key: Field,
) -> Option<Quoted> {
    TEMPLATE_EXTERNAL_FN_WRAPPERS.get((template_key, function_key))
}

pub(crate) comptime fn get_template_external_function_abi_export(
    template_key: Field,
    function_key: Field,
) -> Option<Quoted> {
    TEMPLATE_EXTERNAL_FN_ABI_EXPORTS.get((template_key, function_key))
}

pub(crate) comptime fn is_template_external_function_virtual(template_key: Field, function_key: Field) -> bool {
    TEMPLATE_VIRTUAL_EXTERNAL_FN_KEYS.get((template_key, function_key)).is_some()
}
