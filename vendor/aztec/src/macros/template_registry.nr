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
comptime mut global TEMPLATE_KEY_BY_MODULE_NAME: CHashMap<Quoted, Field> = CHashMap::new();
comptime mut global TEMPLATE_KEY_BY_MODULE_NAME_HASH: CHashMap<Field, Field> = CHashMap::new();

// Maps a template key to the list of template keys it directly composes.
// Populated by the aztec macro when a contract_template module itself composes other templates.
comptime mut global TEMPLATE_COMPOSED_KEYS: CHashMap<Field, [Field]> = CHashMap::new();
comptime mut global TEMPLATE_COMPOSED_KEYS_BY_MODULE: CHashMap<Module, [Field]> = CHashMap::new();

// Maps a Module to its template key.
// Populated by contract_template so the aztec macro can determine whether the current module
// is a registered template and store transitive composed-key relationships for it.
comptime mut global TEMPLATE_KEY_BY_MODULE: CHashMap<Module, Field> = CHashMap::new();

// Per-function wrapper and ABI storage, keyed by (template_key, function_signature_key).
comptime mut global TEMPLATE_EXTERNAL_FN_WRAPPERS: CHashMap<(Field, Field), Quoted> = CHashMap::new();
comptime mut global TEMPLATE_EXTERNAL_FN_ABI_EXPORTS: CHashMap<(Field, Field), Quoted> = CHashMap::new();
comptime mut global TEMPLATE_VIRTUAL_EXTERNAL_FN_KEYS: CHashMap<(Field, Field), bool> = CHashMap::new();
comptime mut global TEMPLATE_INTERNAL_FN_QUOTED: CHashMap<(Field, Field), Quoted> = CHashMap::new();
comptime mut global TEMPLATE_VIRTUAL_INTERNAL_FN_KEYS: CHashMap<(Field, Field), bool> = CHashMap::new();

pub(crate) comptime fn template_key(template_id: CtString) -> Field {
    let template_id_str = template_id.as_quoted_str!();
    hash_str(template_id_str)
}

comptime fn hash_str<let N: u32>(value: str<N>) -> Field {
    let value_bytes = value.as_bytes();
    let mut acc: Field = value_bytes.len() as Field + 1;
    for i in 0..value_bytes.len() {
        acc = acc * 16777619 + value_bytes[i] as Field + 1;
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
    let t_key = template_key(template_id);
    let template_name_key = module_name_key(m);
    TEMPLATE_FUNCTIONS_QUOTED.insert(t_key, functions);
    TEMPLATE_ABI_EXPORTS_QUOTED.insert(t_key, abi_exports);
    TEMPLATE_CONTRACT_LIBRARY_METHODS_QUOTED.insert(t_key, contract_library_methods);
    TEMPLATE_EVENTS_QUOTED.insert(t_key, events);
    TEMPLATE_MODULES.insert(t_key, m);
    TEMPLATE_KEY_BY_MODULE.insert(m, t_key);
    TEMPLATE_KEY_BY_MODULE_NAME.insert(m.name(), t_key);
    TEMPLATE_KEY_BY_MODULE_NAME_HASH.insert(template_name_key, t_key);
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

pub(crate) comptime fn register_internal_function(
    template_key: Field,
    function_key: Field,
    wrapper: Quoted,
    is_virtual: bool,
) {
    let registry_key = (template_key, function_key);
    TEMPLATE_INTERNAL_FN_QUOTED.insert(registry_key, wrapper);
    if is_virtual {
        TEMPLATE_VIRTUAL_INTERNAL_FN_KEYS.insert(registry_key, true);
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

/// Returns the template key for a given module, if that module was registered as a template.
pub(crate) comptime fn get_template_key_by_module(m: Module) -> Option<Field> {
    TEMPLATE_KEY_BY_MODULE.get(m)
}

pub(crate) comptime fn get_template_key_by_module_name(module_name: Quoted) -> Option<Field> {
    TEMPLATE_KEY_BY_MODULE_NAME.get(module_name)
}

pub(crate) comptime fn get_template_key_by_module_name_hash(module_name_key: Field) -> Option<Field> {
    TEMPLATE_KEY_BY_MODULE_NAME_HASH.get(module_name_key)
}

pub(crate) comptime fn module_name_key(m: Module) -> Field {
    let module_name = m.name();
    let module_name_str: CtString = f"{module_name}";
    template_key(module_name_str)
}

/// Stores the list of template keys directly composed by a given template.
pub(crate) comptime fn register_template_composed_keys(t_key: Field, composed_keys: [Field]) {
    TEMPLATE_COMPOSED_KEYS.insert(t_key, composed_keys);
}

pub(crate) comptime fn register_template_composed_keys_for_module(m: Module, composed_keys: [Field]) {
    TEMPLATE_COMPOSED_KEYS_BY_MODULE.insert(m, composed_keys);
}

/// Returns the list of template keys directly composed by the given template, if any.
pub(crate) comptime fn get_template_composed_keys(t_key: Field) -> Option<[Field]> {
    TEMPLATE_COMPOSED_KEYS.get(t_key)
}

pub(crate) comptime fn get_template_composed_keys_by_module(m: Module) -> Option<[Field]> {
    TEMPLATE_COMPOSED_KEYS_BY_MODULE.get(m)
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

pub(crate) comptime fn get_template_internal_function(template_key: Field, function_key: Field) -> Option<Quoted> {
    TEMPLATE_INTERNAL_FN_QUOTED.get((template_key, function_key))
}

pub(crate) comptime fn is_template_external_function_virtual(template_key: Field, function_key: Field) -> bool {
    TEMPLATE_VIRTUAL_EXTERNAL_FN_KEYS.get((template_key, function_key)).is_some()
}

pub(crate) comptime fn is_template_internal_function_virtual(template_key: Field, function_key: Field) -> bool {
    TEMPLATE_VIRTUAL_INTERNAL_FN_KEYS.get((template_key, function_key)).is_some()
}
