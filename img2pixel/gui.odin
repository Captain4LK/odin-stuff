package main

import "core:fmt"
import "core:mem"
import "core:log"
import "core:bytes"
import "core:strconv"
import "core:image/png"
import "core:image/qoi"
import "core:image/tga"
import "core:image/bmp"
import "core:image/netpbm"
import "core:image"
import "base:runtime"
import "vendor:sdl3"

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
}


@(private="file")
gui_ctx: GuiCtx

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

gui_construct :: proc()
{
   prof.SCOPED_EVENT(#procedure)

   win: ^gui.Window = gui.window_create("img2pixel", 1000, 600, "test.png")
   win.msg_user = main_window_msg
   window_root = win

   menus: [3]^gui.Element
   menus[0] = gui.menu_create(win, {no_parent = true, overlay = true, style = 1}, {fill_x = true}, {"Image", "Preset", "Palette"}, menu_load_msg)
   menus[1] = gui.menu_create(win, {no_parent = true, overlay = true, style = 1}, {fill_x = true}, {"Image", "Preset", "Palette"}, menu_save_msg)
   menus[2] = gui.menu_create(win, {no_parent = true, overlay = true, style = 1}, {fill_x = true}, {"Batch", "File watch"}, menu_tools_msg)

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
      #partial switch SliderType(s.usr)
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
         i2p_ctx.tint[0] = u8(s.value)
         str: string = fmt.aprintf("%v", i2p_ctx.tint[1])
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.TintGreen], str)
         gui_process(2)
      case .TintBlue:
         i2p_ctx.tint[0] = u8(s.value)
         str: string = fmt.aprintf("%v", i2p_ctx.tint[2])
         defer delete(str)
         gui.entry_set(gui_ctx.slider_entries[.TintBlue], str)
         gui_process(2)
      }
   }

   return 0
}

@(private="file")
slider_button_sub_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   return 0
}

@(private="file")
slider_button_add_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   return 0
}

@(private="file")
slider_entry_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   entry: ^gui.Entry = &e.derived.(gui.Entry)

   if msg == .TEXTINPUT_END
   {
      #partial switch SliderType(entry.usr)
      {
      case .Blur:
         value: f32 = f32(strconv.atof(string(entry.entry[:])))
         gui.slider_set(gui_ctx.sliders[.Blur], i32(value * 16), 512, true)
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

   return 0
}

@(private="file")
radiobutton_dither_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   return 0
}

@(private="file")
radiobutton_palette_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   if msg == .GET_WIDTH
   {
      return i64(16 * gui.get_scale())
   }
   else if msg == .GET_HEIGHT
   {
      return i64(16 * gui.get_scale())
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

   return 0
}

@(private="file")
kmeans_pp_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

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
         gui.open_file_dialog(e.window, 0, {{"test", "*"}}, nil, false)
         //filter: [1]sdl3.DialogFileFilter
         //filter[0] = {"all", "*"}
         //context_copy := new(runtime.Context)
         //context_copy^ = context
         //sdl3.ShowOpenFileDialog(load_image_callback, context_copy, nil, &filter[0], 1, nil, false)
         gui_ctx.dialog_open = true
      }
   }

   return 0
}

@(private="file")
menu_save_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   return 0
}

@(private="file")
menu_tools_msg :: proc(e: ^gui.Element, msg: gui.Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

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
      }
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
      image64_blur(img, i2p_ctx.blur_amount + 1)

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

      gui_ctx.cache_sample = image64_sample(img, width, height, 4, 0, 0)
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
   gui_ctx.block_process = true
   load_preset(path, &i2p_ctx)

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
