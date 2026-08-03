const builtin = @import("builtin");
const sdl = @import("sdl");
const std = @import("std");

const util = @import("../../util.zig");

const GPUBuffer = @import("gpu_buffer.zig").GPUBuffer;

pub const Material = struct {
    pipeline: *sdl.SDL_GPUGraphicsPipeline,
    vertex_buffer: ?GPUBuffer = null,

    pub fn init(device: *sdl.SDL_GPUDevice, reader: *std.Io.Reader) !Material {
        var buffer: [1024 * 1024]u8 = undefined;
        const bufferLen = try reader.readSliceShort(&buffer);
        const shaderData = buffer[0..bufferLen];

        const vertexShader = createShader(
            device,
            sdl.SDL_GPU_SHADERSTAGE_VERTEX,
            "vertex",
            shaderData,
        );
        const fragmentShader = createShader(
            device,
            sdl.SDL_GPU_SHADERSTAGE_FRAGMENT,
            "fragment",
            shaderData,
        );

        const vertexBufferDescription = sdl.SDL_GPUVertexBufferDescription{
            .slot = 0,
            .pitch = @sizeOf(f32) * 3,
            .input_rate = sdl.SDL_GPU_VERTEXINPUTRATE_VERTEX,
        };
        const vertexAttribute = sdl.SDL_GPUVertexAttribute{
            .location = 0,
            .buffer_slot = 0,
            .format = sdl.SDL_GPU_VERTEXELEMENTFORMAT_FLOAT3,
        };
        const vertexInputState = sdl.SDL_GPUVertexInputState{
            .vertex_buffer_descriptions = &vertexBufferDescription,
            .num_vertex_buffers = 1,
            .vertex_attributes = &vertexAttribute,
            .num_vertex_attributes = 1,
        };
        const rasterizerState = sdl.SDL_GPURasterizerState{
            .fill_mode = sdl.SDL_GPU_FILLMODE_FILL,
            .cull_mode = sdl.SDL_GPU_CULLMODE_BACK,
            .front_face = sdl.SDL_GPU_FRONTFACE_COUNTER_CLOCKWISE,
            .enable_depth_bias = false,
            .enable_depth_clip = false,
        };
        const mutisampleState = sdl.SDL_GPUMultisampleState{
            .sample_count = sdl.SDL_GPU_SAMPLECOUNT_1,
            .enable_alpha_to_coverage = false,
        };
        const depthStencilState = sdl.SDL_GPUDepthStencilState{
            .compare_op = sdl.SDL_GPU_COMPAREOP_LESS,
            .enable_depth_test = false,
            .enable_depth_write = false,
            .compare_mask = 0,
            .enable_stencil_test = false,
        };
        const targetBlendState = sdl.SDL_GPUColorTargetBlendState{
            .src_color_blendfactor = sdl.SDL_GPU_BLENDFACTOR_ONE,
            .dst_color_blendfactor = sdl.SDL_GPU_BLENDFACTOR_ZERO,
            .color_blend_op = sdl.SDL_GPU_BLENDOP_ADD,
            .src_alpha_blendfactor = sdl.SDL_GPU_BLENDFACTOR_ONE,
            .dst_alpha_blendfactor = sdl.SDL_GPU_BLENDFACTOR_ZERO,
            .alpha_blend_op = sdl.SDL_GPU_BLENDOP_ADD,
            .color_write_mask = 0,
            .enable_blend = false,
            .enable_color_write_mask = false,
        };
        const targetDescription = sdl.SDL_GPUColorTargetDescription{
            .format = sdl.SDL_GPU_TEXTUREFORMAT_R8G8B8A8_UNORM,
            .blend_state = targetBlendState,
        };
        const targetInfo = sdl.SDL_GPUGraphicsPipelineTargetInfo{
            .num_color_targets = 1,
            .color_target_descriptions = &targetDescription,
            .has_depth_stencil_target = false,
        };
        const pipelineCreateInfo = sdl.SDL_GPUGraphicsPipelineCreateInfo{
            .vertex_shader = vertexShader,
            .fragment_shader = fragmentShader,
            .vertex_input_state = vertexInputState,
            .primitive_type = sdl.SDL_GPU_PRIMITIVETYPE_TRIANGLELIST,
            .rasterizer_state = rasterizerState,
            .multisample_state = mutisampleState,
            .depth_stencil_state = depthStencilState,
            .target_info = targetInfo,
            .props = 0,
        };

        const pipeline = sdl.SDL_CreateGPUGraphicsPipeline(device, &pipelineCreateInfo) orelse {
            util.sdlPanic();
        };

        return Material{
            .pipeline = pipeline,
        };
    }

    pub fn deinit(self: *Material, device: *sdl.SDL_GPUDevice) void {
        self.freeGpuBuffers(device);
        sdl.SDL_ReleaseGPUGraphicsPipeline(device, self.pipeline);
    }

    pub fn setVertices(self: *Material, device: *sdl.SDL_GPUDevice, vertices: []const f32) void {
        const data = std.mem.sliceAsBytes(vertices);
        const size: u32 = @intCast(data.len);

        const needsBuffer = if (self.vertex_buffer) |buffer| buffer.size != size else true;
        if (needsBuffer) {
            self.freeGpuBuffers(device);
            self.vertex_buffer = GPUBuffer.init(device, sdl.SDL_GPU_BUFFERUSAGE_VERTEX, size);
        }

        self.vertex_buffer.?.write(device, data);
    }

    pub fn freeGpuBuffers(self: *Material, device: *sdl.SDL_GPUDevice) void {
        if (self.vertex_buffer) |*buffer| {
            buffer.deinit(device);
            self.vertex_buffer = null;
        }
    }
};

fn createShader(
    device: *sdl.SDL_GPUDevice,
    shaderStage: sdl.SDL_GPUShaderStage,
    entrypoint: []const u8,
    shaderData: []u8,
) *sdl.SDL_GPUShader {
    const shaderCreateInfo = sdl.SDL_GPUShaderCreateInfo{
        .code_size = shaderData.len,
        .code = shaderData.ptr,
        .entrypoint = entrypoint.ptr,
        .format = sdl.SDL_GPU_SHADERFORMAT_SPIRV,
        .stage = shaderStage,
        .num_samplers = 0,
        .num_storage_textures = 0,
        .num_storage_buffers = 0,
        .num_uniform_buffers = 0,

        .props = 0,
    };

    return sdl.SDL_CreateGPUShader(device, &shaderCreateInfo) orelse util.sdlPanic();
}
