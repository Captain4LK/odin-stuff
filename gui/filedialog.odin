package gui

import "../prof"

import "base:runtime"
import "core:log"
import "core:strings"
import "vendor:sdl3"

FileFilter :: struct
{
   name: string,
   pattern: string,
}

@(private)
DialogInternalCtx :: struct
{
   filters: []sdl3.DialogFileFilter,
   ident: i32,
   ctx: runtime.Context,
   window: ^Window,
}

OpenFileMsg :: struct
{
   ident: i32,
   file_list: []string,
   filter: i32,
}

SaveFileMsg :: struct
{
   ident: i32,
   file_list: []string,
   filter: i32,
}

OpenFolderMsg :: struct
{
   ident: i32,
   folder_list: []string,
}

open_file_dialog :: proc(window: ^Window, ident: i32, filters: []FileFilter, default_location: string, allow_many: bool)
{
   prof.SCOPED_EVENT(#procedure)

   ctx: ^DialogInternalCtx = new(DialogInternalCtx)
   ctx.ctx = context
   ctx.ident = ident
   ctx.window = window

   // Convert filters (we need a copy anyway)
   ctx.filters = make([]sdl3.DialogFileFilter, len(filters))
   for filter, idx in filters
   {
      ctx.filters[idx].name = strings.clone_to_cstring(filter.name)
      ctx.filters[idx].pattern = strings.clone_to_cstring(filter.pattern)
   }

   default_cstr: cstring = strings.clone_to_cstring(default_location)
   sdl3.ShowOpenFileDialog(open_file_callback, ctx, window.sdl_window, raw_data(ctx.filters), i32(len(ctx.filters)), default_cstr, allow_many)
   delete(default_cstr)
}

save_file_dialog :: proc(window: ^Window, ident: i32, filters: []FileFilter, default_location: string)
{
   prof.SCOPED_EVENT(#procedure)

   ctx: ^DialogInternalCtx = new(DialogInternalCtx)
   ctx.ctx = context
   ctx.ident = ident
   ctx.window = window

   // Convert filters (we need a copy anyway)
   ctx.filters = make([]sdl3.DialogFileFilter, len(filters))
   for filter, idx in filters
   {
      ctx.filters[idx].name = strings.clone_to_cstring(filter.name)
      ctx.filters[idx].pattern = strings.clone_to_cstring(filter.pattern)
   }

   default_cstr: cstring = strings.clone_to_cstring(default_location)
   sdl3.ShowSaveFileDialog(save_file_callback, ctx, window.sdl_window, raw_data(ctx.filters), i32(len(ctx.filters)), default_cstr)
   delete(default_cstr)
}

open_folder_dialog :: proc(window: ^Window, ident: i32, default_location: string, allow_many: bool)
{
   prof.SCOPED_EVENT(#procedure)

   ctx: ^DialogInternalCtx = new(DialogInternalCtx)
   ctx.ctx = context
   ctx.ident = ident
   ctx.window = window

   default_cstr: cstring = strings.clone_to_cstring(default_location)
   sdl3.ShowOpenFolderDialog(open_folder_callback, ctx, window.sdl_window, default_cstr, allow_many)
   delete(default_cstr)
}
