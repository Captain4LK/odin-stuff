package prof

import "core:sync"
import "core:prof/spall"

@(private="file")
spall_ctx: spall.Context
@(private="file")
@(thread_local) spall_buffer: spall.Buffer
@(private="file")
buffer_backing: []u8

init :: proc()
{
   spall_ctx = spall.context_create("trace_test.spall")
   //defer spall.context_destroy(&spall_ctx)

   buffer_backing = make([]u8, spall.BUFFER_DEFAULT_SIZE)
      //defer delete(buffer_backing)

   spall_buffer = spall.buffer_create(buffer_backing, u32(sync.current_thread_id()))
      //defer spall.buffer_destroy(&spall_ctx, &spall_buffer)

      //spall.SCOPED_EVENT(&spall_ctx, &spall_buffer, #procedure)
}

@(deferred_in=_scoped_buffer_end)
@(no_instrumentation)
SCOPED_EVENT :: proc(name: string, args: string = "", location := #caller_location) -> bool {
	spall._buffer_begin(&spall_ctx, &spall_buffer, name, args, location)
	return true
}

@(no_instrumentation)
_scoped_buffer_end :: proc(_, _: string, _ := #caller_location) {
	spall._buffer_end(&spall_ctx, &spall_buffer)
}

destroy :: proc()
{
   spall.buffer_destroy(&spall_ctx, &spall_buffer)
   delete(buffer_backing)
   spall.context_destroy(&spall_ctx)
}
