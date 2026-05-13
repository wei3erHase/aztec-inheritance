//! Injection logic for generic contract template composition.
//!
//! This module provides two things:
//!
//! 1. `inject_template_functions_to_registries(host, template_ids)`: Populates the composed
//!    registries with template FunctionDefinitions. This enables
//!    `generate_external_function_calls(host)`, `generate_external_function_self_calls_structs(host)`,
//!    and `generate_call_internal_struct(host)` to include composed functions in the host module's
//!    interface/stubs. These operations do NOT call `f.body()`, so they work cross-crate.
//!    Transitive injection: if a directly composed template itself composes other templates,
//!    those transitive templates are also injected automatically.
//!
//! 2. `get_composed_templates_quoted(template_ids)`: Returns the pre-generated Quoted code (stored
//!    by `#[contract_template(...)]`) for the `__aztec_nr_internals__` wrappers, ABI
//!    export structs, and contract library helpers. This avoids the Noir cross-crate `f.body()`
//!    limitation since the bodies were captured in the template crate.

use crate::macros::{
    internals_functions_generation::{external_functions_registry, internal_functions_registry},
    template_registry,
};
use crate::utils::cmap::CHashMap;

comptime fn contains_field(values: [Field], value: Field) -> bool {
    for existing in values {
        if existing == value {
            return true;
        }
    }
    false
}

comptime fn get_template_overrides_or_empty(
    template_overrides: CHashMap<Field, [Field]>,
    template_key: Field,
) -> [Field] {
    let overrides = template_overrides.get(template_key);
    if overrides.is_some() {
        overrides.unwrap()
    } else {
        @[]
    }
}

comptime fn validate_template_overrides(
    template_key: Field,
    template_overrides: [Field],
) -> [Field] {
    let template_function_keys = template_registry::get_template_function_keys(template_key);
    assert(
        template_function_keys.is_some(),
        "compose: no function metadata registered for one of the composed templates",
    );
    let template_virtual_function_keys = template_registry::get_template_virtual_function_keys(template_key);
    assert(
        template_virtual_function_keys.is_some(),
        "compose: no virtual-function metadata registered for one of the composed templates",
    );

    let template_function_keys = template_function_keys.unwrap();
    let template_virtual_function_keys = template_virtual_function_keys.unwrap();

    for override_key in template_overrides {
        assert(
            contains_field(template_function_keys, override_key),
            "compose: override_template target does not exist in composed template",
        );
        assert(
            contains_field(template_virtual_function_keys, override_key),
            "compose: override_template target is not marked #[template_virtual]",
        );
    }

    template_overrides
}

// Returns all template ids reachable from `template_keys`, preserving first-seen order and
// deduplicating entries as they are discovered.
comptime fn flatten_template_keys(template_keys: [Field]) -> [Field] {
    let mut pending = template_keys;
    let mut processed = @[];

    let mut index = 0;
    while index < pending.len() {
        let template_key = pending[index];
        let template_module_opt = template_registry::get_template_module(template_key);
        assert(
            template_module_opt.is_some(),
            "compose: no contract template registered for one of the requested template ids",
        );

        if !contains_field(processed, template_key) {
            processed = processed.push_back(template_key);

            if let Some(composed_keys) = template_registry::get_template_composed_keys(template_key) {
                for child_key in composed_keys {
                    if !contains_field(processed, child_key) {
                        pending = pending.push_back(child_key);
                    }
                }
            }
        }

        index += 1;
    }

    processed
}

/// Injects one template's own FunctionDefinitions into the host's composed registries.
comptime fn inject_one_template_functions(
    host: Module,
    template_module: Module,
    template_overrides: [Field],
) {
    // Inject external function definitions into the host's composed registries.
    // These are used by generate_external_function_calls and generate_external_function_self_calls_structs.
    for f in external_functions_registry::get_own_private_functions(template_module) {
        let function_key = template_registry::function_name_key(f.name());
        if !contains_field(template_overrides, function_key) {
            external_functions_registry::add_composed_private(host, f);
        }
    }
    for f in external_functions_registry::get_own_public_functions(template_module) {
        let function_key = template_registry::function_name_key(f.name());
        if !contains_field(template_overrides, function_key) {
            external_functions_registry::add_composed_public(host, f);
        }
    }
    for f in external_functions_registry::get_own_utility_functions(template_module) {
        let function_key = template_registry::function_name_key(f.name());
        if !contains_field(template_overrides, function_key) {
            external_functions_registry::add_composed_utility(host, f);
        }
    }

    // Inject internal function definitions into the host's composed registries.
    // These are used by generate_call_internal_struct.
    for f in internal_functions_registry::get_own_private_functions(template_module) {
        let function_key = template_registry::function_name_key(f.name());
        if !contains_field(template_overrides, function_key) {
            internal_functions_registry::add_composed_private(host, f);
        }
    }
    for f in internal_functions_registry::get_own_public_functions(template_module) {
        let function_key = template_registry::function_name_key(f.name());
        if !contains_field(template_overrides, function_key) {
            internal_functions_registry::add_composed_public(host, f);
        }
    }
}

/// Populates the host module's composed registries with the selected templates'
/// FunctionDefinitions. This enables the interface/stub generators to include composed functions
/// without accessing function bodies (no cross-crate limitation applies here).
pub(crate) comptime fn inject_template_functions_to_registries(
    host: Module,
    template_keys: [Field],
    template_overrides: CHashMap<Field, [Field]>,
) {
    for template_key in flatten_template_keys(template_keys) {
        let template_module_opt = template_registry::get_template_module(template_key);
        assert(
            template_module_opt.is_some(),
            "compose: no contract template registered for one of the requested template ids",
        );

        let overrides_for_template =
            validate_template_overrides(template_key, get_template_overrides_or_empty(template_overrides, template_key));

        inject_one_template_functions(host, template_module_opt.unwrap(), overrides_for_template);
    }
}

/// Returns the pre-generated Quoted code for all selected composed template functions:
/// - `functions`: all `__aztec_nr_internals__` wrappers (private, public, utility, internal) plus
///   contract library helpers referenced by them.
/// - `abi_exports`: all ABI export parameter/abi structs.
/// - `_self_call_structs`: Always empty (the host's `generate_external_function_self_calls_structs`
///   covers them via the composed registries).
///
/// Panics if any requested template id has not been registered.
pub(crate) comptime fn get_composed_templates_quoted(
    template_keys: [Field],
    template_overrides: CHashMap<Field, [Field]>,
) -> (Quoted, Quoted, Quoted) {
    let mut all_functions = quote {};
    let mut all_abi_exports = quote {};
    let template_keys = flatten_template_keys(template_keys);

    for template_key in template_keys {
        let overrides_for_template =
            validate_template_overrides(template_key, get_template_overrides_or_empty(template_overrides, template_key));

        let functions_opt = template_registry::get_template_functions_by_key(template_key);
        let abi_exports_opt = template_registry::get_template_abi_exports_by_key(template_key);
        let contract_library_methods_opt =
            template_registry::get_template_contract_library_methods_by_key(template_key);

        let functions = if functions_opt.is_some() { functions_opt.unwrap() } else { @[] };
        let abi_exports = if abi_exports_opt.is_some() { abi_exports_opt.unwrap() } else { @[] };
        let contract_library_methods =
            if contract_library_methods_opt.is_some() { contract_library_methods_opt.unwrap() } else { @[] };

        let mut template_functions = quote {};
        let mut template_abi_exports = quote {};
        let mut template_contract_library_methods = quote {};

        for (function_key, function_quote) in functions {
            if !contains_field(overrides_for_template, function_key) {
                template_functions = quote {
                    $template_functions
                    $function_quote
                };
            }
        }

        for (function_key, abi_quote) in abi_exports {
            if !contains_field(overrides_for_template, function_key) {
                template_abi_exports = quote {
                    $template_abi_exports
                    $abi_quote
                };
            }
        }

        for (function_key, library_method_quote) in contract_library_methods {
            if !contains_field(overrides_for_template, function_key) {
                template_contract_library_methods = quote {
                    $template_contract_library_methods
                    $library_method_quote
                };
            }
        }

        all_functions = quote {
            $all_functions
            $template_contract_library_methods
            $template_functions
        };
        all_abi_exports = quote {
            $all_abi_exports
            $template_abi_exports
        };
    }

    (all_functions, all_abi_exports, quote {})
}
