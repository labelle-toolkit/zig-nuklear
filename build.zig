const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const link_libc = b.option(bool, "link_libc", "Use libc for memory allocation, string formatting, and loading files") orelse false;

    const config = b.addConfigHeader(.{}, .{
        // These are always available, regardless of whether libc is linked
        .NK_INCLUDE_FIXED_TYPES = {},
        .NK_INCLUDE_STANDARD_VARARGS = {},
        .NK_INCLUDE_STANDARD_BOOL = {},

        // These require libc
        .NK_INCLUDE_DEFAULT_ALLOCATOR = if (link_libc) {} else null,
        .NK_INCLUDE_STANDARD_IO = if (link_libc) {} else null,

        // Configurable features
        .NK_INCLUDE_VERTEX_BUFFER_OUTPUT = boolOption(b, "vertex_backend", "Enable the vertex draw command list backend"),
        .NK_INCLUDE_FONT_BAKING = boolOption(b, "font_baking", "Enable font baking and rendering"),
        .NK_INCLUDE_DEFAULT_FONT = boolOption(b, "default_font", "Include the default font (ProggyClean.ttf)"),
        .NK_INCLUDE_COMMAND_USERDATA = boolOption(b, "userdata", "Add a userdata pointer into each command"),
        .NK_BUTTON_TRIGGER_ON_RELEASE = boolOption(b, "button_trigger_on_release", "Trigger buttons when released, instead of pressed"),
        .NK_ZERO_COMMAND_MEMORY = boolOption(b, "zero_command_memory", "Zero out memory for each drawing command added to a drawing queue"),
        .NK_UINT_DRAW_INDEX = boolOption(b, "draw_index_32bit", "Use 32-bit vertex index elements, instead of 16-bit (requires vertex_backend)"),
        .NK_KEYSTATE_BASED_INPUT = boolOption(b, "keystate_based_input", "Use key state for each frame rather than key press/release events"),

        // STB library exclusions (for avoiding duplicate symbols when host project provides them)
        .NK_NO_STB_RECT_PACK_IMPLEMENTATION = boolOption(b, "no_stb_rect_pack", "Skip bundled stb_rect_pack (use when host provides it, e.g., raylib)"),
    });

    // Create static library using Zig 0.15+ API
    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "nuklear",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/nuklear.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    lib.root_module.addConfigHeader(config);
    lib.addIncludePath(b.path("src"));
    lib.addCSourceFile(.{
        .file = b.path("src/nuklear.c"),
        .flags = &.{ "-std=c11", "-Wall", "-Werror", "-Wno-unused-function" },
    });
    if (link_libc) lib.linkLibC();
    b.installArtifact(lib);

    // Create module for external use
    const mod = b.addModule("nuklear", .{
        .root_source_file = b.path("src/bindings.zig"),
        .target = target,
        .optimize = optimize,
    });
    mod.addConfigHeader(config);
    mod.addIncludePath(b.path("src"));
    mod.linkLibrary(lib);

    // Tests
    const test_step = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/bindings.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    test_step.root_module.addConfigHeader(config);
    test_step.addIncludePath(b.path("src"));
    test_step.linkLibrary(lib);

    const run_tests = b.addRunArtifact(test_step);
    const test_step_cmd = b.step("test", "Run tests");
    test_step_cmd.dependOn(&run_tests.step);
}

// Returns ?void rather than bool because ConfigHeader is silly
fn boolOption(b: *std.Build, name: []const u8, desc: []const u8) ?void {
    const value = b.option(bool, name, desc) orelse false;
    return if (value) {} else null;
}
