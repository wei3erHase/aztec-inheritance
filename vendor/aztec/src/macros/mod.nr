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

comptime fn function_signature_key(f: FunctionDefinition) -> Field {
    crate::macros::utils::compute_fn_selector(f.name(), f.parameters())
}

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

comptime fn quote_event_struct(event_struct: TypeDefinition) -> Quoted {
    let struct_name = event_struct.name();
    let fields = event_struct.fields_as_written().map(|field| {
        let (name, typ, _) = field;
        quote { $name: $typ }
    }).join(quote {,});

    quote {
        #[aztec::macros::events::event]
        struct $struct_name {
            $fields
        }
    }
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
    let template_key = template_registry::template_key(template_id);

    // Pre-generate all external function wrappers.
    let private_fns = external_functions_registry::get_private_functions(m);
    let public_fns = external_functions_registry::get_public_functions(m);
    let utility_fns = external_functions_registry::get_utility_functions(m);

    for f in private_fns {
        let wrapper = generate_private_external(f);
        let abi = create_fn_abi_export(f);
        template_registry::register_external_function(
            template_key,
            function_signature_key(f),
            wrapper,
            abi,
            f.has_named_attribute("template_virtual"),
        );
    }

    for f in public_fns {
        let wrapper = generate_public_external(f);
        let abi = create_fn_abi_export(f);
        template_registry::register_external_function(
            template_key,
            function_signature_key(f),
            wrapper,
            abi,
            f.has_named_attribute("template_virtual"),
        );
    }

    for f in utility_fns {
        let wrapper = generate_utility_external(f);
        let abi = create_fn_abi_export(f);
        template_registry::register_external_function(
            template_key,
            function_signature_key(f),
            wrapper,
            abi,
            f.has_named_attribute("template_virtual"),
        );
    }


    // Pre-generate all internal function wrappers.
    let priv_internal_fns = internal_functions_registry::get_private_functions(m);
    let pub_internal_fns = internal_functions_registry::get_public_functions(m);

    for f in priv_internal_fns {
        let generated = generate_private_internal(f);
        template_registry::register_internal_function(
            template_key,
            function_signature_key(f),
            generated,
            f.has_named_attribute("template_virtual"),
        );
    }

    for f in pub_internal_fns {
        let generated = generate_public_internal(f);
        template_registry::register_internal_function(
            template_key,
            function_signature_key(f),
            generated,
            f.has_named_attribute("template_virtual"),
        );
    }

    // Pre-generate ABI export structs.
    let mut all_abi_exports = quote {};

    for f in private_fns {
        let generated = create_fn_abi_export(f);
        all_abi_exports = quote { $all_abi_exports $generated };
    }

    for f in public_fns {
        let generated = create_fn_abi_export(f);
        all_abi_exports = quote { $all_abi_exports $generated };
    }

    for f in utility_fns {
        let generated = create_fn_abi_export(f);
        all_abi_exports = quote { $all_abi_exports $generated };
    }

    let mut all_contract_library_methods = quote {};

    for f in m.functions().filter(|f| is_fn_contract_library_method(f)) {
        let generated = generate_contract_library_method_quote(f);
        all_contract_library_methods = quote { $all_contract_library_methods $generated };
    }

    let template_events = m.structs().filter(|s| s.has_named_attribute("event")).map(|s| quote_event_struct(s)).join(quote {});

    template_registry::register_template(
        template_id,
        quote {},
        all_abi_exports,
        all_contract_library_methods,
        template_events,
        m,
    );
    quote {}
}
