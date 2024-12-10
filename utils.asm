####################  LIBRARY START  ####################
.text
# macros START
// load a 64-bit immediate using MOV
.macro movq Xn, imm
    movz    \Xn,  \imm & 0xFFFF
    movk    \Xn, (\imm >> 16) & 0xFFFF, lsl 16
    movk    \Xn, (\imm >> 32) & 0xFFFF, lsl 32
    movk    \Xn, (\imm >> 48) & 0xFFFF, lsl 48
.endm

// load a 32-bit immediate using MOV
.macro movl Wn, imm
    movz    \Wn,  \imm & 0xFFFF
    movk    \Wn, (\imm >> 16) & 0xFFFF, lsl 16
.endm
# macros END

# functions START
_exit:
    # args: x0, u8 return status
    # NORET
    mov x8, 0x5d
    brk 0

_puts_no_newline:
    # args: x0 (string to print)
    # returns: none
    mov x2, 0
    mov x1, x0
    _str_len_loop_puts_no_newline:
    ldrb w3, [x1]
    add x2, x2, 1
    add x1, x1, 1
    cmp x3, 0
    b.ne _str_len_loop_puts_no_newline
    sub x2, x2, 1
    mov x8, 0x40
    mov x1, x0
    # x2 already set to string length
    mov x0, 1
    brk 0
    ret

_puts:
    # args: x0 (string to print)
    # returns: none
    mov x2, 0
    mov x1, x0
    _str_len_loop_puts:
    ldrb w3, [x1]
    add x2, x2, 1
    add x1, x1, 1
    cmp x3, 0
    b.ne _str_len_loop_puts
    sub x2, x2, 1
    mov x8, 0x40
    mov x1, x0
    # x2 already set to string length
    mov x0, 1
    brk 0

    # newline
    mov x8, 0x40
    mov x0, 1
    adr x1, _newline
    mov x2, 1
    brk 0
    ret

_print_hex:
    # args: x0 (raw uint64_t value to print), x1 (0:no newline, 1: include newline)
    # returns: none

    # locals
    #     0 == u64: index
    #     8 == u64: x0 copy
    #  0x10 == u64: link register
    #  0x18 == u64: x1 (newline print)
    sub sp, sp, 0x20
    str x30, [sp, 0x10]
    str x1, [sp, 0x18]
    mov x1, 64
    str x1, [sp]
    str x0, [sp, 8]

    # write out the 0x first
    mov x0, 1
    adr x1, _0x
    mov x2, 2
    mov x8, 0x40
    brk 0

    _print_hex_loop:
        ldr x7, [sp]
        sub x7, x7, 4
        str x7, [sp]

        ldr x1, [sp, 8]
        lsr x1, x1, x7
        and x2, x1, 0xf

        adr x1, _ascii_hex
        add x1, x1, x2

        mov x8, 0x40
        mov x0, 1
        # x1 set already
        mov x2, 1
        brk 0

        ldr x7, [sp]
        cmp x7, 0
        b.gt _print_hex_loop

    ldr x1, [sp, 0x18]
    cmp x1, 1
    b.ne _no_newline_requested
        # newline
        mov x8, 0x40
        mov x0, 1
        adr x1, _newline
        mov x2, 1
        brk 0
    _no_newline_requested:

    ldr x30, [sp, 0x10]
    add sp, sp, 0x20
    ret

_print_dec:
    # args: x0 (raw uint64_t value to print), x1 (0:no newline, 1: include newline)
    # returns: none

    # locals
    #     0 == index
    #     8 == link register
    #  0x10 == newline flag (x1)
    #  0x18 == string_ptr
    #  0x20 == x0 backup
    sub sp, sp, 0x28
    str x30, [sp, 8]
    str x1, [sp, 0x10]
    str x0, [sp, 0x20]

    cmp x0, 0
    b.ne _print_dec_not_zero
        # 0
        mov x8, 0x40
        mov x0, 1
        adr x1, _ascii_hex
        mov x2, 1
        brk 0

        # newline
        mov x8, 0x40
        mov x0, 1
        adr x1, _newline
        mov x2, 1
        brk 0
        
        b _print_end
    _print_dec_not_zero:

    # unsigned(18446744073709551615), 0x14 bytes + 1 null byte
    # signed(9223372036854775807 to -9223372036854775808), 0x14 bytes + 1 null byte (version 2)
    mov x0, 0x15
    bl _malloc
    # assume this works
    str x0, [sp, 0x18]
    
    ldr x1, [sp, 0x20]
    mov x2, 1
    mov x3, 0xa
    mov x4, 0
    _print_dec_loop:
        cmp x2, x1
        b.gt _print_dec_loop_done
        udiv x5, x1, x2
        
        get_under_10:
            cmp x3, x5
            b.gt no_need_to_truncate
            sub x5, x5, x3
            b get_under_10
        no_need_to_truncate:
        # figure out the next character to write
        ldr x0, [sp, 0x18]
        add x6, x0, 0x14
        sub x6, x6, x4

        # convert to ascii
        add x5, x5, 0x30
        strb w5, [x6]
        add x4, x4, 1
        mul x2, x2, x3
        b _print_dec_loop
    _print_dec_loop_done:

    ldr x0, [sp, 0x18]
    add x0, x0, 0x15
    sub x0, x0, x4
    ldr x1, [sp, 0x10]
    bl _puts

    ldr x0, [sp, 0x18]
    bl _free

    _print_end:
    ldr x30, [sp, 8]
    add sp, sp, 0x28
    ret

_print_hex_n:
    # args: x0 (value to print)
    # returns: none

    # locals
    # 0 == saved x30
    sub sp, sp, 8
    str x30, [sp]
    mov x1, 1
    bl _print_hex
    ldr x30, [sp]

    # locals
    add sp, sp, 8
    ret

_print_dec_n:
    # args: x0 (value to print)
    # returns: none

    # locals
    # 0 == saved x30
    sub sp, sp, 8
    str x30, [sp]
    mov x1, 1
    bl _print_dec
    ldr x30, [sp]

    # locals
    add sp, sp, 8
    ret

_free:
    # args: x0 (size of object to allocate)
    # returns: x0 (0 if successful, -1 if an error occurs)

    # uint64_t _free(void* object) {
    #     if (!_heap_location_ptr)
    #         return -1;
    ldr x8, _heap_location_ptr
    cbz x8, _free_failure
    #     
    #     heap_struct* curr = (heap_struct*)((uint64_t)object - _chunk_size);
    sub x8, x0, _chunk_size

    ldr x9, [x8]

    #     printf("object=0x%lx freeing target @ 0x%lx\n", (uint64_t)object, (uint64_t)curr);
    #     // tag this as free
    #     curr->size--;
    sub x9, x9, 1
    str x9, [x8]
    # 
    #     // check if we can coalesce forwards
    #     if (((uint64_t)curr->next->size & 1) == 0) {
    ldr x11, [x8, 0x10]
    ldr x12, [x11]
    and x12, x12, 1
    cmp x12, 0
    b.ne _free_cannot_coalesce_forwards
    #         curr->size += (curr->next->size);
    ldr x9, [x8]
    ldr x11, [x8, 0x10]
    ldr x12, [x11]
    add x9, x9, x12
    str x9, [x8]
    #         curr->next->next->prev = curr;
    ldr x11, [x8, 0x10]
    ldr x12, [x11, 0x10]
    str x8, [x12, 8]
    #         curr->next = curr->next->next;
    ldr x11, [x8, 0x10]
    ldr x12, [x11, 0x10]
    str x12, [x8, 0x10]
    #         printf(" coalesced forwards!\n");
    #     }
    _free_cannot_coalesce_forwards:
    # 
    #     // make sure that we don't coalesce twice when we have an empty heap
    #     if ((curr != curr->next) && (curr != curr->prev)) {
    ldr x11, [x8, 0x10]
    cmp x8, x11
    b.eq _free_cannot_coalesce_twice
    ldr x10, [x8, 8]
    cmp x8, x10
    b.eq _free_cannot_coalesce_twice
    #         // check if we can coalesce backwards
    #         if (((uint64_t)curr->prev->size & 1) == 0) {
    ldr x10, [x8, 8]
    ldr x12, [x10]
    and x12, x12, 1
    cmp x12, 0
    b.ne _free_cannot_coalesce_backwards
    #             curr->prev->size += (curr->size);
    ldr x13, [x8]
    ldr x10, [x8, 8]
    ldr x12, [x10]
    add x12, x12, x13
    ldr x10, [x8, 8]
    str x12, [x10]
    #             curr->prev->next = curr->next;
    ldr x12, [x8, 0x10]
    ldr x13, [x8, 8]
    ldr x11, [x8, 0x10]
    str x11, [x13, 0x10]
    #             curr->next->prev = curr->prev;
    ldr x12, [x8, 8]
    ldr x13, [x8, 0x10]
    str x12, [x13, 8]
    #             printf(" coalesced backwards!\n");
    #         }
    _free_cannot_coalesce_backwards:
    #     }
    _free_cannot_coalesce_twice:
    # 
    mov x0, 0
    b _free_success
    _free_failure:
    mov x0, -1
    _free_success:
    ret
    #     return 0;
    # }


_malloc:
    # args: x0 (size of object to allocate)
    # returns: x0 (pointer to object if allocation, otherwise -1 if error occurs)

    # locals
    # 0 == size
    sub sp, sp, 0x8

    # if ((requested_size % 8) != 0)
    #     requested_size += 8 - (requested_size % 8);
    and x1, x0, 7
    cmp x1, 0
    b.eq _malloc_no_need_to_align_to_8_bytes
    mov x2, 8
    sub x1, x2, x1
    add x0, x0, x1
    _malloc_no_need_to_align_to_8_bytes:

    # requested_size += _chunk_size;
    add x0, x0, _chunk_size

    str x0, [sp]

    # if (!_heap_location_ptr) {
    ldr x8, _heap_location_ptr
    cbnz x8, _malloc__heap_ready
    #     _heap_location_ptr = (uint64_t*)mmap(0,
    #                                          _heap_size,
    #                                          _PROT_READ | _PROT_WRITE,
    #                                          _MAP_ANONYMOUS | _MAP_PRIVATE,
    #                                          0,
    #                                          0);
    # make a svc call to mmap a [_heap_size] page. version 2 of this should grow and shring mmap'd pages!
    # void *mmap(void *addr, size_t len, int prot, int flags, int fd, off_t offset)
    mov x8, 0xde //mmap
    mov x0, 0
    mov x1, _heap_size
    mov x2, _PROT_READ | _PROT_WRITE
    mov x3, _MAP_ANONYMOUS | _MAP_PRIVATE
    mov x4, 0
    mov x5, 0
    brk 0
    adr x1, _heap_location_ptr
    str x0, [x1]
    #     heap_struct* init = (heap_struct*)_heap_location_ptr;
    #     init->size = _heap_size - _chunk_size;
    mov x2, _heap_size
    sub x1, x2, _chunk_size
    str x1, [x0]
    #     init->prev = (heap_struct*)_heap_location_ptr;
    str x0, [x0, 0x8]
    #     init->next = (heap_struct*)_heap_location_ptr;
    str x0, [x0, 0x10]
    mov x8, x0
    # }
    _malloc__heap_ready:

    ldr x17, [sp]
    # x0 is the ptr to the heap
    # x8 is curr ptr to the current chunk
    # x9 size
    # x10 prev ptr
    # x11 next_ptr
    # x12 is scratch
    # x17 is requested size
    # x18 is the terminus

    # // traverse the heap
    # printf(" traversing the heap for free mem size=0x%lx\n", requested_size);
    # heap_struct* curr = (heap_struct*)_heap_location_ptr;
    adr x8, _heap_location_ptr
    ldr x8, [x8]
    mov x18, x8
    # do {
    _malloc_traverse_heap_loop:
        ldr x9, [x8]
        ldr x10, [x8, 8]
        ldr x11, [x8, 0x10]

    #     // see if this chunk is in-use
    #     if ((curr->size & 1) == 0) {
        and x12, x9, 1
        cmp x12, 1
        b.eq _malloc_chunk_in_use
    #         printf(" curr is FREE (size=0x%lx @ 0x%lx)\n",curr->size, (uint64_t)curr);
    #         // is this chunk big enough for us?
    #         if (curr->size >= requested_size) {
        cmp x9, x17
        b.lt _malloc_chunk_not_big_enough
    #             printf(" this chunk is big enough for us!(size=0x%lx)\n", curr->size);
    #             // can we subdivide this chunk?
    #             if (curr->size - (_chunk_size+8) >= requested_size) {
        sub x12, x9, _chunk_size
        add x12, x12, 8
        cmp x12, x17
        b.lt _malloc_unable_to_subdivide_chunk
    #                 uint64_t old_size = curr->size;
        # x13 == old_size
        mov x13, x9
    #                 printf(" we can subdivide this chunk\n");
    #                 curr->size = requested_size + 1; // mark as in-use
        add x12, x17, 1
        str x12, [x8]
    #                 // init the new chunk
    #                 uint64_t next = (uint64_t)curr + requested_size;
        # x14 == next
        add x14, x8, x17
    #                 printf(" next = 0x%lx\n", next);
    #                 heap_struct* new = (heap_struct*)next;
        # x15 == new
        mov x15, x14
    #                 printf(" new = 0x%lx\n", (uint64_t)new);
    #                 new->size = old_size - requested_size;
        sub x12, x13, x17
        str x12, [x15]
    #                 printf("old_size=0x%lx, new_size=0x%lx @ 0x%lx\n", old_size, new->size, (uint64_t)&new->size);
    #                 new->prev = curr;
        str x8, [x15, 8]
    #                 new->next = curr->next;
        str x11, [x15, 0x10]
    #                 // update the next->prev pointer to point at it
    #                 new->next->prev = new;
        ldr x12, [x15, 0x10]
        str x15, [x12, 8]
    #                 // update the curr entry
    #                 curr->next = new;
        str x15, [x8, 0x10]
    #                 // zero out the data section
    #                 for (int i=0; i < requested_size - _chunk_size; i++) {
        mov x12, 0
        mov x15, 0
        sub x13, x17, _chunk_size
        add x14, x8, 0x18
        _malloc_bzero:
    #                     curr->data[i] = 0;
            strb w15, [x14, x12]

            add x12, x12, 1
            cmp x12, x13
            b.lt _malloc_bzero
    #                 }
    #                 return (void*)((uint64_t)curr + _chunk_size;
            add x0, x8, _chunk_size
            b _malloc_success
    #             } else {
        _malloc_unable_to_subdivide_chunk:
    #                 printf(" we can't subdivide this chunk, so we're gonna use all of it!\n");
    #                 curr->size += 1; // mark as in-use
            add x12, x9, 1
            str x12, [x8]
    #                 // we don't have to change our previous or following heap structure
    #                 // pointers because we are consuming the whole chunk
    #                 return (void*)((uint64_t)curr + _chunk_size;
            add x0, x8, _chunk_size
            b _malloc_success
    #             }
    #         } else {
        _malloc_chunk_not_big_enough:
    #             printf(" this chunk is not big enough for us! (size=0x%lx)\n", curr->size);
    #             curr = curr->next;
            mov x8, x11
            b _malloc_traverse_heap_loop_end
    #         }
    #     } else {
        _malloc_chunk_in_use:
    #         printf(" curr is in-use (size=0x%lx @ 0x%lx)\n", curr->size, (uint64_t)curr);
    #         curr = curr->next;
        mov x8, x11
        # yeah, I know. I just want to be explicit about PC flow
        b _malloc_traverse_heap_loop_end
    #     }
        _malloc_traverse_heap_loop_end:
        cmp x18, x8
        b.ne _malloc_traverse_heap_loop
    # } while (((uint64_t*)curr) != _heap_location_ptr);
    # return (void*)-1;
    _malloc_fail:
        mov x0, -1
    _malloc_success:

    # locals
    add sp, sp, 0x8
    ret

_open:
    # args: x0 (char* filename), x1 (int flags), x2 (int mode)
    # returns: x0 set to fd on success, -1 on error

    # 56      openat  man/ cs/        0x38    int dfd const char *filename    int flags       umode_t mode    -       -
    mov x8, 0x38
    mov x3, x2
    mov x2, x1
    mov x1, x0
    mov x0, -100
    brk 0
    ret

_read:
    # args: x0 (fd), x1 (dest_buf), x2 (bytes to read)
    # returns: x0 set to # bytes read or -1 on error

    # 63      read    man/ cs/        0x3f    unsigned int fd char *buf       size_t count    -       -       -
    mov x8, 0x3f
    brk 0
    ret

_close:
    # args: x0 (int fd)
    # returns: x0 set to 0 on success or -1 on error

    # 57      close   man/ cs/        0x39    unsigned int fd -       -       -       -       -
    mov x8, 0x39
    brk 0
    ret

_read_line_to_string:
    # args: x0 (int fd)
    # returns: x0 (heap allocated string that was read in)

    # locals
    #  0x00: fd
    #  0x08: malloc'd ptr
    #  0x10: amt_read / index
    #  0x18: x30
    sub sp, sp, 0x20
    str x30, [sp, 0x18]
    str x0, [sp]
    mov x1, -1
    str x1, [sp, 0x10]

    mov x0, 0x400
    bl _malloc
    cmp x0, -1
    b.eq _read_line_to_string_fail
    str x0, [sp, 0x8]

    _read_line_to_string_loop:
        # read a byte
        ldr x0, [sp]
        ldr x1, [sp, 0x8]
        ldr x2, [sp, 0x10]
        add x2, x2, 1
        str x2, [sp, 0x10]
        add x1, x1, x2
        mov x2, 1
        bl _read
        # add the byte to our string
        cmp x0, 1
        b.ne _read_line_to_string_success
        # check if it's a newline, if so we bail without including it in the string!
        ldr x1, [sp, 0x8]
        ldr x2, [sp, 0x10]
        add x1, x1, x2
        ldrb w0, [x1]
        and x0, x0, 0xff
        cmp x0, 0x0a
        b.eq _read_line_to_string_success
        cmp x2, 0x400
        # if we have read over 0x400 bytes, we need to malloc more, but that's V2
        b.ge _read_line_to_string_fail
        b _read_line_to_string_loop
        
    _read_line_to_string_success:
        ldr x0, [sp, 0x08]
        ldr x1, [sp, 0x10]
        add x2, x0, x1
        mov x3, 0
        strb w3, [x2]
        b _read_line_to_string_ret
        
    _read_line_to_string_fail:
        ldr x0, [sp, 0x08]
        bl _free

        mov x0, -1
        ldr x1, [sp, 0x10]

    _read_line_to_string_ret:
    
    # locals
    ldr x30, [sp, 0x18]
    add sp, sp, 0x20
    ret

_atoi:
    # args: x0: pointer to string
    # returns: x0: value as u64, x1: failure_flag

    # locals
    #  0 == index
    #  8 == num_so_far
    sub sp, sp, 0x10
    mov x1, 0
    str x1, [sp]
    str x1, [sp, 8]

    cmp x0, 0
    b.eq _atoi_failure

    # check if begins with 0x, else use decimal
    # 0x30 == 0
    ldr x2, [sp]
    ldrb w1, [x0, x2]
    cmp x1, 0x30
    b.ne _atoi_parse_normal_number
    ldr x2, [sp]
    add x2, x2, 1
    str x2, [sp]
    # 0x78 == x
    ldr x2, [sp]
    ldrb w1, [x0, x2]
    cmp x1, 0x78
    b.ne _atoi_parse_normal_number
    ldr x2, [sp]
    add x2, x2, 1
    str x2, [sp]
    # we are parsing a hex number

    _atoi_parse_hex_loop:
        ldr x2, [sp, 8]
        ldr x1, [sp]
        ldrb w3, [x0, x1]
        # we read in a byte, if it's a non-number, we are done
        # 0x30 - 0x39 | 0x61 - 0x66 (inclusive)
        cmp x3, 0x30
        b.lt _atoi_parse_hex_loop_NAN
        cmp x3, 0x39
        b.le _atoi_parse_hex_loop_OK_n
        cmp x3, 0x61
        b.le _atoi_parse_hex_loop_NAN
        cmp x3, 0x66
        b.gt _atoi_parse_hex_loop_NAN
        b _atoi_parse_hex_loop_OK_x

        _atoi_parse_hex_loop_OK_n:
            sub x3, x3, 0x30
            b _atoi_parse_hex_loop_OK

        _atoi_parse_hex_loop_OK_x:
            sub x3, x3, 0x60
            b _atoi_parse_hex_loop_OK

        _atoi_parse_hex_loop_OK:
            lsl x3, x3, 8
            add x3, x3, x2
            str x3, [sp, 8]
        b _atoi_parse_hex_loop
    
    _atoi_parse_hex_loop_NAN:
        mov x1, 0
        ldr x0, [sp, 8]
        b _atoi_success

    _atoi_parse_normal_number:
    # we are parsing a decimal number
        # x0 == ptr to string
        #  0 == index
        #  8 == num_so_far
        mov x1, -1
        str x1, [sp]

        _atoi_parse_number_loop:
            ldr x2, [sp, 8]
            ldr x1, [sp]
            add x1, x1, 1
            str x1, [sp]
            ldrb w3, [x0, x1]

            cmp x3, 0x30
            b.lt _atoi_parse_number_loop_NAN
            cmp x3, 0x39
            b.gt _atoi_parse_number_loop_NAN
            sub x3, x3, 0x30

            mov x4, 0xa
            madd x5, x4, x2, x3
            str x5, [sp, 8]
            b _atoi_parse_number_loop

    _atoi_parse_number_loop_NAN:
        mov x1, 0
        ldr x0, [sp, 8]
        b _atoi_success

    _atoi_failure:
        mov x0, 0
        mov x1, 1
    _atoi_success:

        # locals
        add sp, sp, 0x10
        ret

_find:
    # args: x0 (haystack), x1 (needle)
    # returns: x0 (offset to leftmost substring or -1 if not found)
    
    # x2 == base_index
    mov x2, 0
    # x8 == sliding window
    mov x8, 0
    # x3 == substring_index
    mov x3, 0

    _find_loop:
        mov x2, x8
        mov x3, 0
        _find_substring_loop:
            ldrb w4, [x0, x2]
            ldrb w5, [x1, x3]

            cmp w5, 0
            b.eq _find_success

            cmp w4, 0
            b.eq _find_failure

            cmp w4, w5
            b.eq _find_got_additional_char
            b _find_didnt_find_additiona_char

            _find_got_additional_char:
                add x2, x2, 1
                add x3, x3, 1
                b _find_substring_loop

            _find_didnt_find_additiona_char:
                mov x3, 0
                add x8, x8, 1
                b _find_loop

    _find_failure:
        mov x0, 0
        sub x0, x0, 1
        ret

    _find_success:
        mov x0, x8
        ret

_rfind:
    # args: x0 (haystack), x1 (needle)
    # returns: x0 (offset to rightmost substring or -1 if not found)

    # locals
    # 0 = x19
    sub sp, sp, 8
    str x19, [sp]

    # find length of haystack
    mov x6, 0
    _rfind_get_length_of_haystack:
    ldrb w3, [x0, x6]
    cmp w3, 0
    b.eq _rfind_got_length_of_haystack
    add x6, x6, 1
    b _rfind_get_length_of_haystack
    _rfind_got_length_of_haystack:
    sub x6, x6, 1

    # find length of needle
    mov x7, 0
    _rfind_get_length_of_needle:
    ldrb w3, [x1, x7]
    cmp w3, 0
    b.eq _rfind_got_length_of_needle
    add x7, x7, 1
    b _rfind_get_length_of_needle
    _rfind_got_length_of_needle:
    sub x7, x7, 1

    
    # x2 == base_index
    mov x2, x6
    # x8 == sliding window
    mov x8, x6
    # x3 == substring_index
    mov x3, x7

    _rfind_loop:
        mov x2, x8
        mov x3, x7
        _rfind_substring_loop:
            movq x19, 0xffffffffffffffff
            cmp x3, x19
            b.eq _rfind_success

            cmp x2, x19
            b.eq _rfind_failure


            ldrb w4, [x0, x2]
            ldrb w5, [x1, x3]

            cmp w4, w5
            b.eq _rfind_got_additional_char
            b _rfind_didnt_find_additiona_char

            _rfind_got_additional_char:
                sub x2, x2, 1
                sub x3, x3, 1
                b _rfind_substring_loop

            _rfind_didnt_find_additiona_char:
                mov x3, 0
                sub x8, x8, 1
                b _rfind_loop

    _rfind_failure:
        mov x0, 0
        sub x0, x0, 1
        b _rfind_ret

    _rfind_success:
        sub x0, x8, x7
    
    _rfind_ret:
        ldr x19, [sp]
        add sp, sp, 8
        ret

# Stupid shit to remind you
#  svc call numbers go in x8, args in x0,x1,x2,x3,etc
#  X0 – X7      arguments and return value
#  X8 – X18     temporary registers
#  X19 – X28    callee-saved registers
#  X29	        frame pointer
#  X30	        link register
#  SP(X31)      stack pointer

# aarch64 linux ABI implicit rules for registers
# x0 – x7 are used to pass parameters and return values. The value of these registers may
# be freely modified by the called function (the callee) so the caller cannot assume
# anything about their content, even if they are not used in the parameter passing or for
# the returned value. This means that these registers are in practice caller-saved.
# 
# x8 – x18 are temporary registers for every function. No assumption can be made on their
# values upon returning from a function. In practice these registers are also caller-saved.
# 
# x19 – x28 are registers, that, if used by a function, must have their values preserved
# and later restored upon returning to the caller. These registers are known as callee-saved.
# 
# x29 can be used as a frame pointer and x30 is the link register. The callee should save
# x30 if it intends to call a subroutine.
# functions END

#################### CONSTANTS START ####################
# internal library constants
_heap_size          = 0x1000000
_chunk_size = 0x18

# memory flags
_PROT_NONE  = 0
_PROT_READ  = 1
_PROT_WRITE = 2
_PROT_EXEC  = 4

# memory tpes
_MAP_ANONYMOUS      = 0x20
_MAP_ANON           = 0x20
_MAP_FILE           = 0x0
_MAP_FIXED          = 0x10
_MAP_PRIVATE        = 0x02
_MAP_SHARED         = 0x1

# file flags
_O_RDONLY    = 0x0
_O_WRONLY    = 0x1
_O_RDWR      = 0x2

# file modes
_O_NONBLOCK      = 00004000
_O_APPEND        = 00002000
_O_CREAT         = 00000100
_O_TRUNC         = 00001000
_O_EXCL          = 0200
# O_SHLOCK        atomically obtain a shared lock
# O_EXLOCK        atomically obtain an exclusive lock
_O_DIRECTORY     = 00200000
_O_NOFOLLOW      = 00400000
# O_SYMLINK       allow open of symlinks
# O_EVTONLY       descriptor requested for event notifications only
_O_CLOEXEC       = 02000000
# O_NOFOLLOW_ANY  do not follow symlinks in the entire path.
#################### CONSTANTS END ####################
#################### INTERNALS START ####################
.align 4
_newline: .ascii "\n"
.align 4
_space: .ascii " "
.align 4
_0x: .ascii "0x"
.align 4
_ascii_hex: .ascii "0123456789abcdefx"
.align 4
.global _heap_location_ptr
_heap_location_ptr: .8byte 0x0000000000000000
#################### INTERNALS END ####################
#################### LIBRARY END ####################
