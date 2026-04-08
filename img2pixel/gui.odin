package main

import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:time"
import "core:os"
import "core:log"
import "core:encoding/json"
import "core:bytes"
import "core:strconv"
import "core:image/png"
import "core:image/qoi"
import "core:image/tga"
import "core:image/bmp"
import "core:image/jpeg"
import "core:image/netpbm"
import "core:image"
import "core:path/filepath"
import "core:strings"
import "vendor:sdl3"
import stbi "vendor:stb/image"

import "../gui"
import "../prof"

@(private="file")
window_root: ^gui.Window

@(private="file")
GuiCtx :: struct
{
   groups_left: [4]^gui.Group,
   groups_sample: [2]^gui.Group,

   imgcmp: ^gui.ImageComp,

   sliders: [SliderType]^gui.Slider,
   slider_entries: [SliderType]^gui.Entry,

   sample_scale_mode: [2]^gui.RadioButton,
   sample_sample_mode: [5]^gui.RadioButton,
   dither_dither_mode: [9]^gui.RadioButton,

   groups_dither: [3]^gui.Group,

   palette_colours: [256]^gui.RadioButton,
   palette_kmeanspp: ^gui.CheckButton,

   bar_sample: ^gui.Group,
   bar_batch: ^gui.Group,
   bar_dither: ^gui.Group,
   bar_distance: ^gui.Group,
   dither_colour_dist: [6]^gui.RadioButton,

   dialog_open: bool,

   block_process: bool,
   input: ^Image32,
   output: ^Image8,
   output32: ^Image32,

   cache_sample: ^Image64,
   cache_sharp: ^Image64,
   cache_tint: ^Image64,

   label_batch_input: ^gui.Label,
   label_batch_output: ^gui.Label,

   watch_path: string,
   watch_modtime: time.Time,
   watch: bool,

   batch_type: i32,
   batch_input: string,
   batch_output: string,
   batch_progress: ^gui.Label,
}

GuiSettings :: struct
{
   gui_scale: i32,

   // Paths
   path_image_input: string,
   path_preset_input: string,
   path_palette_input: string,
   path_image_output: string,
   path_preset_output: string,
   path_palette_output: string,
   path_batch_input: string,
   path_batch_output: string,
}


@(private="file")
gui_ctx: GuiCtx

@(private="file")
gui_settings: GuiSettings

@(private="file")
i2p_ctx: Config

SliderType :: enum
{
   ScaleWidth,
   ScaleHeight,
   ScaleX,
   ScaleY,
   SampleXOffset,
   SampleYOffset,
   Blur,
   Sharpen,
   AlphaThreshold,
   DitherAmount,
   TargetColours,
   ColourRed,
   ColourGreen,
   ColourBlue,
   ColourCount,
   Brightness,
   Contrast,
   Saturation,
   Hue,
   Gamma,
   TintRed,
   TintGreen,
   TintBlue,
}

@(private="file")
slider_create :: proc(root_group: ^gui.Group, type: SliderType)
{
   prof.SCOPED_EVENT(#procedure)

   group: ^gui.Group = gui.group_create(root_group, {fill_x = true, layout = .HORIZONTAL})
   slider: ^gui.Slider = gui.slider_create(group, {fill_x = true}, 0)
   gui.slider_set(slider, -1, 1, false)
   slider.msg_user = slider_msg
   slider.usr = u64(type)
   gui_ctx.sliders[type] = slider
   b: ^gui.Button = gui.button_create(group, {layout = .HORIZONTAL}, "\x11")
   b.msg_user = slider_button_sub_msg
   b.usr = u64(type)

   b = gui.button_create(group, {layout = .HORIZONTAL}, "\x10")
   b.msg_user = slider_button_add_msg
   b.usr = u64(type)

   gui_ctx.slider_entries[type] = gui.entry_create(group, {}, 5)
   gui_ctx.slider_entries[type].msg_user = slider_entry_msg
   gui_ctx.slider_entries[type].usr = u64(type)
}

gui_construct_batch :: proc()
{
   prof.SCOPED_EVENT(#procedure)

   gui_ctx.batch_type = 0

   win: ^gui.Window = gui.window_create("Batch processing", 500, 100, "test.png")
   win.msg_user = batch_window_msg
   gui.window_block(window_root, win)

   group_root: ^gui.Group = gui.group_create(win, {fill_x = true, fill_y = true, layout = .VERTICAL})
   gui.group_create(group_root, {fill_x = true, fill_y = true})

   {
      group: ^gui.Group = gui.group_create(group_root, {fill_x = true, layout = .HORIZONTAL})
      group_type: ^gui.Group = gui.group_create(group.window, {fill_x = true, no_parent = true, overlay = true, style = 1})

      r: ^gui.RadioButton = gui.radiobutton_create(group_type, {fill_x = true, style = 1}, "png")
      first: ^gui.RadioButton = r
      r.usr = 0
      r.msg_user = radiobutton_batch_msg
      r = gui.radiobutton_create(group_type, {fill_x = true, style = 1}, "pcx")
      r.usr = 1
      r.msg_user = radiobutton_batch_msg
      gui_ctx.bar_batch = gui.menubar_create(group, {layout = .HORIZONTAL}, {}, {"png  \x1f"}, (cast([^]^gui.Element)&group_type)[0:1], nil)
      gui.radiobutton_set(first, true, true)

      gui_ctx.batch_progress = gui.label_create(group, {layout = .HORIZONTAL, fill_x = true}, "Progress     0/   0")
   }

   {
      group: ^gui.Group = gui.group_create(group_root, {fill_x = true, layout = .HORIZONTAL})
      b: ^gui.Button = gui.button_create(group, {}, "Input ")
      b.usr = 0
      b.msg_user = button_batch_msg
      gui_ctx.label_batch_input = gui.label_create(group, {fill_x = true}, gui_ctx.batch_input)
   }

   {
      group: ^gui.Group = gui.group_create(group_root, {fill_x = true, layout = .HORIZONTAL})
      b: ^gui.Button = gui.button_create(group, {}, "Output")
      b.usr = 1
      b.msg_user = button_batch_msg
      gui_ctx.label_batch_output = gui.label_create(group, {fill_x = true}, gui_ctx.batch_output)
   }

   {
      group: ^gui.Group = gui.group_create(group_root, {center_x = true, layout = .HORIZONTAL})
      b: ^gui.Button = gui.button_create(group, {}, "Exit")
      b.usr = 2
      b.msg_user = button_batch_msg
      gui.label_create(group, {}, "     ")
      b = gui.button_create(group, {}, "Run")
      b.usr = 3
      b.msg_user = button_batch_msg
   }
}

gui_construct :: proc()
{
   prof.SCOPED_EVENT(#procedure)

   data, ok := os.read_entire_file_from_path("settings.json", context.allocator)
   defer delete(data)
   err: json.Unmarshal_Error = json.unmarshal(data[:], &gui_settings)
   if err != nil
   {
      gui_settings.gui_scale = 1
   }
   gui.set_scale(gui_settings.gui_scale)

   win: ^gui.Window = gui.window_create("img2pixel", 1000, 600, "test.png")
   win.msg_user = main_window_msg
   window_root = win

   menus: [3]^gui.Element
   menus[0] = gui.menu_create(win, {no_parent = true, overlay = true, style = 1}, {fill_x = true}, {"Image", "Preset", "Palette"}, menu_load_msg)
   menus[1] = gui.menu_create(win, {no_parent = true, overlay = true, style = 1}, {fill_x = true}, {"Image", "Preset", "Palette"}, menu_save_msg)
   menus[2] = gui.menu_create(win, {no_parent = true, overlay = true, style = 1}, {fill_x = true}, {"Batch"}, menu_tools_msg)
   ck: ^gui.CheckButton = gui.checkbutton_create(menus[2], {fill_x = true, style = 1}, "File watch")
   ck.msg_user = filewatch_msg
   gui.element_timer(ck, 1e9 / 5)

   root: ^gui.Group = gui.group_create(win, {fill_x = true, fill_y = true, layout = .VERTICAL})
   gui.menubar_create(root, {fill_x = true, layout = .HORIZONTAL}, {style = 1}, {"Load", "Save", "Tools"}, menus[:], nil)
   gui.separator_create(root, {fill_x = true}, false)

   group_content: ^gui.Group = gui.group_create(root, {fill_x = true, fill_y = true, layout = .HORIZONTAL})
   group_left: ^gui.Group = gui.group_create(group_content, {fill_y = true, layout = .HORIZONTAL})
   group_middle: ^gui.Group = gui.group_create(group_content, {fill_y = true, fill_x = true, layout = .HORIZONTAL})
   group_right: ^gui.Group = gui.group_create(group_content, {fill_y = true, layout = .VERTICAL})

   // Left: Settings
   // Sample
   {
      gui_ctx.groups_left[0] = gui.group_create(group_left, {fill_x = true, fill_y = true, layout = .VERTICAL})

      // Absolute / relative sampling selection
      group_relative: ^gui.Group = gui.group_create(gui_ctx.groups_left[0], {layout = .HORIZONTAL, center_x = true})

      // Absolute sampling
      gui_ctx.groups_sample[0] = gui.group_create(gui_ctx.groups_left[0], {fill_x = true})
      gui.label_create(gui_ctx.groups_sample[0], {fill_x = true}, "Width")
      slider_create(gui_ctx.groups_sample[0], .ScaleWidth)

      gui.label_create(gui_ctx.groups_sample[0], {fill_x = true}, "Height")
      slider_create(gui_ctx.groups_sample[0], .ScaleHeight)

      // Relative sampling
      gui_ctx.groups_sample[1] = gui.group_create(gui_ctx.groups_left[0], {fill_x = true})
      gui.label_create(gui_ctx.groups_sample[1], {fill_x = true}, "Scale X")
      slider_create(gui_ctx.groups_sample[1], .ScaleX)

      gui.label_create(gui_ctx.groups_sample[1], {fill_x = true}, "Scale Y")
      slider_create(gui_ctx.groups_sample[1], .ScaleY)

      r: ^gui.RadioButton = gui.radiobutton_create(group_relative, {}, "Absolute")
      r.usr = 0
      r.msg_user = radiobutton_scale_msg
      gui_ctx.sample_scale_mode[0] = r
      r = gui.radiobutton_create(group_relative, {}, "Relative")
      r.usr = 1
      r.msg_user = radiobutton_scale_msg
      gui_ctx.sample_scale_mode[1] = r
      gui.radiobutton_set(gui_ctx.sample_scale_mode[0], true, false)

      gui.label_create(gui_ctx.groups_left[0], {}, "                                ");
      gui.separator_create(gui_ctx.groups_left[0], {fill_x = true}, false)
      gui.label_create(gui_ctx.groups_left[0], {}, "                                ");

      gui.label_create(gui_ctx.groups_left[0], {fill_x = true}, "Sample Mode");

      group_sample: ^gui.Group = gui.group_create(gui_ctx.groups_left[0].window, {no_parent = true, style = 1, overlay = true})
      r = gui.radiobutton_create(group_sample, {fill_x = true, style = 1}, "Nearest")
      r.usr = 0
      r.msg_user = radiobutton_sample_msg
      gui_ctx.sample_sample_mode[0] = r

      r = gui.radiobutton_create(group_sample, {fill_x = true, style = 1}, "Bilinear")
      r.usr = 1
      r.msg_user = radiobutton_sample_msg
      gui_ctx.sample_sample_mode[1] = r

      r = gui.radiobutton_create(group_sample, {fill_x = true, style = 1}, "Bicubic")
      r.usr = 2
      r.msg_user = radiobutton_sample_msg
      gui_ctx.sample_sample_mode[2] = r

      r = gui.radiobutton_create(group_sample, {fill_x = true, style = 1}, "Lanczos")
      r.usr = 3
      r.msg_user = radiobutton_sample_msg
      gui_ctx.sample_sample_mode[3] = r

      r = gui.radiobutton_create(group_sample, {fill_x = true, style = 1}, "Cluster")
      r.usr = 4
      r.msg_user = radiobutton_sample_msg
      gui_ctx.sample_sample_mode[4] = r
      
      gui.radiobutton_set(gui_ctx.sample_sample_mode[0], true, false)

      //g: [1]^gui.Element
      //g[0] = group_sample
      gui_ctx.bar_sample = gui.menubar_create(gui_ctx.groups_left[0], {center_x = true, layout = .HORIZONTAL}, {}, {"Nearest  \x1f"}, (cast([^]^gui.Element)&group_sample)[0:1], nil)

      gui.label_create(gui_ctx.groups_left[0], {fill_x =true}, "Sample x offset")
      slider_create(gui_ctx.groups_left[0], .SampleXOffset)
      gui.label_create(gui_ctx.groups_left[0], {fill_x =true}, "Sample y offset")
      slider_create(gui_ctx.groups_left[0], .SampleYOffset)

      gui.label_create(gui_ctx.groups_left[0], {}, "                                ");
      gui.separator_create(gui_ctx.groups_left[0], {fill_x = true}, false)
      gui.label_create(gui_ctx.groups_left[0], {}, "                                ");

      gui.label_create(gui_ctx.groups_left[0], {fill_x = true}, "Blur amount")
      slider_create(gui_ctx.groups_left[0], .Blur)

      gui.label_create(gui_ctx.groups_left[0], {}, "                                ");
      gui.separator_create(gui_ctx.groups_left[0], {fill_x = true}, false)
      gui.label_create(gui_ctx.groups_left[0], {}, "                                ");

      gui.label_create(gui_ctx.groups_left[0], {fill_x = true}, "Sharpen amount")
      slider_create(gui_ctx.groups_left[0], .Sharpen)
   }

   // Dither
   {
      gui_ctx.groups_left[1] = gui.group_create(group_left, {fill_x = true, fill_y = true, layout = .VERTICAL})
      gui.label_create(gui_ctx.groups_left[1], {fill_x = true}, "Alpha threshold")
      slider_create(gui_ctx.groups_left[1], .AlphaThreshold)

      gui.label_create(gui_ctx.groups_left[1], {}, "                                ");
      gui.separator_create(gui_ctx.groups_left[1], {fill_x = true}, false)
      gui.label_create(gui_ctx.groups_left[1], {}, "                                ");

      gui.label_create(gui_ctx.groups_left[1], {fill_x = true}, "Distance metric");

      group_distance: ^gui.Group = gui.group_create(gui_ctx.groups_left[1], {no_parent = true, style = 1, overlay = true})
      r: ^gui.RadioButton
      r = gui.radiobutton_create(group_distance, {fill_x = true, style = 1}, "RGB euclidian")
      r.usr = 0
      r.msg_user = radiobutton_distance_msg
      gui_ctx.dither_colour_dist[0] = r
      r = gui.radiobutton_create(group_distance, {fill_x = true, style = 1}, "RGB weighted ")
      r.usr = 1
      r.msg_user = radiobutton_distance_msg
      gui_ctx.dither_colour_dist[1] = r
      r = gui.radiobutton_create(group_distance, {fill_x = true, style = 1}, "RGB redmean  ")
      r.usr = 2
      r.msg_user = radiobutton_distance_msg
      gui_ctx.dither_colour_dist[2] = r
      r = gui.radiobutton_create(group_distance, {fill_x = true, style = 1}, "CIE76        ")
      r.usr = 3
      r.msg_user = radiobutton_distance_msg
      gui_ctx.dither_colour_dist[3] = r
      r = gui.radiobutton_create(group_distance, {fill_x = true, style = 1}, "CIE94        ")
      r.usr = 4
      r.msg_user = radiobutton_distance_msg
      gui_ctx.dither_colour_dist[4] = r
      r = gui.radiobutton_create(group_distance, {fill_x = true, style = 1}, "CIEDE2000    ")
      r.usr = 5
      r.msg_user = radiobutton_distance_msg
      gui_ctx.dither_colour_dist[5] = r

      gui_ctx.bar_distance = gui.menubar_create(gui_ctx.groups_left[1], {center_x = true, layout = .HORIZONTAL}, {}, {"RGB Euclidian \x1f"}, (cast([^]^gui.Element)&group_distance)[0:1], nil)
      gui.radiobutton_set(gui_ctx.dither_colour_dist[0], true, false)

      gui.label_create(gui_ctx.groups_left[1], {fill_x = true}, "Dither / Assignment mode")
      group_dither: ^gui.Group = gui.group_create(gui_ctx.groups_left[1], {no_parent = true, style = 1, overlay = true})

      r = gui.radiobutton_create(group_dither, {fill_x = true, style = 1}, "None             ")
      r.usr = 0
      r.msg_user = radiobutton_dither_msg
      gui_ctx.dither_dither_mode[0] = r

      r = gui.radiobutton_create(group_dither, {fill_x = true, style = 1}, "Bayer 8x8        ")
      r.usr = 1
      r.msg_user = radiobutton_dither_msg
      gui_ctx.dither_dither_mode[1] = r

      r = gui.radiobutton_create(group_dither, {fill_x = true, style = 1}, "Bayer 4x4        ")
      r.usr = 2
      r.msg_user = radiobutton_dither_msg
      gui_ctx.dither_dither_mode[2] = r

      r = gui.radiobutton_create(group_dither, {fill_x = true, style = 1}, "Bayer 2x2        ")
      r.usr = 3
      r.msg_user = radiobutton_dither_msg
      gui_ctx.dither_dither_mode[3] = r

      r = gui.radiobutton_create(group_dither, {fill_x = true, style = 1}, "Cluster 8x8      ")
      r.usr = 4
      r.msg_user = radiobutton_dither_msg
      gui_ctx.dither_dither_mode[4] = r

      r = gui.radiobutton_create(group_dither, {fill_x = true, style = 1}, "Cluster 4x4      ")
      r.usr = 5
      r.msg_user = radiobutton_dither_msg
      gui_ctx.dither_dither_mode[5] = r

      r = gui.radiobutton_create(group_dither, {fill_x = true, style = 1}, "Floyd-Steinberg  ")
      r.usr = 6
      r.msg_user = radiobutton_dither_msg
      gui_ctx.dither_dither_mode[6] = r

      r = gui.radiobutton_create(group_dither, {fill_x = true, style = 1}, "Floyd-Steinberg 2")
      r.usr = 7
      r.msg_user = radiobutton_dither_msg
      gui_ctx.dither_dither_mode[7] = r

      r = gui.radiobutton_create(group_dither, {fill_x = true, style = 1}, "Median-Cut       ")
      r.usr = 8
      r.msg_user = radiobutton_dither_msg
      gui_ctx.dither_dither_mode[8] = r

      gui_ctx.bar_dither = gui.menubar_create(gui_ctx.groups_left[1], {center_x = true, layout = .HORIZONTAL}, {}, {"RGB Euclidian \x1f"}, (cast([^]^gui.Element)&group_dither)[0:1], nil)

      gui_ctx.groups_dither[0] = gui.group_create(gui_ctx.groups_left[1], {fill_x = true})
      gui_ctx.groups_dither[1] = gui.group_create(gui_ctx.groups_left[1], {fill_x = true})
      gui_ctx.groups_dither[2] = gui.group_create(gui_ctx.groups_left[1], {fill_x = true})

      gui.label_create(gui_ctx.groups_dither[1], {fill_x = true}, "Dither amount")
      slider_create(gui_ctx.groups_dither[1], .DitherAmount)

      gui.label_create(gui_ctx.groups_dither[2], {fill_x = true}, "Target colours")
      slider_create(gui_ctx.groups_dither[2], .TargetColours)

      gui.radiobutton_set(gui_ctx.dither_dither_mode[0], true, false)
   }

   // Palette
   {
      gui_ctx.groups_left[2] = gui.group_create(group_left, {fill_x = true, fill_y = true, layout = .VERTICAL})

      // Palette buttons
      group_palette: ^gui.Group = gui.group_create(gui_ctx.groups_left[2], {fill_y = false, layout = .WRAP, center_x = true})
      group_palette.size_min[0] = 256
      for i in 0..<256
      {
         rb: ^gui.RadioButton = gui.radiobutton_create(group_palette, {},"A")
         gui_ctx.palette_colours[i] = rb
         rb.usr = u64(i)
         rb.usr_ptr = &i2p_ctx.palette[i]
         rb.msg_user = radiobutton_palette_msg
      }

      gui.label_create(gui_ctx.groups_left[2], {fill_x = true}, "Red")
      slider_create(gui_ctx.groups_left[2], .ColourRed)

      gui.label_create(gui_ctx.groups_left[2], {fill_x = true}, "Green")
      slider_create(gui_ctx.groups_left[2], .ColourGreen)

      gui.label_create(gui_ctx.groups_left[2], {fill_x = true}, "Blue")
      slider_create(gui_ctx.groups_left[2], .ColourBlue)

      gui.label_create(gui_ctx.groups_left[2], {fill_x = true}, "Colour count")
      slider_create(gui_ctx.groups_left[2], .ColourCount)

      gui.label_create(gui_ctx.groups_left[2], {}, "                                ");
      gui.separator_create(gui_ctx.groups_left[2], {fill_x = true}, false)
      gui.label_create(gui_ctx.groups_left[2], {}, "                                ");

      b: ^gui.Button = gui.button_create(gui_ctx.groups_left[2], {center_x = true}, "Generate palette")
      b.msg_user = palette_gen_msg
      c: ^gui.CheckButton = gui.checkbutton_create(gui_ctx.groups_left[2], {center_x = true}, "k-means++")
      c.msg_user = kmeans_pp_msg
      gui_ctx.palette_kmeanspp = c
   }

   // Colours
   {
      gui_ctx.groups_left[3] = gui.group_create(group_left, {fill_x = true, fill_y = true, layout = .VERTICAL})

      gui.label_create(gui_ctx.groups_left[3], {fill_x = true}, "Brightness")
      slider_create(gui_ctx.groups_left[3], .Brightness)

      gui.label_create(gui_ctx.groups_left[3], {fill_x = true}, "Contrast")
      slider_create(gui_ctx.groups_left[3], .Contrast)

      gui.label_create(gui_ctx.groups_left[3], {fill_x = true}, "Saturation")
      slider_create(gui_ctx.groups_left[3], .Saturation)

      gui.label_create(gui_ctx.groups_left[3], {fill_x = true}, "Hue")
      slider_create(gui_ctx.groups_left[3], .Hue)

      gui.label_create(gui_ctx.groups_left[3], {fill_x = true}, "Gamma")
      slider_create(gui_ctx.groups_left[3], .Gamma)

      gui.label_create(gui_ctx.groups_left[3], {}, "                                ");
      gui.separator_create(gui_ctx.groups_left[3], {fill_x = true}, false)
      gui.label_create(gui_ctx.groups_left[3], {}, "                                ");

      gui.label_create(gui_ctx.groups_left[3], {fill_x = true}, "Tint red")
      slider_create(gui_ctx.groups_left[3], .TintRed)

      gui.label_create(gui_ctx.groups_left[3], {fill_x = true}, "Tint green")
      slider_create(gui_ctx.groups_left[3], .TintGreen)

      gui.label_create(gui_ctx.groups_left[3], {fill_x = true}, "Tint blue")
      slider_create(gui_ctx.groups_left[3], .TintBlue)
   }

   gui_ctx.groups_left[0].flags.ignore = true
   gui_ctx.groups_left[1].flags.ignore = true
   gui_ctx.groups_left[2].flags.ignore = true
   gui_ctx.groups_left[3].flags.ignore = true

   // Middle: preview
   pix: [4]u8 = 0
   gui_ctx.imgcmp = gui.imgcmp_create(group_middle, {fill_x = true, fill_y = true}, pix[:], 1, 1, pix[:], 1, 1)

   // Right settings
   rb: ^gui.RadioButton
   rb = gui.radiobutton_create(group_right, {fill_x = true, style = 2}, "Sample")
   rb.usr = 0
   rb.msg_user = radiobutton_rb_msg
   first := rb
   rb = gui.radiobutton_create(group_right, {fill_x = true, style = 2}, "Dither")
   rb.usr = 1
   rb.msg_user = radiobutton_rb_msg
   rb = gui.radiobutton_create(group_right, {fill_x = true, style = 2}, "Palette")
   rb.usr = 2
   rb.msg_user = radiobutton_rb_msg
   rb = gui.radiobutton_create(group_right, {fill_x = true, style = 2}, "Colours")
   rb.usr = 3
   rb.msg_user = radiobutton_rb_msg

   gui.radiobutton_set(first, true, true)

}

@(private="file")
slider_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   s: ^gui.Slider = &e.derived.(gui.Slider)

   if msg == .SLIDER_VALUE_CHANGED
   {
      switch SliderType(s.usr)
      {
      case .Blur:
         i2p_ctx.blur_amount = f32(s.value) / 16
         str: string = fmt.aprintf("%.2f", i2p_ctx.blur_amount)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.Blur], str)
         gui_process(0)
      case .SampleXOffset:
         i2p_ctx.x_offset = f32(s.value) / 500
         str: string = fmt.aprintf("%.2f", i2p_ctx.x_offset)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.SampleXOffset], str)
         gui_process(0)
      case .SampleYOffset:
         i2p_ctx.y_offset = f32(s.value) / 500
         str: string = fmt.aprintf("%.2f", i2p_ctx.y_offset)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.SampleYOffset], str)
         gui_process(0)
      case .ScaleWidth:
         i2p_ctx.size_absolute_x = s.value + 1
         str: string = fmt.aprintf("%v", i2p_ctx.size_absolute_x)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.ScaleWidth], str)
         gui_process(0)
      case .ScaleHeight:
         i2p_ctx.size_absolute_y = s.value + 1
         str: string = fmt.aprintf("%v", i2p_ctx.size_absolute_y)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.ScaleHeight], str)
         gui_process(0)
      case .ScaleX:
         i2p_ctx.size_relative_x = s.value + 1
         str: string = fmt.aprintf("%v", i2p_ctx.size_relative_x)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.ScaleX], str)
         gui_process(0)
      case .ScaleY:
         i2p_ctx.size_relative_y = s.value + 1
         str: string = fmt.aprintf("%v", i2p_ctx.size_relative_y)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.ScaleY], str)
         gui_process(0)
      case .AlphaThreshold:
         i2p_ctx.alpha_threshold = s.value
         str: string = fmt.aprintf("%v", i2p_ctx.alpha_threshold)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.AlphaThreshold], str)
         gui_process(3)
      case .DitherAmount:
         i2p_ctx.dither_amount = f32(s.value) / 500
         str: string = fmt.aprintf("%.2f", i2p_ctx.dither_amount)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.DitherAmount], str)
         gui_process(3)
      case .TargetColours:
         i2p_ctx.target_colours = s.value + 1
         str: string = fmt.aprintf("%v", i2p_ctx.target_colours)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.TargetColours], str)
         gui_process(3)
      case .Sharpen:
         i2p_ctx.sharp_amount = f32(s.value) / 500
         str: string = fmt.aprintf("%.2f", i2p_ctx.sharp_amount)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.Sharpen], str)
         gui_process(1)
      case .Brightness:
         i2p_ctx.brightness = f32(s.value - 250) / 250
         str: string = fmt.aprintf("%.2f", i2p_ctx.brightness)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.Brightness], str)
         gui_process(2)
      case .Contrast:
         i2p_ctx.contrast = f32(s.value) / 100
         str: string = fmt.aprintf("%.2f", i2p_ctx.contrast)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.Contrast], str)
         gui_process(2)
      case .Saturation:
         i2p_ctx.saturation = f32(s.value) / 100
         str: string = fmt.aprintf("%.2f", i2p_ctx.saturation)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.Saturation], str)
         gui_process(2)
      case .Hue:
         i2p_ctx.hue = f32(s.value) - 180
         str: string = fmt.aprintf("%.0f", i2p_ctx.hue)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.Hue], str)
         gui_process(2)
      case .Gamma:
         i2p_ctx.gamma = f32(s.value) / 100
         str: string = fmt.aprintf("%.2f", i2p_ctx.gamma)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.Gamma], str)
         gui_process(2)
      case .ColourCount:
         i2p_ctx.colour_count = s.value + 1
         str: string = fmt.aprintf("%v", i2p_ctx.colour_count)
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.ColourCount], str)
         gui_process(3)
      case .ColourRed:
         i2p_ctx.palette[i2p_ctx.colour_selected][0] = u8(s.value)
         str: string = fmt.aprintf("%v", i2p_ctx.palette[i2p_ctx.colour_selected][0])
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.ColourRed], str)
         gui_process(3)
      case .ColourGreen:
         i2p_ctx.palette[i2p_ctx.colour_selected][1] = u8(s.value)
         str: string = fmt.aprintf("%v", i2p_ctx.palette[i2p_ctx.colour_selected][1])
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.ColourGreen], str)
         gui_process(3)
      case .ColourBlue:
         i2p_ctx.palette[i2p_ctx.colour_selected][2] = u8(s.value)
         str: string = fmt.aprintf("%v", i2p_ctx.palette[i2p_ctx.colour_selected][2])
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.ColourBlue], str)
         gui_process(3)
      case .TintRed:
         i2p_ctx.tint[0] = u8(s.value)
         str: string = fmt.aprintf("%v", i2p_ctx.tint[0])
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.TintRed], str)
         gui_process(2)
      case .TintGreen:
         i2p_ctx.tint[1] = u8(s.value)
         str: string = fmt.aprintf("%v", i2p_ctx.tint[1])
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.TintGreen], str)
         gui_process(2)
      case .TintBlue:
         i2p_ctx.tint[2] = u8(s.value)
         str: string = fmt.aprintf("%v", i2p_ctx.tint[2])
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.TintBlue], str)
         gui_process(2)
      }
   }

   return 0
}

@(private="file")
slider_button_add_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   button: ^gui.Button= &e.derived.(gui.Button)

   if msg == .CLICK
   {
      switch SliderType(button.usr)
      {
      case .Blur:
         gui.slider_set(gui_ctx.sliders[.Blur], i32((i2p_ctx.blur_amount + 0.25) * 16), 512, true)
      case .SampleXOffset:
         gui.slider_set(gui_ctx.sliders[.SampleXOffset], i32((i2p_ctx.x_offset + 0.1) * 500), 512, true)
      case .SampleYOffset:
         gui.slider_set(gui_ctx.sliders[.SampleYOffset], i32((i2p_ctx.y_offset + 0.1) * 500), 512, true)
      case .ScaleWidth:
         gui.slider_set(gui_ctx.sliders[.ScaleWidth], i2p_ctx.size_absolute_x + 8 - 1, 512, true)
      case .ScaleHeight:
         gui.slider_set(gui_ctx.sliders[.ScaleHeight], i2p_ctx.size_absolute_y + 8 - 1, 512, true)
      case .ScaleX:
         gui.slider_set(gui_ctx.sliders[.ScaleX], i2p_ctx.size_relative_x + 1 - 1, 31, true)
      case .ScaleY:
         gui.slider_set(gui_ctx.sliders[.ScaleY], i2p_ctx.size_relative_y + 1 - 1, 31, true)
      case .Sharpen:
         gui.slider_set(gui_ctx.sliders[.Sharpen], i32((i2p_ctx.sharp_amount + 0.1) * 500), 512, true)
      case .AlphaThreshold:
         gui.slider_set(gui_ctx.sliders[.AlphaThreshold], i2p_ctx.alpha_threshold + 8, 255, true)
      case .DitherAmount:
         gui.slider_set(gui_ctx.sliders[.DitherAmount], i32((i2p_ctx.dither_amount + 0.1) * 500), 512, true)
      case .TargetColours:
         gui.slider_set(gui_ctx.sliders[.TargetColours], i2p_ctx.target_colours + 1 - 1, 255, true)
      case .ColourCount:
         gui.slider_set(gui_ctx.sliders[.ColourCount], i2p_ctx.colour_count + 4 - 1, 255, true)
      case .ColourRed:
         gui.slider_set(gui_ctx.sliders[.ColourRed], i32(i2p_ctx.palette[i2p_ctx.colour_selected].r + 4), 255, true)
      case .ColourGreen:
         gui.slider_set(gui_ctx.sliders[.ColourGreen], i32(i2p_ctx.palette[i2p_ctx.colour_selected].g + 4), 255, true)
      case .ColourBlue:
         gui.slider_set(gui_ctx.sliders[.ColourBlue], i32(i2p_ctx.palette[i2p_ctx.colour_selected].b + 4), 255, true)
      case .TintRed:
         gui.slider_set(gui_ctx.sliders[.TintRed], i32(i2p_ctx.tint.r + 4), 255, true)
      case .TintGreen:
         gui.slider_set(gui_ctx.sliders[.TintGreen], i32(i2p_ctx.tint.g + 4), 255, true)
      case .TintBlue:
         gui.slider_set(gui_ctx.sliders[.TintBlue], i32(i2p_ctx.tint.b + 4), 255, true)
      case .Brightness:
         gui.slider_set(gui_ctx.sliders[.Brightness], i32((i2p_ctx.brightness + 0.1) * 250 + 250), 500, true)
      case .Contrast:
         gui.slider_set(gui_ctx.sliders[.Contrast], i32((i2p_ctx.contrast + 0.1) * 100), 500, true)
      case .Saturation:
         gui.slider_set(gui_ctx.sliders[.Saturation], i32((i2p_ctx.saturation + 0.1) * 100), 500, true)
      case .Hue:
         gui.slider_set(gui_ctx.sliders[.Hue], i32((i2p_ctx.hue + 10) + 180), 360, true)
      case .Gamma:
         gui.slider_set(gui_ctx.sliders[.Gamma], i32((i2p_ctx.gamma + 0.1) * 100), 500, true)
      }
   }

   return 0
}

@(private="file")
slider_button_sub_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   button: ^gui.Button= &e.derived.(gui.Button)

   if msg == .CLICK
   {
      switch SliderType(button.usr)
      {
      case .Blur:
         gui.slider_set(gui_ctx.sliders[.Blur], i32((i2p_ctx.blur_amount - 0.25) * 16), 512, true)
      case .SampleXOffset:
         gui.slider_set(gui_ctx.sliders[.SampleXOffset], i32((i2p_ctx.x_offset - 0.1) * 500), 512, true)
      case .SampleYOffset:
         gui.slider_set(gui_ctx.sliders[.SampleYOffset], i32((i2p_ctx.y_offset - 0.1) * 500), 512, true)
      case .ScaleWidth:
         gui.slider_set(gui_ctx.sliders[.ScaleWidth], i2p_ctx.size_absolute_x - 8 - 1, 512, true)
      case .ScaleHeight:
         gui.slider_set(gui_ctx.sliders[.ScaleHeight], i2p_ctx.size_absolute_y - 8 - 1, 512, true)
      case .ScaleX:
         gui.slider_set(gui_ctx.sliders[.ScaleX], i2p_ctx.size_relative_x - 1 - 1, 31, true)
      case .ScaleY:
         gui.slider_set(gui_ctx.sliders[.ScaleY], i2p_ctx.size_relative_y - 1 - 1, 31, true)
      case .Sharpen:
         gui.slider_set(gui_ctx.sliders[.Sharpen], i32((i2p_ctx.sharp_amount - 0.1) * 500), 512, true)
      case .AlphaThreshold:
         gui.slider_set(gui_ctx.sliders[.AlphaThreshold], i2p_ctx.alpha_threshold - 8, 255, true)
      case .DitherAmount:
         gui.slider_set(gui_ctx.sliders[.DitherAmount], i32((i2p_ctx.dither_amount - 0.1) * 500), 512, true)
      case .TargetColours:
         gui.slider_set(gui_ctx.sliders[.TargetColours], i2p_ctx.target_colours - 1 - 1, 255, true)
      case .ColourCount:
         gui.slider_set(gui_ctx.sliders[.ColourCount], i2p_ctx.colour_count - 4 - 1, 255, true)
      case .ColourRed:
         gui.slider_set(gui_ctx.sliders[.ColourRed], i32(i2p_ctx.palette[i2p_ctx.colour_selected].r - 4), 255, true)
      case .ColourGreen:
         gui.slider_set(gui_ctx.sliders[.ColourGreen], i32(i2p_ctx.palette[i2p_ctx.colour_selected].g - 4), 255, true)
      case .ColourBlue:
         gui.slider_set(gui_ctx.sliders[.ColourBlue], i32(i2p_ctx.palette[i2p_ctx.colour_selected].b - 4), 255, true)
      case .TintRed:
         gui.slider_set(gui_ctx.sliders[.TintRed], i32(i2p_ctx.tint.r - 4), 255, true)
      case .TintGreen:
         gui.slider_set(gui_ctx.sliders[.TintGreen], i32(i2p_ctx.tint.g - 4), 255, true)
      case .TintBlue:
         gui.slider_set(gui_ctx.sliders[.TintBlue], i32(i2p_ctx.tint.b - 4), 255, true)
      case .Brightness:
         gui.slider_set(gui_ctx.sliders[.Brightness], i32((i2p_ctx.brightness - 0.1) * 250 + 250), 500, true)
      case .Contrast:
         gui.slider_set(gui_ctx.sliders[.Contrast], i32((i2p_ctx.contrast - 0.1) * 100), 500, true)
      case .Saturation:
         gui.slider_set(gui_ctx.sliders[.Saturation], i32((i2p_ctx.saturation - 0.1) * 100), 500, true)
      case .Hue:
         gui.slider_set(gui_ctx.sliders[.Hue], i32((i2p_ctx.hue - 10) + 180), 360, true)
      case .Gamma:
         gui.slider_set(gui_ctx.sliders[.Gamma], i32((i2p_ctx.gamma - 0.1) * 100), 500, true)
      }
   }

   return 0
}

@(private="file")
slider_entry_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   entry: ^gui.Entry = &e.derived.(gui.Entry)

   if msg == .TEXTINPUT_END
   {
      switch SliderType(entry.usr)
      {
      case .Blur:
         value, ok := strconv.parse_f64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.Blur], i32(value * 16), 512, true)
      case .SampleXOffset:
         value, ok := strconv.parse_f64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.SampleXOffset], i32(value * 500), 500, true)
      case .SampleYOffset:
         value, ok := strconv.parse_f64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.SampleYOffset], i32(value * 500), 500, true)
      case .ScaleWidth:
         value, ok := strconv.parse_i64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.ScaleWidth], i32(value - 1), 511, true)
      case .ScaleHeight:
         value, ok := strconv.parse_i64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.ScaleHeight], i32(value - 1), 511, true)
      case .ScaleX:
         value, ok := strconv.parse_i64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.ScaleX], i32(value - 1), 31, true)
      case .ScaleY:
         value, ok := strconv.parse_i64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.ScaleY], i32(value - 1), 31, true)
      case .Sharpen:
         value, ok := strconv.parse_f64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.Sharpen], i32(value * 500), 500, true)
      case .AlphaThreshold:
         value, ok := strconv.parse_i64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.AlphaThreshold], i32(value), 255, true)
      case .DitherAmount:
         value, ok := strconv.parse_f64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.DitherAmount], i32(value * 500), 500, true)
      case .TargetColours:
         value, ok := strconv.parse_i64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.TargetColours], i32(value - 1), 255, true)
      case .ColourCount:
         value, ok := strconv.parse_i64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.ColourCount], i32(value), 255, true)
      case .ColourRed:
         value, ok := strconv.parse_i64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.ColourRed], i32(value), 255, true)
      case .ColourGreen:
         value, ok := strconv.parse_i64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.ColourGreen], i32(value), 255, true)
      case .ColourBlue:
         value, ok := strconv.parse_i64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.ColourBlue], i32(value), 255, true)
      case .TintRed:
         value, ok := strconv.parse_i64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.TintRed], i32(value), 255, true)
      case .TintGreen:
         value, ok := strconv.parse_i64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.TintGreen], i32(value), 255, true)
      case .TintBlue:
         value, ok := strconv.parse_i64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.TintBlue], i32(value), 255, true)
      case .Brightness:
         value, ok := strconv.parse_f64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.Brightness], i32(value * 250 + 250), 500, true)
      case .Contrast:
         value, ok := strconv.parse_f64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.Contrast], i32(value * 100), 500, true)
      case .Saturation:
         value, ok := strconv.parse_f64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.Saturation], i32(value * 100), 500, true)
      case .Hue:
         value, ok := strconv.parse_f64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.Hue], i32(value + 180), 360, true)
      case .Gamma:
         value, ok := strconv.parse_f64(string(entry.entry[:]))
         gui.slider_set(gui_ctx.sliders[.Gamma], i32(value * 100), 500, true)
      }
   }

   return 0
}

@(private="file")
radiobutton_scale_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   if msg == .CLICK
   {
      if di == 0 // Uncheck
      {
         gui_ctx.groups_sample[e.usr].flags.ignore = true
      }
      else if di == 1 // Check
      {
         gui_ctx.groups_sample[e.usr].flags.ignore = false
         gui.element_layout(e.window, e.window.bounds)
         gui.element_redraw(e.window)
         
         i2p_ctx.scale_relative = bool(e.usr)
         gui_process(0)
      }
   }

   return 0
}

@(private="file")
radiobutton_sample_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   r: ^gui.RadioButton = &e.derived.(gui.RadioButton)

   if msg == .CLICK
   {
      if di == 1
      {
         i2p_ctx.sample_mode = i32(r.usr)
         str: string = fmt.aprintf("%v \x1f", r.text)
         defer delete(str)
         gui.menubar_label_set(gui_ctx.bar_sample, str, 0)
         gui.element_layout(r.window, r.window.bounds)
         gui.element_redraw(r.window)

         gui_process(0)
      }
   }

   return 0
}

@(private="file")
radiobutton_distance_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   r: ^gui.RadioButton = &e.derived.(gui.RadioButton)

   if msg == .CLICK
   {
      if di == 1
      {
         i2p_ctx.colour_dist = ColourDist(r.usr)
         str: string = fmt.aprintf("%v \x1f", r.text)
         defer delete(str)
         gui.menubar_label_set(gui_ctx.bar_distance, str, 0)

         gui_process(3)
      }
   }

   return 0
}

@(private="file")
button_batch_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   r: ^gui.Button = &e.derived.(gui.Button)

   if msg == .CLICK
   {
      if e.usr == 0 // Input select
      {
         gui.open_folder_dialog(e.window, 0, gui_settings.path_batch_input, false)
      }
      else if e.usr == 1 // Output select
      {
         gui.open_folder_dialog(e.window, 1, gui_settings.path_batch_output, false)
      }
      else if e.usr == 2 // Exit
      {
         gui.window_close(e.window)
      }
      else if e.usr == 3 // Run
      {
         files, err := os.read_directory_by_path(gui_ctx.batch_input, 0, context.allocator)
         if err != nil
         {
            return 0
         }
         defer os.file_info_slice_delete(files[:], context.allocator)

         file_cnt: i32 = 0
         for file in files
         {
            if file.type != .Regular do continue
            file_cnt += 1
         }

         file_current: i32 = 0
         for file in files
         {
            if file.type != .Regular do continue

            img: ^image.Image
            err: image.Error
            img, err = image.load_from_file(file.fullpath)
            defer image.destroy(img)
            if err != nil
            {
               log.errorf("Failed to load image \"%v\": %v", file.fullpath, err)
               continue
            }
            image.alpha_add_if_missing(img)
            
            data: []u8 = bytes.buffer_to_bytes(&img.pixels)
            img32: ^Image32 = image32_new(i32(img.width), i32(img.height))
            #no_bounds_check {
               mem.copy(&img32.data[0], raw_data(data), len(data))
            }

            img64: ^Image64 = image64_from_32(img32)
            free(img32)
            image64_blur(img64, i2p_ctx.blur_amount)

            width: i32 = 0
            height: i32 = 0
            if i2p_ctx.scale_relative
            {
               width = img64.width / max(1, i2p_ctx.size_relative_x)
               height = img64.height / max(1, i2p_ctx.size_relative_y)
            }
            else
            {
               width = i2p_ctx.size_absolute_x
               height = i2p_ctx.size_absolute_y
            }

            sample64: ^Image64 = image64_sample(img64, width, height, i2p_ctx.sample_mode, i2p_ctx.x_offset, i2p_ctx.y_offset)
            free(img64)
            image64_sharpen(sample64, i2p_ctx.sharp_amount)
            image64_hscb(sample64, i2p_ctx.hue, i2p_ctx.saturation, i2p_ctx.contrast, i2p_ctx.brightness)
            image64_gamma(sample64, i2p_ctx.gamma)
            image64_tint(sample64, i2p_ctx.tint)
            out32, out := image64_dither(sample64, &i2p_ctx)
            free(sample64)
            defer free(out32)
            defer free(out)

            if gui_ctx.batch_type == 0
            {
               stem: string = filepath.stem(file.name)
               raw_path, err := os.join_path({gui_ctx.batch_output, stem}, context.allocator)
               defer delete(raw_path)
               final_path: string = fmt.aprintf("%v.png", raw_path)
               defer delete(final_path)
               path_cstr: cstring = strings.clone_to_cstring(final_path)
               defer delete(path_cstr)
 #no_bounds_check {
                  stbi.write_png(path_cstr, out32.width, out32.height, 4, &out32.data[0], out32.width * 4)
               }
            }
            else if gui_ctx.batch_type == 1
            {
               stem: string = filepath.stem(file.name)
               raw_path, err := os.join_path({gui_ctx.batch_output, stem}, context.allocator)
               defer delete(raw_path)
               final_path: string = fmt.aprintf("%v.pcx", raw_path)
               defer delete(final_path)
               pcx_save(out, final_path)
            }

            if file_current % 5 == 0
            {
               label: string = fmt.aprintf("Progress %4d/%4d", file_current, file_cnt)
               gui.label_set(gui_ctx.batch_progress, label)
               delete(label)
               gui.element_redraw_now(gui_ctx.batch_progress)
            }
            file_current += 1
         }
      }
   }

   return 0
}

@(private="file")
radiobutton_batch_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   r: ^gui.RadioButton = &e.derived.(gui.RadioButton)

   if msg == .CLICK
   {
      if di == 1
      {
         gui_ctx.batch_type = i32(r.usr)
         str: string = fmt.aprintf("%v  \x1f", r.text)
         defer delete(str)
         gui.menubar_label_set(gui_ctx.bar_batch, str, 0)
      }
   }

   return 0
}

@(private="file")
radiobutton_dither_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   r: ^gui.RadioButton = &e.derived.(gui.RadioButton)

   if msg == .CLICK
   {
      if di == 1
      {
         i2p_ctx.dither_mode = DitherMode(r.usr)
         str: string = fmt.aprintf("%v \x1f", r.text)
         defer delete(str)
         gui.menubar_label_set(gui_ctx.bar_dither, str, 0)

         gui_ctx.groups_dither[0].flags.ignore = true
         gui_ctx.groups_dither[1].flags.ignore = true
         gui_ctx.groups_dither[2].flags.ignore = true

         switch i2p_ctx.dither_mode
         {
         case .Bayer8x8, .Bayer4x4, .Bayer2x2, .Cluster8x8, .Cluster4x4:
            gui_ctx.groups_dither[1].flags.ignore = false
         case .None, .Floyd, .Floyd2:
            gui_ctx.groups_dither[0].flags.ignore = false
         case .MedianCut:
            gui_ctx.groups_dither[2].flags.ignore = false
         }

         gui.element_layout(gui_ctx.groups_left[1], gui_ctx.groups_left[1].bounds)
         gui.element_redraw(gui_ctx.groups_left[1])

         gui_process(3)
      }
   }

   return 0
}

@(private="file")
radiobutton_palette_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   button: ^gui.RadioButton = &e.derived.(gui.RadioButton)   
   prof.SCOPED_EVENT(#procedure)

   if msg == .GET_WIDTH
   {
      return i64(16 * gui.get_scale())
   }
   else if msg == .GET_HEIGHT
   {
      return i64(16 * gui.get_scale())
   }
   else if msg == .DRAW
   {
      if i32(button.usr) >= i2p_ctx.colour_count do return 1

      colour: [4]u8 = i2p_ctx.palette[button.usr]
      bounds: gui.Rect = button.bounds
      scale: i32 = gui.get_scale()

      gui.draw_rectangle_fill(button, bounds, colour)

      if button.state || button.checked
      {
         gui.draw_rectangle_fill(button, {{bounds.min[0], bounds.min.y + scale}, 
            {bounds.min.x + scale, bounds.max.y - scale}}, {0, 0, 0, 255})
         gui.draw_rectangle_fill(button, {{bounds.min[0], bounds.max.y - scale}, 
            {bounds.max.x - scale, bounds.max.y}}, {0, 0, 0, 255})

         gui.draw_rectangle_fill(button, {{bounds.max.x - scale, bounds.min.y + scale},
            {bounds.max.x, bounds.max.y - scale}}, {50, 50, 50, 255})
         gui.draw_rectangle_fill(button, {{bounds.min.x + scale, bounds.min.y},
            {bounds.max.x, bounds.min.y + scale}}, {50, 50, 50, 255})
      }
      else
      {
         gui.draw_rectangle_fill(button, {{bounds.min[0], bounds.min.y + scale}, 
            {bounds.min.x + scale, bounds.max.y - scale}}, {50, 50, 50, 255})
         gui.draw_rectangle_fill(button, {{bounds.min[0], bounds.max.y - scale}, 
            {bounds.max.x - scale, bounds.max.y}}, {50, 50, 50, 255})

         gui.draw_rectangle_fill(button, {{bounds.max.x - scale, bounds.min.y + scale},
            {bounds.max.x, bounds.max.y - scale}}, {200, 200, 200, 255})
         gui.draw_rectangle_fill(button, {{bounds.min.x + scale, bounds.min.y},
            {bounds.max.x, bounds.min.y + scale}}, {200, 200, 200, 255})
      }

      height: i32 = bounds.max.y - bounds.min.y
      dim: i32 = gui.GLYPH_HEIGHT * gui.get_scale()
      offset: i32 = (height - dim) / 2
      if button.checked
      {
         colour_box: [4]u8 = {0, 0, 0, 255}
         if colour.r < 128 && colour.g < 128 && colour.b < 128
         {
            colour_box = {255, 255, 255, 255}
         }

         gui.draw_rectangle_fill(button, {{bounds.min.x + offset + 5 * scale, bounds.min.y + offset + 4 * scale},
            {bounds.min.x + dim + offset - 4 * scale, bounds.min.y + offset - 5 * scale + dim}}, colour_box)
      }

      return 1
   }
   else if msg == .CLICK
   {
      if di != 0
      {
         i2p_ctx.colour_selected = i32(button.usr)

         gui.slider_set(gui_ctx.sliders[.ColourRed], i32(i2p_ctx.palette[button.usr].r), 255, true)
         gui.slider_set(gui_ctx.sliders[.ColourGreen], i32(i2p_ctx.palette[button.usr].g), 255, true)
         gui.slider_set(gui_ctx.sliders[.ColourBlue], i32(i2p_ctx.palette[button.usr].b), 255, true)
      }
   }

   return 0
}

@(private="file")
radiobutton_rb_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   if msg == .CLICK
   {
      if di == 0 // Uncheck
      {
         gui_ctx.groups_left[e.usr].flags.ignore = true
      }
      else if di == 1 // Check
      {
         gui_ctx.groups_left[e.usr].flags.ignore = false
         gui.element_layout(e.window, e.window.bounds)
         gui.element_redraw(e.window)
      }
   }

   return 0
}

@(private="file")
palette_gen_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   if msg == .CLICK
   {
      img_kmeans: ^Image32 = image32_from_64(gui_ctx.cache_tint)
      defer free(img_kmeans)
      // TODO: seed
      image32_kmeans(img_kmeans, &i2p_ctx.palette, i2p_ctx.colour_count, 0, i2p_ctx.kmeanspp)

      //gui.element_redraw(gui_ctx.

      gui_process(3)
   }

   return 0
}

@(private="file")
kmeans_pp_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   if msg == .CLICK
   {
      i2p_ctx.kmeanspp = bool(di)
   }

   return 0
}

@(private="file")
filewatch_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   if msg == .CLICK
   {
      gui_ctx.watch = bool(di)
   }
   else if msg == .TIMER
   {
      if !gui_ctx.watch do return 0

      time, err_mtbp := os.modification_time_by_path(gui_ctx.watch_path)
      if err_mtbp != nil do return 0

      if time != gui_ctx.watch_modtime
      {
         gui_ctx.watch_modtime = time

         img: ^image.Image
         err: image.Error
         img, err = image.load_from_file(gui_ctx.watch_path)
         defer image.destroy(img)
         if err != nil
         {
            log.errorf("Failed to load image \"%v\": %v", gui_ctx.watch_path, err)
            return 0
         }
         image.alpha_add_if_missing(img)
         
         data: []u8 = bytes.buffer_to_bytes(&img.pixels)
         img32: ^Image32 = image32_new(i32(img.width), i32(img.height))
         #no_bounds_check {
            mem.copy(&img32.data[0], raw_data(data), len(data))
         }

         if gui_ctx.input != nil
         {
            free(gui_ctx.input)
            gui_ctx.input = nil
         }
         gui_ctx.input = img32

         gui.imgcmp_update0(gui_ctx.imgcmp, data, i32(img.width), i32(img.height))

         gui_process(0)
         gui.element_redraw(gui_ctx.imgcmp)
      }
   }

   return 0
}

@(private="file")
menu_load_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   m: ^gui.MenuButton = &e.derived.(gui.MenuButton)

   if msg == .CLICK_MENU
   {
      if m.idx == 0
      {
         gui.open_file_dialog(e.window, 0, {{"all", "*"}}, gui_settings.path_image_input, false)
         gui_ctx.dialog_open = true
      }
      else if m.idx == 1
      {
         gui.open_file_dialog(e.window, 1, {{"JSON", "json"}}, gui_settings.path_preset_input, false)
         gui_ctx.dialog_open = true
      }
      else if m.idx == 2
      {
         gui.open_file_dialog(e.window, 2, {{"all", "*"}, {"jasc-pal", "pal"},
            {"hex", "hex"}, {"gpl", "gpl"},
            {"png", "png"}}, gui_settings.path_palette_input, false)
         gui_ctx.dialog_open = true
      }
   }

   return 0
}

@(private="file")
menu_save_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   m: ^gui.MenuButton = &e.derived.(gui.MenuButton)

   if msg == .CLICK_MENU
   {
      if m.idx == 0
      {
         gui.save_file_dialog(e.window, 0, {{"PNG", "png"}, {"TARGA", "tga"}, 
            {"QOI", "qoi"}, {"BMP", "bmp"},
            {"pcx", "pcx"}}, gui_settings.path_image_output)
         gui_ctx.dialog_open = true
      }
      else if m.idx == 1
      {
         gui.save_file_dialog(e.window, 1, {{"JSON", "json"}}, gui_settings.path_preset_output)
         gui_ctx.dialog_open = true
      }
      else if m.idx == 2
      {
         gui.save_file_dialog(e.window, 2, {{"jasc-pal", "pal"}, {"hex", "hex"},
            {"gpl", "gpl"}}, gui_settings.path_palette_output)
         gui_ctx.dialog_open = true
      }
   }

   return 0
}

@(private="file")
menu_tools_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   m: ^gui.MenuButton = &e.derived.(gui.MenuButton)

   if msg == .CLICK_MENU
   {
      if m.idx == 0
      {
         gui_construct_batch()
      }
   }

   return 0
}

@(private="file")
batch_window_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   if msg == .OPENFOLDER
   {
      msg_ctx: ^gui.OpenFolderMsg = cast(^gui.OpenFolderMsg)dp
      if msg_ctx.ident == 0 // Input directory
      {
         if len(msg_ctx.folder_list) != 1 do return 0

         delete(gui_settings.path_batch_input)
         gui_settings.path_batch_input = strings.clone(msg_ctx.folder_list[0])

         delete(gui_ctx.batch_input)
         gui_ctx.batch_input = strings.clone(msg_ctx.folder_list[0])
         gui.label_set(gui_ctx.label_batch_input, gui_ctx.batch_input)
         gui.element_redraw(gui_ctx.label_batch_input)
      }
      else if msg_ctx.ident == 1 // Output directory
      {
         if len(msg_ctx.folder_list) != 1 do return 0

         delete(gui_settings.path_batch_output)
         gui_settings.path_batch_output = strings.clone(msg_ctx.folder_list[0])

         delete(gui_ctx.batch_output)
         gui_ctx.batch_output = strings.clone(msg_ctx.folder_list[0])
         gui.label_set(gui_ctx.label_batch_output, gui_ctx.batch_output)
         gui.element_redraw(gui_ctx.label_batch_output)
      }
   }

   return 0
}

@(private="file")
main_window_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   if msg == .OPENFILE
   {
      msg_ctx: ^gui.OpenFileMsg = cast(^gui.OpenFileMsg)dp
      if msg_ctx.ident == 0 // Load image
      {
         if len(msg_ctx.file_list) != 1 do return 0

         delete(gui_settings.path_image_input)
         gui_settings.path_image_input = strings.clone(filepath.dir(msg_ctx.file_list[0]))
         delete(gui_ctx.watch_path)
         gui_ctx.watch_path = strings.clone(msg_ctx.file_list[0])
         time, err_mtbp := os.modification_time_by_path(gui_ctx.watch_path)
         if err_mtbp == nil
         {
            gui_ctx.watch_modtime = time
         }

         img: ^image.Image
         err: image.Error
         img, err = image.load_from_file(msg_ctx.file_list[0])
         defer image.destroy(img)
         if err != nil
         {
            log.errorf("Failed to load image \"%v\": %v", msg_ctx.file_list[0], err)
            return 0
         }
         image.alpha_add_if_missing(img)
         
         data: []u8 = bytes.buffer_to_bytes(&img.pixels)
         img32: ^Image32 = image32_new(i32(img.width), i32(img.height))
         #no_bounds_check {
            mem.copy(&img32.data[0], raw_data(data), len(data))
         }

         if gui_ctx.input != nil
         {
            free(gui_ctx.input)
            gui_ctx.input = nil
         }
         gui_ctx.input = img32

         gui.imgcmp_update0(gui_ctx.imgcmp, data, i32(img.width), i32(img.height))

         gui_process(0)
         gui.element_redraw(gui_ctx.imgcmp)
      }
      else if msg_ctx.ident == 1 // Load preset
      {
         if len(msg_ctx.file_list) != 1 do return 0

         delete(gui_settings.path_preset_input)
         gui_settings.path_preset_input = strings.clone(filepath.dir(msg_ctx.file_list[0]))

         path: string = msg_ctx.file_list[0]
         data, ok := os.read_entire_file_from_path(path, context.allocator)
         defer delete(data)
         err: json.Unmarshal_Error = json.unmarshal(data[:], &i2p_ctx)
         if err != nil
         {
            log.errorf("json unmarshal error: %v", err)
         }

         gui_apply_preset()
         gui_process(0)
      }
      else if msg_ctx.ident == 2 // Load palette
      {
         if len(msg_ctx.file_list) != 1 do return 0

         delete(gui_settings.path_palette_input)
         gui_settings.path_palette_input = strings.clone(filepath.dir(msg_ctx.file_list[0]))

         palette_load(msg_ctx.file_list[0], &i2p_ctx.palette, &i2p_ctx.colour_count)

         gui.slider_set(gui_ctx.sliders[.ColourRed], i32(i2p_ctx.palette[i2p_ctx.colour_selected].r), 255, true)
         gui.slider_set(gui_ctx.sliders[.ColourGreen], i32(i2p_ctx.palette[i2p_ctx.colour_selected].g), 255, true)
         gui.slider_set(gui_ctx.sliders[.ColourBlue], i32(i2p_ctx.palette[i2p_ctx.colour_selected].b), 255, true)
         gui.slider_set(gui_ctx.sliders[.ColourCount], i2p_ctx.colour_count - 1, 255, true)
         gui.element_redraw(e.window)

         gui_process(3)
      }
   }
   else if msg == .SAVEFILE
   {
      msg_ctx: ^gui.SaveFileMsg = cast(^gui.SaveFileMsg)dp
      if msg_ctx.ident == 0 // Save image
      {
         if len(msg_ctx.file_list) != 1 do return 0

         delete(gui_settings.path_image_output)
         gui_settings.path_image_output = strings.clone(filepath.dir(msg_ctx.file_list[0]))

         if gui_ctx.output32 == nil || gui_ctx.output32.width <= 0 || gui_ctx.output32.height <= 0 do return 0

         path: string = msg_ctx.file_list[0]
         ext: string = filepath.ext(path)
         ext_lower: string = strings.to_lower(ext)
         defer delete(ext_lower)

         path_cstr: cstring = strings.clone_to_cstring(path)
         defer delete(path_cstr)

         #no_bounds_check {
            img, ok := image.pixels_to_image((([^]image.RGBA_Pixel)(&gui_ctx.output32.data[0]))[0:gui_ctx.output32.width * gui_ctx.output32.height],
               int(gui_ctx.output32.width), int(gui_ctx.output32.height))

            if strings.compare(ext_lower, ".tga") == 0
            {
               tga.save_to_file(path, &img)
            }
            else if strings.compare(ext_lower, ".bmp") == 0
            {
               bmp.save_to_file(path, &img)
            }
            else if strings.compare(ext_lower, ".qoi") == 0
            {
               qoi.save_to_file(path, &img)
            }
            else if strings.compare(ext_lower, ".png") == 0
            {
               stbi.write_png(path_cstr, gui_ctx.output32.width, gui_ctx.output32.height, 4, &gui_ctx.output32.data[0], gui_ctx.output32.width * 4)
            }
            else if strings.compare(ext_lower, ".pcx") == 0
            {
               pcx_save(gui_ctx.output, path)
            }
         }
      }
      else if msg_ctx.ident == 1 // Save preset
      {
         if len(msg_ctx.file_list) != 1 do return 0

         delete(gui_settings.path_preset_output)
         gui_settings.path_preset_output = strings.clone(filepath.dir(msg_ctx.file_list[0]))

         path: string = msg_ctx.file_list[0]

         data, err := json.marshal(i2p_ctx)
         defer delete(data)
         err_write := os.write_entire_file_from_bytes(path, data)
      }
      else if msg_ctx.ident == 2 // Save palette
      {
         if len(msg_ctx.file_list) != 1 do return 0

         delete(gui_settings.path_palette_output)
         gui_settings.path_palette_output = strings.clone(filepath.dir(msg_ctx.file_list[0]))

         path: string = msg_ctx.file_list[0]

         palette_save(path, i2p_ctx.palette, i2p_ctx.colour_count)
      }
   }
   else if msg == .DESTROY
   {
      data, err := json.marshal(gui_settings, {pretty = true})
      defer delete(data)
      err_write := os.write_entire_file_from_bytes("settings.json", data)
   }

   return 0
}

gui_process :: proc(from: i32) #no_bounds_check
{
   prof.SCOPED_EVENT(#procedure)

   if gui_ctx.input == nil || gui_ctx.block_process
   {
      return
   }

   if gui_ctx.output != nil
   {
      free(gui_ctx.output)
      free(gui_ctx.output32)
      gui_ctx.output = nil
      gui_ctx.output32 = nil
   }

   if from <= 0 || gui_ctx.cache_sample == nil
   {
      if gui_ctx.cache_sample != nil
      {
         free(gui_ctx.cache_sample)
         gui_ctx.cache_sample = nil
      }

      img: ^Image64 = image64_from_32(gui_ctx.input)
      defer free(img)
      image64_blur(img, i2p_ctx.blur_amount)

      width: i32 = 0
      height: i32 = 0
      if i2p_ctx.scale_relative
      {
         width = img.width / max(1, i2p_ctx.size_relative_x)
         height = img.height / max(1, i2p_ctx.size_relative_y)
      }
      else
      {
         width = i2p_ctx.size_absolute_x
         height = i2p_ctx.size_absolute_y
      }

      gui_ctx.cache_sample = image64_sample(img, width, height, i2p_ctx.sample_mode, i2p_ctx.x_offset, i2p_ctx.y_offset)
   }

   if from <= 1 || gui_ctx.cache_sharp == nil
   {
      if gui_ctx.cache_sharp != nil
      {
         free(gui_ctx.cache_sharp)
         gui_ctx.cache_sharp = nil
      }

      gui_ctx.cache_sharp = image64_dup(gui_ctx.cache_sample)
      image64_sharpen(gui_ctx.cache_sharp, i2p_ctx.sharp_amount)
   }

   if from <= 2 || gui_ctx.cache_tint == nil
   {
      if gui_ctx.cache_tint != nil
      {
         free(gui_ctx.cache_tint)
         gui_ctx.cache_tint = nil
      }

      gui_ctx.cache_tint = image64_dup(gui_ctx.cache_sharp)
      image64_hscb(gui_ctx.cache_tint, i2p_ctx.hue, i2p_ctx.saturation, i2p_ctx.contrast, i2p_ctx.brightness)
      image64_gamma(gui_ctx.cache_tint, i2p_ctx.gamma)
      image64_tint(gui_ctx.cache_tint, i2p_ctx.tint)
   }

   dither_input: ^Image64 = image64_dup(gui_ctx.cache_tint)
   defer free(dither_input)
   out32, out := image64_dither(dither_input, &i2p_ctx)
   gui_ctx.output = out
   gui_ctx.output32 = out32

   if gui_ctx.output != nil
   {
      gui.imgcmp_update1(gui_ctx.imgcmp, (cast([^]u8)&gui_ctx.output32.data[0][0])[0:gui_ctx.output32.width * gui_ctx.output32.height], 
         gui_ctx.output32.width, gui_ctx.output32.height)
   }
}

gui_load_preset :: proc(path: string)
{
   data, ok := os.read_entire_file_from_path(path, context.allocator)
   defer delete(data)
   err: json.Unmarshal_Error = json.unmarshal(data[:], &i2p_ctx)
   if err != nil
   {
      default_preset(&i2p_ctx)
   }

   gui_apply_preset()
}

gui_apply_preset :: proc()
{
   gui_ctx.block_process = true
   //load_preset(path, &i2p_ctx)

   gui.slider_set(gui_ctx.sliders[.Blur], i32(i2p_ctx.blur_amount * 16), 512, true)
   gui.slider_set(gui_ctx.sliders[.SampleXOffset], i32(i2p_ctx.x_offset * 500), 500, true)
   gui.slider_set(gui_ctx.sliders[.SampleYOffset], i32(i2p_ctx.y_offset * 500), 500, true)
   gui.slider_set(gui_ctx.sliders[.ScaleWidth], i2p_ctx.size_absolute_x - 1, 511, true)
   gui.slider_set(gui_ctx.sliders[.ScaleHeight], i2p_ctx.size_absolute_y - 1, 511, true)
   gui.slider_set(gui_ctx.sliders[.ScaleX], i2p_ctx.size_relative_x - 1, 31, true)
   gui.slider_set(gui_ctx.sliders[.ScaleY], i2p_ctx.size_relative_y - 1, 31, true)
   gui.slider_set(gui_ctx.sliders[.Sharpen], i32(i2p_ctx.sharp_amount * 500), 500, true)
   gui.slider_set(gui_ctx.sliders[.Brightness], i32(i2p_ctx.brightness * 250 + 250), 500, true)
   gui.slider_set(gui_ctx.sliders[.Contrast], i32(i2p_ctx.contrast * 100), 500, true)
   gui.slider_set(gui_ctx.sliders[.Saturation], i32(i2p_ctx.saturation * 100), 500, true)
   gui.slider_set(gui_ctx.sliders[.Hue], i32(i2p_ctx.hue + 180), 360, true)
   gui.slider_set(gui_ctx.sliders[.Gamma], i32(i2p_ctx.gamma * 100), 500, true)
   gui.slider_set(gui_ctx.sliders[.AlphaThreshold], i2p_ctx.alpha_threshold, 255, true)
   gui.slider_set(gui_ctx.sliders[.DitherAmount], i32(i2p_ctx.dither_amount * 500), 500, true)
   gui.slider_set(gui_ctx.sliders[.TargetColours], i2p_ctx.target_colours - 1, 255, true)
   gui.slider_set(gui_ctx.sliders[.ColourCount], i2p_ctx.colour_count - 1, 255, true)
   gui.slider_set(gui_ctx.sliders[.TintRed], i32(i2p_ctx.tint[0]), 255, true)
   gui.slider_set(gui_ctx.sliders[.TintGreen], i32(i2p_ctx.tint[1]), 255, true)
   gui.slider_set(gui_ctx.sliders[.TintBlue], i32(i2p_ctx.tint[2]), 255, true)

   gui.radiobutton_set(gui_ctx.sample_sample_mode[i2p_ctx.sample_mode], true, false)
   gui.radiobutton_set(gui_ctx.sample_scale_mode[int(i2p_ctx.scale_relative)], true, false)
   gui.radiobutton_set(gui_ctx.dither_dither_mode[i2p_ctx.dither_mode], true, false)
   gui.radiobutton_set(gui_ctx.dither_colour_dist[i2p_ctx.colour_dist], true, false)
   gui.radiobutton_set(gui_ctx.palette_colours[i2p_ctx.colour_selected], true, false)

   gui.checkbutton_set(gui_ctx.palette_kmeanspp, i2p_ctx.kmeanspp, true ,false)

   gui_ctx.block_process = false
}
