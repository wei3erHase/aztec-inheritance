//! Injection logic for generic contract template composition.
//!
//! This module provides two things:
//!
//! 1. `compute_template_override_signatures` validates override declarations and translates them into
//!    `(template_key, function_signature)` pairs for later filtering.
//! 2. `inject_template_functions_to_registries` injects template function declarations into host registries,
//!    while skipping overridden external functions.
//! 3. `get_composed_templates_quoted` replays non-overridden template quoteds into host output.

use crate::macros::{
    internals_functions_generation::{external_functions_registry, internal_functions_registry},
    template_registry,
    utils::{compute_fn_selector},
};
use crate::utils::cmap::CHashMap;

fn function_signature_key(f: FunctionDefinition) -> Field {
    compute_fn_selector(f.name(), f.parameters())
}

fn own_external_functions(m: Module) -> [FunctionDefinition] {
    external_functions_registry::get_own_private_functions(m)
        .append(external_functions_registry::get_own_public_functions(m))
        .append(external_functions_registry::get_own_utility_functions(m))
}

fn has_override(
    template_key: Field,
    signature_key: Field,
    override_signatures: [(Field, Field)],
) -> bool {
    let mut matched = false;
    for override_signature in override_signatures {
        let (override_template_key, override_sig_key) = override_signature;
        if override_template_key == template_key & override_sig_key == signature_key {
            matched = true;
            break;
        }
    }
    matched
}

fn is_template_key_composed(template_keys: [Field], template_key: Field) -> bool {
    let mut found = false;
    for configured_template_key in template_keys {
        if configured_template_key == template_key {
            found = true;
            break;
        }
    }
    found
}

/// Computes a canonical list of overrides for this host and validates each declaration.
pub(crate) comptime fn compute_template_override_signatures(
    host: Module,
    template_keys: [Field],
    overrides: [(Field, CtString)],
) -> [(Field, Field)] {
    let host_functions = own_external_functions(host);
    let mut host_signature_map = CHashMap::<Field, bool>::new();
    for f in host_functions {
        let signature_key = function_signature_key(f);
        host_signature_map.insert(signature_key, true);
    }

    let mut seen_overrides = CHashMap::<(Field, Field), bool>::new();
    let mut resolved_overrides = @[];

    for override_decl in overrides {
        let (template_key, function_name) = override_decl;
        if !is_template_key_composed(template_keys, template_key) {
            panic(
                f"compose: cannot apply override for template key {template_key}; call .compose(...) before override_template(...)."
            );
        }

        let template_module_opt = template_registry::get_template_module(template_key);
        assert(
            template_module_opt.is_some(),
            f"compose: no template registered for override target {template_key}"
        );
        let template_module = template_module_opt.unwrap();

        let template_functions = own_external_functions(template_module);
        let mut matches = @[];

        for template_function in template_functions {
            if template_function.name() == function_name {
                matches = matches.push_back(template_function);
            }
        }

        if matches.len() == 0 {
            panic(
                f"compose: override target '{function_name}' not found in template {template_key}"
            );
        }

        if matches.len() > 1 {
            panic(
                f"compose: override target '{function_name}' in template {template_key} is ambiguous; overloads require unique function names in overrides"
            );
        }

        let template_fn = matches[0];
        let override_signature = function_signature_key(template_fn);
        let override_identity = (template_key, override_signature);

        if seen_overrides.get(override_identity).is_some() {
            panic(
                f"compose: duplicate override for function '{function_name}' on template key {template_key}"
            );
        }

        if !template_registry::is_template_external_function_virtual(template_key, override_signature) {
            panic(
                f"compose: cannot override '{function_name}' on template {template_key}; mark it with #[template_virtual]"
            );
        }

        if !host_signature_map.get(override_signature).is_some() {
            panic(
                f"compose: override '{function_name}' on template {template_key} requires a host function with the same signature"
            );
        }

        seen_overrides.insert(override_identity, true);
        resolved_overrides = resolved_overrides.push_back(override_identity);
    }

    resolved_overrides
}

/// Populates the host module's composed registries with selected templates' own function declarations.
pub(crate) comptime fn inject_template_functions_to_registries(
    host: Module,
    template_keys: [Field],
    override_signatures: [(Field, Field)],
) {
    let mut host_signature_map = CHashMap::<Field, bool>::new();
    for f in own_external_functions(host) {
        let signature_key = function_signature_key(f);
        host_signature_map.insert(signature_key, true);
    }

    for template_key in template_keys {
        let template_module_opt = template_registry::get_template_module(template_key);
        assert(
            template_module_opt.is_some(),
            "compose: no contract template registered for one of the requested template ids",
        );

        let template_module = template_module_opt.unwrap();
        let template_functions = own_external_functions(template_module);

        for f in template_functions {
            let signature_key = function_signature_key(f);
            if has_override(template_key, signature_key, override_signatures) {
                continue;
            }

            if host_signature_map.get(signature_key).is_some() {
                panic(
                    f"compose: host function selector collision on '{f.name()}'; to override, mark template function as #[template_virtual] and call .override_template(..., \"{f.name()}\")"
                );
            }

            if f.is_private() {
                external_functions_registry::add_composed_private(host, f);
            } else if f.is_public() {
                external_functions_registry::add_composed_public(host, f);
            } else {
                external_functions_registry::add_composed_utility(host, f);
            }
        }

        // Inject internal function definitions into the host's composed registries.
        // These are used by generate_call_internal_struct.
        for f in internal_functions_registry::get_own_private_functions(template_module) {
            internal_functions_registry::add_composed_private(host, f);
        }
        for f in internal_functions_registry::get_own_public_functions(template_module) {
            internal_functions_registry::add_composed_public(host, f);
        }
    }
}

/// Returns the pre-generated code for all selected composed template functions, excluding overridden entries.
/// - `functions`: `__aztec_nr_internals__` wrappers for non-overridden externals plus internal wrappers/library methods
/// - `abi_exports`: ABI export structs for non-overridden externals
/// - `_self_call_structs`: always empty (host-generated path handles this)
pub(crate) comptime fn get_composed_templates_quoted(
    template_keys: [Field],
    override_signatures: [(Field, Field)],
) -> (Quoted, Quoted, Quoted) {
    let mut all_functions = quote {};
    let mut all_abi_exports = quote {};

    for template_key in template_keys {
        let template_module_opt = template_registry::get_template_module(template_key);
        assert(
            template_module_opt.is_some(),
            "compose: no contract template registered for one of the requested template ids",
        );

        let template_module = template_module_opt.unwrap();
        let template_non_external_functions_opt = template_registry::get_template_functions(template_key);
        assert(
            template_non_external_functions_opt.is_some(),
            "compose: template functions are missing in registry; ensure #[contract_template] runs before composition",
        );
        let template_non_external_functions = template_non_external_functions_opt.unwrap();

        all_functions = quote {
            $all_functions
            $template_non_external_functions
        };

        for template_function in own_external_functions(template_module) {
            let signature_key = function_signature_key(template_function);
            if has_override(template_key, signature_key, override_signatures) {
                continue;
            }

            let wrapper_opt = template_registry::get_template_external_function_wrapper(template_key, signature_key);
            let abi_opt = template_registry::get_template_external_function_abi_export(template_key, signature_key);
            assert(
                wrapper_opt.is_some() & abi_opt.is_some(),
                f"compose: no replay payload for overridden template entry in {template_key}",
            );

            let wrapper = wrapper_opt.unwrap();
            let abi = abi_opt.unwrap();

            all_functions = quote {
                $all_functions
                $wrapper
            };
            all_abi_exports = quote {
                $all_abi_exports
                $abi
            };
        }
    }

    (all_functions, all_abi_exports, quote {})
}
