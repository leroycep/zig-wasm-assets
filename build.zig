const Builder = @import("std").build.Builder;

pub fn build(b: *Builder) void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const wasm = b.addStaticLibrary("zig-wasm-assets", "src/main.zig");
    wasm.setBuildMode(mode);
    wasm.setOutputDir(b.fmt("{s}/www", .{b.install_prefix}));
    wasm.setTarget(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });

    const static_files = b.addInstallDirectory(.{
        .source_dir = "static",
        .install_dir = .Prefix,
        .install_subdir = "www",
    });

    const wasm_step = b.step("wasm", "Build web app");
    wasm_step.dependOn(&wasm.step);
    wasm_step.dependOn(&static_files.step);
}
