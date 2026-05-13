//! Registry that stores the pre-generated Quoted code for contract templates.
//!
//! The `#[contract_template(...)]` macro processes all functions in a template contract and
//! generates their `__aztec_nr_internals__` wrappers, ABI exports, and helper wrappers as
//! `Quoted` at the time the template module is elaborated. This pre-generated code is stored here
//! and retrieved by the composition machinery to be included in the host module's output.

use crate::utils::cmap::CHashMap;

// Key is a stable hash derived from a user-specified template id.
comptime mut global TEMPLATE_FUNCTIONS_QUOTED: CHashMap<Field, Quoted> = CHashMap::new();
comptime mut global TEMPLATE_ABI_EXPORTS_QUOTED: CHashMap<Field, Quoted> = CHashMap::new();
comptime mut global TEMPLATE_CONTRACT_LIBRARY_METHODS_QUOTED: CHashMap<Field, Quoted> = CHashMap::new();
comptime mut global TEMPLATE_EVENTS_QUOTED: CHashMap<Field, Quoted> = CHashMap::new();
comptime mut global TEMPLATE_MODULES: CHashMap<Field, Module> = CHashMap::new();
comptime mut global TEMPLATE_COMPOSED_TEMPLATE_IDS_BY_MODULE: CHashMap<Module, [Field]> = CHashMap::new();

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
