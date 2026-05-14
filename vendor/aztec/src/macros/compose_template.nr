//! Injection logic for generic contract template composition.
//!
//! This module provides:
//! 1. override validation (`compute_template_override_signatures`)
//! 2. external registry injection with override-aware skipping, using transitive flattening
//! 3. quoted replay of non-overridden composed template functions and event structs

use crate::macros::{
    internals_functions_generation::{external_functions_registry, internal_functions_registry},
    template_registry,
    utils::{compute_fn_selector},
};
use crate::utils::cmap::CHashMap;

comptime fn function_signature_key(f: FunctionDefinition) -> Field {
    compute_fn_selector(f.name(), f.parameters())
}

comptime fn function_name_key(function_name: Quoted) -> Field {
    let function_name_str: str<_> = f"{function_name}".as_quoted_str!();
    let function_name_bytes = function_name_str.as_bytes();
    let mut acc: Field = function_name_bytes.len() as Field + 1;
    for i in 0..function_name_bytes.len() {
        acc = acc * 16777619 + function_name_bytes[i] as Field + 1;
    }
    acc
}

comptime fn function_name_key_from_template_id(function_name: CtString) -> Field {
    let function_name_str: str<_> = function_name.as_quoted_str!();
    let function_name_bytes = function_name_str.as_bytes();
    let mut acc: Field = function_name_bytes.len() as Field + 1;
    for i in 0..function_name_bytes.len() {
        acc = acc * 16777619 + function_name_bytes[i] as Field + 1;
    }
    acc
}

comptime fn contains_field(values: [Field], value: Field) -> bool {
    let mut found = false;
    for existing in values {
        if existing == value {
            found = true;
        }
    }
    found
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
        let template_module = template_module_opt.unwrap();

        if !contains_field(processed, template_key) {
            processed = processed.push_back(template_key);

            let composed_keys_opt = template_registry::get_template_composed_keys(template_key);
            let mut child_template_keys = if composed_keys_opt.is_some() {
                composed_keys_opt.unwrap()
            } else {
                let module_composed_keys_opt = template_registry::get_template_composed_keys_by_module(template_module);
                if module_composed_keys_opt.is_some() {
                    module_composed_keys_opt.unwrap()
                } else {
                    @[]
                }
            };

            for child_key in child_template_keys {
                if !contains_field(processed, child_key) & !contains_field(pending, child_key) {
                    pending = pending.push_back(child_key);
                }
            }
        }

        index += 1;
    }

    processed
}

comptime fn own_external_functions(m: Module) -> [FunctionDefinition] {
    external_functions_registry::get_own_private_functions(m)
        .append(external_functions_registry::get_own_public_functions(m))
        .append(external_functions_registry::get_own_utility_functions(m))
}

comptime fn own_internal_functions(m: Module) -> [FunctionDefinition] {
    internal_functions_registry::get_own_private_functions(m)
        .append(internal_functions_registry::get_own_public_functions(m))
}

comptime fn has_override(
    template_key: Field,
    signature_key: Field,
    override_signatures: [(Field, Field)],
) -> bool {
    let mut matched = false;
    for override_signature in override_signatures {
        let (override_template_key, override_sig_key) = override_signature;
        if (override_template_key == template_key) & (override_sig_key == signature_key) {
            matched = true;
            break;
        }
    }
    matched
}

comptime fn is_template_key_composed(template_keys: [Field], template_key: Field) -> bool {
    let mut found = false;
    for configured_template_key in template_keys {
        if configured_template_key == template_key {
            found = true;
            break;
        }
    }
    found
}

/// Validates override declarations and resolves each override to `(template_key, function_signature_key)` entries.
pub(crate) comptime fn compute_template_override_signatures(
    host: Module,
    template_keys: [Field],
    overrides: [(Field, Field)],
) -> [(Field, Field)] {
    let host_functions = own_external_functions(host);
    let mut host_signature_map = CHashMap::<Field, bool>::new();
    for f in host_functions {
        host_signature_map.insert(function_signature_key(f), true);
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

        let mut matched_template_function: Option<FunctionDefinition> = Option::none();
        for template_function in own_external_functions(template_module) {
            if function_name == function_name_key(template_function.name()) {
                if matched_template_function.is_some() {
                    panic(
                        f"compose: override target '{template_key}' in template {template_key} is ambiguous; overloads require unique function names in overrides"
                    );
                }
                matched_template_function = Option::some(template_function);
            }
        }

        if matched_template_function.is_none() {
            panic(f"compose: override target '{template_key}' not found in template {template_key}");
        }

        let template_fn = matched_template_function.unwrap();
        let override_signature = function_signature_key(template_fn);
        let override_identity = (template_key, override_signature);

        if seen_overrides.get(override_identity).is_some() {
            panic(f"compose: duplicate override for '{template_key}' on template {template_key}");
        }

        if !template_registry::is_template_external_function_virtual(template_key, override_signature) {
            panic(
                f"compose: cannot override '{template_key}' on template {template_key}; mark it with #[template_virtual]"
            );
        }

        if !host_signature_map.get(override_signature).is_some() {
            panic(
                f"compose: override '{template_key}' on template {template_key} requires a host function with the same signature"
            );
        }

        seen_overrides.insert(override_identity, true);
        resolved_overrides = resolved_overrides.push_back(override_identity);
    }

    resolved_overrides
}

/// Validates override declarations for template internal functions and resolves each override to
/// `(template_key, function_signature_key)` entries.
pub(crate) comptime fn compute_template_internal_override_signatures(
    host: Module,
    template_keys: [Field],
    overrides: [(Field, Field)],
) -> [(Field, Field)] {
    let host_functions = own_internal_functions(host);
    let mut host_signature_map = CHashMap::<Field, bool>::new();
    for f in host_functions {
        host_signature_map.insert(function_signature_key(f), true);
    }

    let mut seen_overrides = CHashMap::<(Field, Field), bool>::new();
    let mut resolved_overrides = @[];

    for override_decl in overrides {
        let (template_key, function_name) = override_decl;

        if !is_template_key_composed(template_keys, template_key) {
            panic(
                f"compose: cannot apply internal override for template key {template_key}; call .compose(...) before override_internal_template(...)."
            );
        }

        let template_module_opt = template_registry::get_template_module(template_key);
        assert(
            template_module_opt.is_some(),
            f"compose: no template registered for internal override target {template_key}"
        );
        let template_module = template_module_opt.unwrap();

        let mut matched_template_function: Option<FunctionDefinition> = Option::none();
        for template_function in own_internal_functions(template_module) {
            if function_name == function_name_key(template_function.name()) {
                if matched_template_function.is_some() {
                    panic(
                        f"compose: internal override target '{template_key}' in template {template_key} is ambiguous; overloads require unique function names in overrides"
                    );
                }
                matched_template_function = Option::some(template_function);
            }
        }

        if matched_template_function.is_none() {
            panic(f"compose: internal override target '{template_key}' not found in template {template_key}");
        }

        let template_fn = matched_template_function.unwrap();
        let override_signature = function_signature_key(template_fn);
        let override_identity = (template_key, override_signature);

        if seen_overrides.get(override_identity).is_some() {
            panic(f"compose: duplicate internal override for '{template_key}' on template {template_key}");
        }

        if !template_registry::is_template_internal_function_virtual(template_key, override_signature) {
            panic(
                f"compose: cannot override internal '{template_key}' on template {template_key}; mark it with #[template_virtual]"
            );
        }

        if !host_signature_map.get(override_signature).is_some() {
            panic(
                f"compose: internal override '{template_key}' on template {template_key} requires a host function with the same signature"
            );
        }

        seen_overrides.insert(override_identity, true);
        resolved_overrides = resolved_overrides.push_back(override_identity);
    }

    resolved_overrides
}

pub(crate) comptime fn function_name_key_from_ctstring(function_name: CtString) -> Field {
    function_name_key_from_template_id(function_name)
}

/// Populates composed function registries with template declarations, skipping overridden functions.
pub(crate) comptime fn inject_template_functions_to_registries(
    host: Module,
    template_keys: [Field],
    override_signatures: [(Field, Field)],
    internal_override_signatures: [(Field, Field)],
) {
    let mut host_signature_map = CHashMap::<Field, bool>::new();
    for f in own_external_functions(host) {
        host_signature_map.insert(function_signature_key(f), true);
    }

    let mut host_internal_signature_map = CHashMap::<Field, bool>::new();
    for f in own_internal_functions(host) {
        host_internal_signature_map.insert(function_signature_key(f), true);
    }

    let mut composed_internal_signature_map = CHashMap::<Field, bool>::new();

    for template_key in flatten_template_keys(template_keys) {
        let template_module_opt = template_registry::get_template_module(template_key);
        assert(
            template_module_opt.is_some(),
            "compose: no contract template registered for one of the requested template ids",
        );
        let template_module = template_module_opt.unwrap();

        for f in external_functions_registry::get_own_private_functions(template_module) {
            let signature_key = function_signature_key(f);
            if has_override(template_key, signature_key, override_signatures) {
                continue;
            }
            if host_signature_map.get(signature_key).is_some() {
                panic(
                    "compose: host function selector collision; mark template function as #[template_virtual] and declare .override_template(...)."
                );
            }
            external_functions_registry::add_composed_private(host, f);
        }

        for f in external_functions_registry::get_own_public_functions(template_module) {
            let signature_key = function_signature_key(f);
            if has_override(template_key, signature_key, override_signatures) {
                continue;
            }
            if host_signature_map.get(signature_key).is_some() {
                panic(
                    "compose: host function selector collision; mark template function as #[template_virtual] and declare .override_template(...)."
                );
            }
            external_functions_registry::add_composed_public(host, f);
        }

        for f in external_functions_registry::get_own_utility_functions(template_module) {
            let signature_key = function_signature_key(f);
            if has_override(template_key, signature_key, override_signatures) {
                continue;
            }
            if host_signature_map.get(signature_key).is_some() {
                panic(
                    "compose: host function selector collision; mark template function as #[template_virtual] and declare .override_template(...)."
                );
            }
            external_functions_registry::add_composed_utility(host, f);
        }

        for f in internal_functions_registry::get_own_private_functions(template_module) {
            let signature_key = function_signature_key(f);
            if has_override(template_key, signature_key, internal_override_signatures) {
                continue;
            }
            if host_internal_signature_map.get(signature_key).is_some() {
                panic(
                    "compose: host function selector collision; mark template function as #[template_virtual] and declare .override_internal_template(...)."
                );
            }
            if composed_internal_signature_map.get(signature_key).is_some() {
                panic(
                    "compose: host function selector collision; two internal templates expose the same selector"
                );
            }
            composed_internal_signature_map.insert(signature_key, true);
            internal_functions_registry::add_composed_private(host, f);
        }
        for f in internal_functions_registry::get_own_public_functions(template_module) {
            let signature_key = function_signature_key(f);
            if has_override(template_key, signature_key, internal_override_signatures) {
                continue;
            }
            if host_internal_signature_map.get(signature_key).is_some() {
                panic(
                    "compose: host function selector collision; mark template function as #[template_virtual] and declare .override_internal_template(...)."
                );
            }
            if composed_internal_signature_map.get(signature_key).is_some() {
                panic(
                    "compose: host function selector collision; two internal templates expose the same selector"
                );
            }
            composed_internal_signature_map.insert(signature_key, true);
            internal_functions_registry::add_composed_public(host, f);
        }
    }
}

/// Returns composed quoted code for all non-overridden template entries.
/// Includes internal helpers, contract-library methods and event structs from composed templates.
pub(crate) comptime fn get_composed_templates_quoted(
    template_keys: [Field],
    override_signatures: [(Field, Field)],
    internal_override_signatures: [(Field, Field)],
) -> (Quoted, Quoted, Quoted) {
    let mut all_functions = quote {};
    let mut all_abi_exports = quote {};
    let mut all_events = quote {};
    let template_keys = flatten_template_keys(template_keys);

    for template_key in template_keys {
        let template_module_opt = template_registry::get_template_module(template_key);
        assert(
            template_module_opt.is_some(),
            "compose: no contract template registered for one of the requested template ids",
        );

        let template_module = template_module_opt.unwrap();
        let template_functions_opt = template_registry::get_template_functions(template_key);
        let template_contract_library_methods_opt =
            template_registry::get_template_contract_library_methods(template_key);
        let events_opt = template_registry::get_template_events(template_key);
        assert(
            template_functions_opt.is_some(),
            "compose: template functions are missing in registry; ensure #[contract_template] runs before composition",
        );
        let template_functions = template_functions_opt.unwrap();
        let template_contract_library_methods = template_contract_library_methods_opt.unwrap_or(quote {});
        let events = if events_opt.is_some() { events_opt.unwrap() } else { quote {} };

        all_functions = quote {
            $all_functions
            $template_functions
            $template_contract_library_methods
        };
        all_events = quote {
            $all_events
            $events
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
                f"compose: no replay payload for template function in {template_key}"
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

        for template_function in own_internal_functions(template_module) {
            let signature_key = function_signature_key(template_function);
            if has_override(template_key, signature_key, internal_override_signatures) {
                continue;
            }

            let internal_wrapper_opt = template_registry::get_template_internal_function(template_key, signature_key);
            assert(
                internal_wrapper_opt.is_some(),
                f"compose: no replay payload for template internal function in {template_key}"
            );
            let internal_wrapper = internal_wrapper_opt.unwrap();

            all_functions = quote {
                $all_functions
                $internal_wrapper
            };
        }
    }

    (all_functions, all_abi_exports, all_events)
}
