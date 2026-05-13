//! Definition of Aztec contract functions, storage, notes and events.

mod aztec;
pub use aztec::{aztec, AztecConfig};

pub mod dispatch;
pub(crate) mod calls_generation;
pub(crate) mod emit_public_init_nullifier;
pub mod internals_functions_generation;
pub mod functions;
pub mod utils;
pub mod notes;
pub mod storage;
pub mod events;
pub mod authorization;
pub(crate) mod compose_template;
pub(crate) mod template_registry;

use internals_functions_generation::{
    abi_export::create_fn_abi_export,
    external::{
        private::generate_private_external, public::generate_public_external,
        utility::generate_utility_external,
    },
    external_functions_registry,
    internal::{generate_private_internal, generate_public_internal},
    internal_functions_registry,
};
use utils::is_fn_contract_library_method;

comptime fn generate_contract_library_method_quote(f: FunctionDefinition) -> Quoted {
    let name = f.name();
    let visibility = f.visibility();
    let params = f.parameters();
    let parameters = params.map(|(param_name, typ): (Quoted, Type)| quote {
        $param_name: $typ
    }).join(quote {,});
    let arguments = params.map(|(param_name, _): (Quoted, Type)| param_name).join(quote {,});
    let return_type = f.return_type();
    let return_clause = if return_type.is_unit() { quote {} } else { quote { -> $return_type } };
    let unconstrained_kw = if f.is_unconstrained() { quote { unconstrained } } else { quote {} };
    let function_ref = f.as_typed_expr();

    quote {
        #[contract_library_method]
        $visibility $unconstrained_kw fn $name($parameters)$return_clause {
            $function_ref($arguments)
        }
    }
}

comptime fn contains_field(values: [Field], value: Field) -> bool {
    for existing in values {
        if existing == value {
            return true;
        }
    }
    false
}

/// Registers a contract module as a named composition template.
///
/// Apply this attribute to any template contract so that
/// `#[aztec(AztecConfig::new().compose("template-id"))]` can locate and copy its functions into
/// any host contract.
///
/// This macro pre-generates all `__aztec_nr_internals__` function wrappers and ABI export structs
/// for the template contract's functions, storing the resulting `Quoted` in the global registry so
/// that the cross-crate `f.body()` limitation is avoided at injection time.
pub comptime fn contract_template(m: Module, template_id: CtString) -> Quoted {
    // Pre-generate all external function wrappers.
    let private_fns = external_functions_registry::get_private_functions(m);
    let public_fns = external_functions_registry::get_public_functions(m);
    let utility_fns = external_functions_registry::get_utility_functions(m);

    // Pre-generate all internal function wrappers.
    let priv_internal_fns = internal_functions_registry::get_private_functions(m);
    let pub_internal_fns = internal_functions_registry::get_public_functions(m);

    let mut all_functions = quote {};
    let mut functions_by_key: [(Field, Quoted)] = @[];
    let mut all_function_keys: [Field] = @[];
    let mut virtual_function_keys: [Field] = @[];

    for f in private_fns {
        let key = template_registry::function_name_key(f.name());
        let generated = generate_private_external(f);
        all_functions = quote { $all_functions $generated };
        functions_by_key = functions_by_key.push_back((key, generated));
        all_function_keys = if contains_field(all_function_keys, key) {
            all_function_keys
        } else {
            all_function_keys.push_back(key)
        };
        if f.has_named_attribute("template_virtual") {
            virtual_function_keys = if contains_field(virtual_function_keys, key) {
                virtual_function_keys
            } else {
                virtual_function_keys.push_back(key)
            };
        }
    }

    for f in public_fns {
        let key = template_registry::function_name_key(f.name());
        let generated = generate_public_external(f);
        all_functions = quote { $all_functions $generated };
        functions_by_key = functions_by_key.push_back((key, generated));
        all_function_keys = if contains_field(all_function_keys, key) {
            all_function_keys
        } else {
            all_function_keys.push_back(key)
        };
        if f.has_named_attribute("template_virtual") {
            virtual_function_keys = if contains_field(virtual_function_keys, key) {
                virtual_function_keys
            } else {
                virtual_function_keys.push_back(key)
            };
        }
    }

    for f in utility_fns {
        let key = template_registry::function_name_key(f.name());
        let generated = generate_utility_external(f);
        all_functions = quote { $all_functions $generated };
        functions_by_key = functions_by_key.push_back((key, generated));
        all_function_keys = if contains_field(all_function_keys, key) {
            all_function_keys
        } else {
            all_function_keys.push_back(key)
        };
        if f.has_named_attribute("template_virtual") {
            virtual_function_keys = if contains_field(virtual_function_keys, key) {
                virtual_function_keys
            } else {
                virtual_function_keys.push_back(key)
            };
        }
    }

    for f in priv_internal_fns {
        let key = template_registry::function_name_key(f.name());
        let generated = generate_private_internal(f);
        all_functions = quote { $all_functions $generated };
        functions_by_key = functions_by_key.push_back((key, generated));
        all_function_keys = if contains_field(all_function_keys, key) {
            all_function_keys
        } else {
            all_function_keys.push_back(key)
        };
        if f.has_named_attribute("template_virtual") {
            virtual_function_keys = if contains_field(virtual_function_keys, key) {
                virtual_function_keys
            } else {
                virtual_function_keys.push_back(key)
            };
        }
    }

    for f in pub_internal_fns {
        let key = template_registry::function_name_key(f.name());
        let generated = generate_public_internal(f);
        all_functions = quote { $all_functions $generated };
        functions_by_key = functions_by_key.push_back((key, generated));
        all_function_keys = if contains_field(all_function_keys, key) {
            all_function_keys
        } else {
            all_function_keys.push_back(key)
        };
        if f.has_named_attribute("template_virtual") {
            virtual_function_keys = if contains_field(virtual_function_keys, key) {
                virtual_function_keys
            } else {
                virtual_function_keys.push_back(key)
            };
        }
    }

    // Pre-generate ABI export structs.
    let mut all_abi_exports = quote {};
    let mut abi_exports_by_key: [(Field, Quoted)] = @[];

    for f in private_fns {
        let key = template_registry::function_name_key(f.name());
        let generated = create_fn_abi_export(f);
        all_abi_exports = quote { $all_abi_exports $generated };
        abi_exports_by_key = abi_exports_by_key.push_back((key, generated));
    }

    for f in public_fns {
        let key = template_registry::function_name_key(f.name());
        let generated = create_fn_abi_export(f);
        all_abi_exports = quote { $all_abi_exports $generated };
        abi_exports_by_key = abi_exports_by_key.push_back((key, generated));
    }

    for f in utility_fns {
        let key = template_registry::function_name_key(f.name());
        let generated = create_fn_abi_export(f);
        all_abi_exports = quote { $all_abi_exports $generated };
        abi_exports_by_key = abi_exports_by_key.push_back((key, generated));
    }

    let mut all_contract_library_methods = quote {};
    let mut contract_library_methods_by_key: [(Field, Quoted)] = @[];

    for f in m.functions().filter(|f| is_fn_contract_library_method(f)) {
        let key = template_registry::function_name_key(f.name());
        let generated = generate_contract_library_method_quote(f);
        all_contract_library_methods = quote { $all_contract_library_methods $generated };
        contract_library_methods_by_key = contract_library_methods_by_key.push_back((key, generated));
        all_function_keys = if contains_field(all_function_keys, key) {
            all_function_keys
        } else {
            all_function_keys.push_back(key)
        };
        if f.has_named_attribute("template_virtual") {
            virtual_function_keys = if contains_field(virtual_function_keys, key) {
                virtual_function_keys
            } else {
                virtual_function_keys.push_back(key)
            };
        }
    }

    template_registry::register_template(
        template_id,
        all_functions,
        all_abi_exports,
        all_contract_library_methods,
        m,
        functions_by_key,
        abi_exports_by_key,
        contract_library_methods_by_key,
        virtual_function_keys,
        all_function_keys,
    );
    quote {}
}
