package gui

import "core:log"
import "core:strings"
import "vendor:sdl3"

import "../prof"

Button :: struct
{
   using element: Element,

   state: bool,
   text: string,
}

button_create :: proc(parent: ^Element, flags: ElementFlags, str: string) -> ^Button
{
   prof.SCOPED_EVENT(#procedure)

   button: ^Button = &element_create(Button, parent, flags, button_msg).derived.(Button)
   button.text = strings.clone(str)

   return button
}

@(private="file")
button_msg :: proc(e: ^Element, msg: Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   button: ^Button = &e.derived.(Button)

   if msg == .GET_WIDTH
   {
      return i64(len(button.text)) * i64(GLYPH_WIDTH * get_scale()) + i64(10 * get_scale())
   }
   else if msg == .GET_HEIGHT
   {
      return i64(GLYPH_HEIGHT * get_scale()) + i64(8 * get_scale())
   }
   else if msg == .MOUSE_LEAVE
   {
      state_old: bool = button.state
      button.state = false
      if state_old != button.state
      {
         element_redraw(button)
      }
   }
   else if msg == .MOUSE
   {
      mouse: ^Mouse = cast(^Mouse)dp

      if button.state
      {
         mouse.handled = true
      }

      click: bool = false
      state_old: bool = button.state
      if card(mouse.button & {.LEFT, .RIGHT, .MIDDLE}) > 0
      {
         button.state = true
         mouse.handled = true
      }
      else
      {
         click = button.state
         button.state = false
      }

      if click || state_old != button.state
      {
         element_redraw(button)
      }

      if click
      {
         element_msg(button, .CLICK, 0, nil)
         button.state = false
      }
   }
   else if msg == .DRAW
   {
      button_draw(button)
   }
   else if msg == .DESTROY
   {
      delete(button.text)
   }

   return 0
}

@(private="file")
button_draw :: proc(button: ^Button)
{
   if button.flags.style == 0
   {
      bounds: Rect = button.bounds
      scale: i32 = get_scale()
      draw_rectangle_fill(button, {bounds.min + scale, bounds.max - scale}, {90, 90, 90, 255})
      draw_rectangle(button, bounds, {0, 0, 0, 255})

      if button.state
      {
         draw_rectangle_fill(button, {{bounds.min[0] + scale, bounds.min[1] + 2 * scale},
            {bounds.min[0] + 2 * scale, bounds.max[1] - 2 * scale}}, {0, 0, 0, 255})
         draw_rectangle_fill(button, {{bounds.min[0] + scale, bounds.max[1] - 2 * scale},
            {bounds.max[0] - 2 * scale, bounds.max[1] - scale}}, {0, 0, 0, 255})
         draw_rectangle_fill(button, {{bounds.max[0] - 2 * scale, bounds.min[1] + 2 * scale},
            {bounds.max[0] - scale, bounds.max[1] - 2 * scale}}, {50, 50, 50, 255})
         draw_rectangle_fill(button, {{bounds.min[0] + 2 * scale, bounds.min[1] + scale},
            {bounds.max[0] - scale, bounds.min[1] + 2 * scale}}, {50, 50, 50, 255})
      }
      else
      {
         draw_rectangle_fill(button, {{bounds.min[0] + scale, bounds.min[1] + 2 * scale},
            {bounds.min[0] + 2 * scale, bounds.max[1] - 2 * scale}}, {50, 50, 50, 255})
         draw_rectangle_fill(button, {{bounds.min[0] + scale, bounds.max[1] - 2 * scale},
            {bounds.max[0] - 2 * scale, bounds.max[1] - scale}}, {50, 50, 50, 255})
         draw_rectangle_fill(button, {{bounds.max[0] - 2 * scale, bounds.min[1] + 2 * scale},
            {bounds.max[0] - scale, bounds.max[1] - 2 * scale}}, {200, 200, 200, 255})
         draw_rectangle_fill(button, {{bounds.min[0] + 2 * scale, bounds.min[1] + scale},
            {bounds.max[0] - scale, bounds.min[1] + 2 * scale}}, {200, 200, 200, 255})
      }

      draw_label(button, button.bounds, button.text, {0, 0, 0, 255}, true)
   }
}
