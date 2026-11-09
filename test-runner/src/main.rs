//! Runs each module's test cases with the Rhai engine, the way the Neblex test flow does:
//! the module's functions are available to the harness script, `item` is one test case, and
//! the script returns a map with `pass`. Every module is run on its own, then all modules are
//! loaded together, which catches two modules defining the same function differently.
//!
//! Usage (from the repository root): cargo run --release --manifest-path test-runner/Cargo.toml

use rhai::{Dynamic, Engine, Scope, AST};
use serde_json::Value;
use std::{fs, path::Path, process::ExitCode};

fn main() -> ExitCode {
    let mut modules: Vec<String> = fs::read_dir(".")
        .expect("run from the repository root")
        .filter_map(|e| e.ok())
        .map(|e| e.file_name().to_string_lossy().into_owned())
        .filter(|name| Path::new(name).join(format!("{name}.rhai")).is_file() && Path::new(name).join("test/cases.json").is_file())
        .collect();
    modules.sort();
    if modules.is_empty() {
        eprintln!("no modules found (expected <module>/<module>.rhai and <module>/test/cases.json)");
        return ExitCode::FAILURE;
    }

    let engine = Engine::new();
    let compile = |path: &Path| -> AST {
        let src = fs::read_to_string(path).unwrap_or_else(|e| panic!("{}: {e}", path.display()));
        engine.compile(&src).unwrap_or_else(|e| panic!("{}: {e}", path.display()))
    };
    let libs: Vec<(String, AST)> = modules.iter().map(|m| (m.clone(), compile(&Path::new(m).join(format!("{m}.rhai"))))).collect();
    let all = libs.iter().fold(AST::empty(), |acc, (_, ast)| acc.merge(ast));

    let mut failed = 0;
    let mut total = 0;
    for setup in ["alone", "together"] {
        for (m, lib) in &libs {
            let base = if setup == "alone" { lib.clone() } else { all.clone() };
            // The harness's own statements run after the module's function definitions.
            let script = base.merge(&compile(&Path::new(m).join("test/harness-script.rhai")));
            let cases: Value = serde_json::from_str(&fs::read_to_string(Path::new(m).join("test/cases.json")).unwrap()).unwrap();
            let cases = cases.get("cases").and_then(Value::as_array).cloned().unwrap_or_default();
            let mut module_failed = 0;
            for (i, case) in cases.iter().enumerate() {
                total += 1;
                let mut scope = Scope::new();
                scope.push("item", rhai::serde::to_dynamic(case).unwrap());
                let outcome = engine.eval_ast_with_scope::<Dynamic>(&mut scope, &script);
                let pass = match &outcome {
                    Ok(r) => r.clone().try_cast::<rhai::Map>().and_then(|map| map.get("pass").and_then(|p| p.as_bool().ok())).unwrap_or(false),
                    Err(_) => false,
                };
                if !pass {
                    module_failed += 1;
                    let got = match outcome {
                        Ok(r) => r.try_cast::<rhai::Map>().and_then(|map| map.get("got").map(|g| g.to_string())).unwrap_or_default(),
                        Err(e) => format!("error: {e}"),
                    };
                    println!("FAIL {m} ({setup}) case {i}: {case} -> got {got}");
                }
            }
            println!("{} {m} ({setup}): {}/{} passed", if module_failed == 0 { "ok  " } else { "FAIL" }, cases.len() - module_failed, cases.len());
            failed += module_failed;
        }
    }
    println!("{} of {total} case runs passed", total - failed);
    if failed == 0 {
        ExitCode::SUCCESS
    } else {
        ExitCode::FAILURE
    }
}
