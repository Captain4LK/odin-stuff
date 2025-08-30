package gui

import "core:log"
import "core:strings"
import "vendor:sdl3"

CheckButton :: struct
{
   using element: Element,

   state: bool,
   checked: bool,
   text: string,
}

checkbutton_create :: proc(parent: ^Element, flags: ElementFlags, str: string) -> ^CheckButton
{
   button: ^CheckButton = &element_create(CheckButton, parent, flags, checkbutton_msg).derived.(CheckButton)
   button.text = strings.clone(str)

   return button
}

@(private="file")
checkbutton_msg :: proc(e: ^Element, msg: Msg, di: int, dp: rawptr) -> int
{
   button: ^CheckButton = &e.derived.(CheckButton)

   if msg == .GET_WIDTH
   {
      return (GLYPH_HEIGHT + 8) * int(get_scale()) + len(button.text) * int(GLYPH_WIDTH * get_scale()) + int(10 * get_scale())
   }
   else if msg == .GET_HEIGHT
   {
      return int(GLYPH_HEIGHT * get_scale()) + int(8 * get_scale())
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

      if click
      {
         button.checked = !button.checked
         element_msg(button, .CLICK, int(button.checked), nil)
         button.state = false
      }

      if click|| state_old != button.state
      {
         element_redraw(button)
      }
      /*
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
      */
   }
   else if msg == .DRAW
   {
      checkbutton_draw(button)
   }
   else if msg == .DESTROY
   {
      delete(button.text)
   }

   return 0
}

@(private="file")
checkbutton_draw :: proc(button: ^CheckButton)
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

      height: i32 = (bounds.max.y - bounds.min.y)
      dim: i32 = GLYPH_HEIGHT * scale
      offset: i32 = (height - dim) / 2

      draw_rectangle_fill(button, {{bounds.min.x + offset + scale, bounds.min.y + offset + scale}, 
         {bounds.min.x + offset + 2 * scale, bounds.max.y - offset}}, {200, 200, 200, 255})
      draw_rectangle_fill(button, {{bounds.min.x + offset + scale, bounds.max.y - offset - scale}, 
         {bounds.min.x + offset + dim, bounds.max.y - offset}}, {200, 200, 200, 255})

      draw_rectangle_fill(button, {{bounds.min.x + offset + 2 * scale, bounds.min.y + offset}, 
         {bounds.min.x + offset + dim + scale, bounds.min.y + offset + scale}}, {50, 50, 50, 255})
      draw_rectangle_fill(button, {{bounds.min.x + dim + offset, bounds.min.y + offset + scale}, 
         {bounds.min.x + offset + dim + scale, bounds.max.y - offset - scale}}, {50, 50, 50, 255})

      draw_label(button, {{bounds.min.x + dim + 2 * scale, bounds.min.y}, bounds.max}, button.text, {0, 0, 0, 255}, true)

      if button.checked
      {
         draw_label(button, {{bounds.min.x + offset + 3 * scale, bounds.min.y + offset + scale},
            {bounds.min.x + offset + scale + dim, bounds.min.y + offset + scale + dim}}, "X", {0, 0, 0, 255}, true)
      }
   }
}
