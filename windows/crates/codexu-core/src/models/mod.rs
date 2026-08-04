//! Core domain models for codexU.
//!
//! These models are direct translations of the Swift structs in the macOS version.
//! They must remain semantically compatible so that the Windows UI can consume
//! the same JSON shape produced by `codexU --dump-json` on macOS.

pub mod leadership;
pub mod runtime;
pub mod usage;

pub use leadership::*;
pub use runtime::*;
pub use usage::*;
