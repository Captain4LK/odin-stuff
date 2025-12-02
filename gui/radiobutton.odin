package gui

import "core:log"
import "core:strings"
import "vendor:sdl3"

import "../prof"

RadioButton :: struct
{
   using element: Element,

   state: bool,
   checked: bool,
   text: string,
}

radiobutton_create :: proc(parent: ^Element, flags: ElementFlags, str: string) -> ^RadioButton
{
   prof.SCOPED_EVENT(#procedure)

   button: ^RadioButton = &element_create(RadioButton, parent, flags, radiobutton_msg).derived.(RadioButton)
   button.text = strings.clone(str)

   radiobutton_set(button, false, false)

   return button
}

radiobutton_set :: proc(button: ^RadioButton, trigger_msg: bool, redraw: bool)
{
   prof.SCOPED_EVENT(#procedure)

   if button == nil do return

   previously: bool = button.checked
   if button.parent != nil
   {
      for child in button.parent.children
      {
         _, ok := child.derived.(RadioButton)
         if !ok do continue

         c: ^RadioButton = &child.derived.(RadioButton)
         if c.checked && trigger_msg && c != button
         {
            element_msg(c, .CLICK, 0, nil)
         }
         c.checked = false
      }
   }

   button.checked = true
   if redraw
   {
      if button.parent != nil
      {
         element_redraw(button.parent)
      }
      else
      {
         element_redraw(button)
      }
   }

   if trigger_msg && !previously
   {
      element_msg(button, .CLICK, 1, nil)
   }
}

@(private="file")
radiobutton_msg :: proc(e: ^Element, msg: Msg, di: i64, dp: rawptr) -> i64
{
   prof.SCOPED_EVENT(#procedure)

   button: ^RadioButton = &e.derived.(RadioButton)

   if msg == .GET_WIDTH
   {
      return (GLYPH_HEIGHT + 8) * i64(get_scale()) + i64(len(button.text)) * i64(GLYPH_WIDTH * get_scale()) + i64(10 * get_scale())
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

      if click
      {
         radiobutton_set(button, true, true)
         //button.checked = !button.checked
         //element_msg(button, .CLICK, int(button.checked), nil)
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
      radiobutton_draw(button)
   }
   else if msg == .DESTROY
   {
      delete(button.text)
   }

   return 0
}

@(private="file")
radiobutton_draw :: proc(button: ^RadioButton)
{
   bounds: Rect = button.bounds
   scale: i32 = get_scale()

   if button.flags.style == 0
   {
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
         draw_rectangle_fill(button, {{bounds.min[0] + offset + 4 * scale, bounds.min[1] + offset + 3 * scale},
            {bounds.min[0] + dim + offset - 2 * scale, bounds.min[1] + offset + dim - 3 * scale}}, {0, 0, 0, 255})
         //draw_label(button, {{bounds.min.x + offset + 3 * scale, bounds.min.y + offset + scale},
            //{bounds.min.x + offset + scale + dim, bounds.min.y + offset + scale + dim}}, "X", {0, 0, 0, 255}, true)
      }
   }
   else if button.flags.style == 1
   {
      if button.state
      {
         draw_rectangle_fill(button, bounds, {50, 50, 50, 255})
      }
      else
      {
         draw_rectangle_fill(button, bounds, {90, 90, 90, 255})
      }

      // Checkbox
      height: i32 = bounds.max.y - bounds.min.y
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
         draw_rectangle_fill(button, {{bounds.min[0] + offset + 4 * scale, bounds.min[1] + offset + 3 * scale},
            {bounds.min[0] + dim + offset - 2 * scale, bounds.min[1] + offset + dim - 3 * scale}}, {0, 0, 0, 255})
      }
   }
   else if button.flags.style == 2
   {
      if button.checked
      {
         draw_rectangle_fill(button, bounds, {50, 50, 50 ,255})
      }
      else
      {
         draw_rectangle_fill(button, bounds, {90, 90, 90 ,255})
      }

      dim: i32 = GLYPH_HEIGHT * scale
      draw_label(button, {{bounds.min.x + dim + 2 * scale, bounds.min.y}, bounds.max}, button.text, {0, 0, 0, 255}, true)
   }
}
