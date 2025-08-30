package gui

import "core:log"
import "core:strings"
import "vendor:sdl3"

Slider :: struct
{
   using element: Element,

   value: i32,
   range: i32,
   direction: i32,
}

slider_create :: proc(parent: ^Element, flags: ElementFlags, direction: i32) -> ^Slider
{
   slider: ^Slider = &element_create(Slider, parent, flags, slider_msg).derived.(Slider)
   slider.direction = direction
   slider.range = 100
   slider.value = 100

   return slider
}

slider_set :: proc(slider: ^Slider, value: i32, range: i32, trigger_msg: bool)
{
   if slider == nil do return

   if slider.value != value || slider.range != range
   {
      slider.value = max(0, min(range, value))
      slider.range = range
      if trigger_msg
      {
         element_msg(slider, .SLIDER_VALUE_CHANGED, 0, nil)
      }
   }
}

@(private="file")
slider_msg :: proc(e: ^Element, msg: Msg, di: int, dp: rawptr) -> int
{
   slider: ^Slider = &e.derived.(Slider)

   if msg == .GET_WIDTH
   {
      return int(GLYPH_HEIGHT * get_scale() + 8 * get_scale())
   }
   else if msg == .GET_HEIGHT
   {
      return int(GLYPH_HEIGHT * get_scale() + 8 * get_scale())
   }
   else if msg == .DRAW
   {
      slider_draw(slider)
   }
   else if msg == .MOUSE
   {
      mouse: ^Mouse = cast(^Mouse)dp

      if card(mouse.button & {.LEFT, .RIGHT, .MIDDLE}) > 0
      {
         mouse.handled = true

         if slider.direction == 0
         {
            mx: i32 = i32(mouse.pos.x) - slider.bounds.min.x
            width: i32 = slider.bounds.max.x - slider.bounds.min.x - get_scale() * 6
            value: i32 = (mx * slider.range) / max(1, width)
            value = max(0, value)
            value = min(slider.range, value)

            if slider.value != value
            {
               slider.value = value
               element_msg(slider, .SLIDER_VALUE_CHANGED, 0, nil)
               element_redraw(slider)
            }
         }
         else
         {
            my: i32 = slider.bounds.max.y - i32(mouse.pos.y)
            height: i32 = slider.bounds.max.y - slider.bounds.min.y - 6 * get_scale()
            value: i32 = (my * slider.range) / height
            value = max(0, min(slider.range, value))
            
            if slider.value != value
            {
               slider.value = value
               element_msg(slider, .SLIDER_VALUE_CHANGED, 0, nil)
               element_redraw(slider)
            }
         }

         return 1
      }
   }

   return 0
}

@(private="file")
slider_draw :: proc(slider: ^Slider)
{
   scale: i32 = get_scale()
   bounds: Rect = slider.bounds

   if slider.direction == 0
   {
      draw_rectangle_fill(slider, bounds, {90, 90, 90, 255})

      draw_rectangle_fill(slider, {{bounds.min.x + scale, bounds.min.y + 2 * scale}, 
         {bounds.min.x + 2 * scale, bounds.max.y - scale}}, {50, 50, 50, 255})
      draw_rectangle_fill(slider, {{bounds.min.x + scale, bounds.max.y - 2 * scale}, 
         {bounds.max.x - 2 * scale, bounds.max.y - scale}}, {50, 50, 50, 255})

      draw_rectangle_fill(slider, {{bounds.max.x - 2 * scale, bounds.min.y + 2 * scale}, 
         {bounds.max.x - 1 * scale, bounds.max.y - 2 * scale}}, {200, 200, 200, 255})
      draw_rectangle_fill(slider, {{bounds.min.x + 2 * scale, bounds.min.y + 1 * scale}, 
         {bounds.max.x - 1 * scale, bounds.min.y + 2 * scale}}, {200, 200, 200, 255})

      width: i32 = (slider.value * (bounds.max.x - bounds.min.x - scale * 6)) / slider.range
      draw_rectangle_fill(slider, {{bounds.min.x + 3 * scale, bounds.min.y + 3 * scale},
         {bounds.min.x + 3 * scale + width, bounds.max.y - 3 * scale}}, {50, 50, 50, 255})
   }
   else if slider.direction == 1
   {
      draw_rectangle_fill(slider, bounds, {90, 90, 90, 255})

      draw_rectangle_fill(slider, {{bounds.min.x + scale, bounds.min.y + 2 * scale}, 
         {bounds.min.x + 2 * scale, bounds.max.y - scale}}, {50, 50, 50, 255})
      draw_rectangle_fill(slider, {{bounds.min.x + scale, bounds.max.y - 2 * scale}, 
         {bounds.max.x - 2 * scale, bounds.max.y - scale}}, {50, 50, 50, 255})

      draw_rectangle_fill(slider, {{bounds.max.x - 2 * scale, bounds.min.y + 2 * scale}, 
         {bounds.max.x - 1 * scale, bounds.max.y - 2 * scale}}, {200, 200, 200, 255})
      draw_rectangle_fill(slider, {{bounds.min.x + 2 * scale, bounds.min.y + 1 * scale}, 
         {bounds.max.x - 1 * scale, bounds.min.y + 2 * scale}}, {200, 200, 200, 255})

      height: i32 = (slider.value * (bounds.max.y - bounds.min.y - scale * 6)) / slider.range
      draw_rectangle_fill(slider, {{bounds.min.x + 3 * scale, bounds.max.y - 3 * scale - height},
         {bounds.max.x - 3 * scale, bounds.max.y - 3 * scale}}, {50, 50, 50, 255})
   }
}
