use bytemuck;
use rand::{
    distributions::{Distribution, Uniform},
    SeedableRng,
};
use wgpu::{Buffer, BufferUsages, Device, Queue, Surface, SurfaceConfiguration};
use winit::window::Window;

use wgpu_alife::wgpu_utils::{
    create_buffer, create_compute_pipeline, create_render_pipeline, BindGroupBuilder,
    BindGroupLayoutBuilder,
};

struct Resources {
    cell_bind_groups: Vec<wgpu::BindGroup>,
    cell_buffers: Vec<wgpu::Buffer>,
    vertices_buffer: wgpu::Buffer,
    compute_pipeline: wgpu::ComputePipeline,
    render_pipeline: wgpu::RenderPipeline,
    work_group_count: u32,
    n_cells: u32,
}

impl Resources {
    fn new(device: &Device, config: &SurfaceConfiguration) -> Self {
        let n_rows = 500;
        let n_cells = n_rows * n_rows;
        let cell_bind_group_layout = BindGroupLayoutBuilder::new()
            .add_storage_buffer(wgpu::BufferSize::new((n_cells * 4) as _), true)
            .add_storage_buffer(wgpu::BufferSize::new((n_cells * 4) as _), false)
            .build(device, None);

        let compute_shader = device.create_shader_module(wgpu::include_wgsl!("wgsl/compute.wgsl"));
        let compute_pipeline =
            create_compute_pipeline(device, &[&cell_bind_group_layout], &compute_shader);

        let mut rng = rand::rngs::StdRng::seed_from_u64(222);
        let unif = Uniform::new::<f32, f32>(0.0, 1.0);
        let init_cells: Vec<f32> = Vec::from_iter((0..n_cells).map(|_| {
            let r = unif.sample(&mut rng);
            if r > 0.8 {
                1.0
            } else {
                0.0
            }
        }));
        let usage = BufferUsages::VERTEX | BufferUsages::STORAGE | BufferUsages::COPY_DST;
        let cell_buffers: Vec<Buffer> = Vec::from_iter((0..2).map(|i| {
            create_buffer(
                device,
                bytemuck::cast_slice(&init_cells),
                usage,
                Some(&format!("cell buffer {}", i)),
            )
        }));

        let cell_bind_groups = Vec::from_iter((0..2).map(|i| {
            BindGroupBuilder::new()
                .add_resource(cell_buffers[i].as_entire_binding())
                .add_resource(cell_buffers[(i + 1) % 2].as_entire_binding())
                .build(device, None, &cell_bind_group_layout)
        }));

        let d = 2.0 / n_rows as f32;
        let vertices: [f32; 12] = [0.0, 0.0, d, 0.0, d, d, 0.0, 0.0, d, d, 0.0, d];
        let vertices_buffer = create_buffer(
            device,
            bytemuck::bytes_of(&vertices),
            BufferUsages::VERTEX | BufferUsages::COPY_DST,
            None,
        );
        let vertex_buffer_layouts = &[
            wgpu::VertexBufferLayout {
                array_stride: 4,
                step_mode: wgpu::VertexStepMode::Instance,
                attributes: &wgpu::vertex_attr_array![0 => Float32],
            },
            wgpu::VertexBufferLayout {
                array_stride: 2 * 4,
                step_mode: wgpu::VertexStepMode::Vertex,
                attributes: &wgpu::vertex_attr_array![1 => Float32x2],
            },
        ];
        let draw_shader = device.create_shader_module(wgpu::include_wgsl!("wgsl/draw.wgsl"));
        let render_pipeline =
            create_render_pipeline(device, config, vertex_buffer_layouts, &draw_shader);

        let work_group_count = (n_cells as f32 / 256.0).ceil() as u32;

        Resources {
            cell_bind_groups,
            cell_buffers,
            vertices_buffer,
            compute_pipeline,
            render_pipeline,
            work_group_count,
            n_cells,
        }
    }

    fn compute_pass(&self, encoder: &mut wgpu::CommandEncoder, frame_num: usize) {
        let mut compute_pass =
            encoder.begin_compute_pass(&wgpu::ComputePassDescriptor { label: None });
        compute_pass.set_pipeline(&self.compute_pipeline);
        compute_pass.set_bind_group(0, &self.cell_bind_groups[frame_num % 2], &[]);
        compute_pass.dispatch_workgroups(self.work_group_count, 1, 1);
    }

    fn render_pass(
        &self,
        encoder: &mut wgpu::CommandEncoder,
        color_attachments: &[Option<wgpu::RenderPassColorAttachment>],
        frame_num: usize,
    ) {
        let render_pass_descriptor = wgpu::RenderPassDescriptor {
            label: None,
            color_attachments,
            depth_stencil_attachment: None,
        };
        let mut render_pass = encoder.begin_render_pass(&render_pass_descriptor);
        render_pass.set_pipeline(&self.render_pipeline);
        render_pass.set_vertex_buffer(0, self.cell_buffers[(frame_num + 1) % 2].slice(..));
        render_pass.set_vertex_buffer(1, self.vertices_buffer.slice(..));
        render_pass.draw(0..6, 0..self.n_cells);
    }
}

pub struct Model {
    surface: Surface,
    device: Device,
    queue: Queue,
    resources: Resources,
    frame_num: usize,
}

impl Model {
    pub async fn new(window: &Window) -> Self {
        let size = window.inner_size();
        let instance = wgpu::Instance::new(wgpu::Backends::all());
        let surface = unsafe { instance.create_surface(window) };
        let adapter = instance
            .request_adapter(&wgpu::RequestAdapterOptions {
                power_preference: wgpu::PowerPreference::default(),
                compatible_surface: Some(&surface),
                force_fallback_adapter: false,
            })
            .await
            .unwrap();
        let (device, queue) = adapter
            .request_device(
                &wgpu::DeviceDescriptor {
                    label: None,
                    features: wgpu::Features::empty(),
                    limits: wgpu::Limits::default(),
                },
                None,
            )
            .await
            .unwrap();
        let config = wgpu::SurfaceConfiguration {
            usage: wgpu::TextureUsages::RENDER_ATTACHMENT,
            format: surface.get_supported_formats(&adapter)[0],
            width: size.width,
            height: size.height,
            present_mode: wgpu::PresentMode::Fifo,
        };
        surface.configure(&device, &config);

        let resources = Resources::new(&device, &config);

        Model {
            surface,
            device,
            queue,
            resources,
            frame_num: 0,
        }
    }

    pub fn update(&mut self) {}

    pub fn render(&mut self) -> Result<(), wgpu::SurfaceError> {
        let mut encoder = self
            .device
            .create_command_encoder(&wgpu::CommandEncoderDescriptor { label: None });
        self.resources.compute_pass(&mut encoder, self.frame_num);

        let frame = self.surface.get_current_texture()?;
        let view = frame
            .texture
            .create_view(&wgpu::TextureViewDescriptor::default());
        let color_attachments = [Some(wgpu::RenderPassColorAttachment {
            view: &view,
            resolve_target: None,
            ops: wgpu::Operations {
                load: wgpu::LoadOp::Clear(wgpu::Color {
                    r: 1.0,
                    g: 1.0,
                    b: 1.0,
                    a: 1.0,
                }),
                store: true,
            },
        })];
        self.resources
            .render_pass(&mut encoder, &color_attachments, self.frame_num);
        self.queue.submit(Some(encoder.finish()));
        frame.present();

        self.frame_num += 1;
        Ok(())
    }
}
