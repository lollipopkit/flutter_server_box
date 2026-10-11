//! `linux::parse_cpu_brand` against /proc/cpuinfo as the command keeps it and
//! as the monitor agent reads it whole (#1685).

use sbm_parser::linux::parse_cpu_brand;

fn brands(raw: &str) -> Vec<(String, u32)> {
    parse_cpu_brand(raw)
}

fn owned(expected: &[(&str, u32)]) -> Vec<(String, u32)> {
    expected.iter().map(|(n, c)| (n.to_string(), *c)).collect()
}

/// An arm64 server: no `model name` at all. `lscpu` says `Neoverse-N1`.
#[test]
fn arm64_without_a_model_name_is_named_by_its_part() {
    let expected = owned(&[("Neoverse-N1", 4)]);
    assert_eq!(
        brands(include_str!("fixtures/cpuinfo_neoverse_n1_grep.txt")),
        expected
    );
    assert_eq!(
        brands(include_str!("fixtures/cpuinfo_neoverse_n1.txt")),
        expected
    );
}

/// big.LITTLE (an RK3588's layout): each kind of core counted on its own.
#[test]
fn each_kind_of_core_is_counted() {
    let mut raw = String::new();
    for (n, part) in [0xd05, 0xd05, 0xd05, 0xd05, 0xd0b, 0xd0b, 0xd0b, 0xd0b]
        .into_iter()
        .enumerate()
    {
        raw.push_str(&format!(
            "processor\t: {n}\nCPU implementer\t: 0x41\nCPU part\t: 0x{part:03x}\n"
        ));
    }
    assert_eq!(
        brands(&raw),
        owned(&[("Cortex-A55", 4), ("Cortex-A76", 4)])
    );
}

/// The made-up `model name` of an ARM kernel gives way to the part.
#[test]
fn a_generic_arm_model_name_gives_way_to_the_part() {
    let raw = "processor\t: 0\nmodel name\t: ARMv8 Processor rev 4 (v8l)\n\
               CPU implementer\t: 0x41\nCPU part\t: 0xd08\n\
               processor\t: 1\nmodel name\t: AArch64 Processor rev 4 (aarch64)\n\
               CPU implementer\t: 0x41\nCPU part\t: 0xd08\n";
    assert_eq!(brands(raw), owned(&[("Cortex-A72", 2)]));
}

/// Another vendor's core carries its name; one the table does not know
/// keeps its id, so two unknown kinds still read as two.
#[test]
fn other_vendors_and_unknown_parts() {
    let raw = "processor\t: 0\nCPU implementer\t: 0x70\nCPU part\t: 0x662\n\
               processor\t: 1\nCPU implementer\t: 0x48\nCPU part\t: 0xd01\n\
               processor\t: 2\nCPU implementer\t: 0x41\nCPU part\t: 0xfff\n\
               processor\t: 3\nCPU implementer\t: 0xee\nCPU part\t: 0x001\n";
    assert_eq!(
        brands(raw),
        owned(&[
            ("Phytium FTC662", 1),
            ("HiSilicon Kunpeng-920", 1),
            ("ARM 0xfff", 1),
            ("0xee 0x001", 1),
        ])
    );
}

/// A `model name` that names the CPU wins over the table.
#[test]
fn a_real_model_name_is_kept() {
    let raw = "processor\t: 0\nmodel name\t: Phytium FT-2000/4\n\
               CPU implementer\t: 0x70\nCPU part\t: 0x662\n";
    assert_eq!(brands(raw), owned(&[("Phytium FT-2000/4", 1)]));

    let raw = "processor\t: 0\nmodel name\t: AMD Ryzen 9 5900X 12-Core Processor\n\
               processor\t: 1\nmodel name\t: AMD Ryzen 9 5900X 12-Core Processor\n";
    assert_eq!(
        brands(raw),
        owned(&[("AMD Ryzen 9 5900X 12-Core Processor", 2)])
    );
}

/// The issue's machine, as the command's older form printed it: `model name`
/// lines alone. The two revisions stay two entries.
#[test]
fn model_name_lines_alone_still_count() {
    let raw = "model name\t: ARMv8 Processor rev 4 (v81)\n\
               model name\t: ARMv8 Processor rev 4 (v81)\n\
               model name\t: ARMv8 Processor rev 2 (v81)\n\
               model name\t: ARMv8 Processor rev 2 (v81)\n\
               model name\t: ARMv8 Processor rev 2 (v81)\n\
               model name\t: ARMv8 Processor rev 2 (v81)\n";
    assert_eq!(
        brands(raw),
        owned(&[
            ("ARMv8 Processor rev 4 (v81)", 2),
            ("ARMv8 Processor rev 2 (v81)", 4),
        ])
    );
}

#[test]
fn nothing_to_name() {
    assert!(brands("").is_empty());
    assert!(brands("processor\t: 0\nprocessor\t: 1\n").is_empty());
}
