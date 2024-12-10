#include <stdint.h>
#include <stdio.h>
#include <sys/mman.h>

#define _heap_size 0x100000
#define _PROT_READ 1
#define _PROT_WRITE 2
#define _MAP_ANONYMOUS 0x20
#define _MAP_PRIVATE 0x02

typedef struct heap_struct {
    uint64_t size;
    struct heap_struct* prev;
    struct heap_struct* next;
    char data[8];
} heap_struct;

#define _chunk_size (sizeof(heap_struct) - 8)

uint64_t* _heap_location_ptr = 0;

void dump_heap() {
    for (int i=0;i<(0x400/8);i++) {
        uint64_t addr = (uint64_t)_heap_location_ptr+8*i;
        printf("  0x%lx: 0x%lx\n", addr, *((uint64_t*)addr));
    }
}

uint64_t _free(void* object) {
    if (!_heap_location_ptr)
        return -1;
    
    heap_struct* curr = (heap_struct*)((uint64_t)object - _chunk_size);
    printf("object=0x%lx freeing target @ 0x%lx\n", (uint64_t)object, (uint64_t)curr);
    // tag this as free
    curr->size--;

    // check if we can coalesce forwards
    if (((uint64_t)curr->next->size & 1) == 0) {
        curr->size += (curr->next->size);
        curr->next->next->prev = curr;
        curr->next = curr->next->next;
        printf(" coalesced forwards!\n");
    }

    // make sure that we don't coalesce twice when we have an empty heap
    if ((curr != curr->next) && (curr != curr->prev)) {
        // check if we can coalesce backwards
        if (((uint64_t)curr->prev->size & 1) == 0) {
            curr->prev->size += (curr->size);
            curr->prev->next = curr->next;
            curr->next->prev = curr->prev;
            printf(" coalesced backwards!\n");
        }
    }

    return 0;
}

void* _malloc(uint64_t requested_size) {
    if ((requested_size % 8) != 0)
        requested_size += 8 - (requested_size % 8);
    requested_size += _chunk_size;
    

    if (!_heap_location_ptr) {
        _heap_location_ptr = (uint64_t*)mmap(0,
                                             _heap_size,
                                             _PROT_READ | _PROT_WRITE,
                                             _MAP_ANONYMOUS | _MAP_PRIVATE,
                                             0,
                                             0);
        heap_struct* init = (heap_struct*)_heap_location_ptr;
        init->size = _heap_size - _chunk_size;
        init->prev = (heap_struct*)_heap_location_ptr;
        init->next = (heap_struct*)_heap_location_ptr;
    }

    // traverse the heap
    printf(" traversing the heap for free mem size=0x%lx\n", requested_size);
    heap_struct* curr = (heap_struct*)_heap_location_ptr;
    do {
        // see if this chunk is in-use
        if ((curr->size & 1) == 0) {
            printf(" curr is FREE (size=0x%lx @ 0x%lx)\n",curr->size, (uint64_t)curr);
            // is this chunk big enough for us?
            if (curr->size >= requested_size) {
                printf(" this chunk is big enough for us!(size=0x%lx)\n", curr->size);
                // can we subdivide this chunk?
                if (curr->size - (_chunk_size+8) >= requested_size) {
                    uint64_t old_size = curr->size;
                    printf(" we can subdivide this chunk\n");
                    curr->size = requested_size + 1; // mark as in-use
                    // init the new chunk
                    uint64_t next = (uint64_t)curr + requested_size;
                    printf(" next = 0x%lx\n", next);
                    heap_struct* new = (heap_struct*)next;
                    printf(" new = 0x%lx\n", (uint64_t)new);
                    new->size = old_size - requested_size;
                    printf("old_size=0x%lx, new_size=0x%lx @ 0x%lx\n", old_size, new->size, (uint64_t)&new->size);
                    new->prev = curr;
                    new->next = curr->next;
                    // update the next->prev pointer to point at it
                    new->next->prev = new;
                    // update the curr entry
                    curr->next = new;
                    // zero out the data section
                    for (int i=0; i < requested_size - _chunk_size; i++) {
                        curr->data[i] = 0;
                    }
                    return (void*)((uint64_t)curr + _chunk_size);
                } else {
                    printf(" we can't subdivide this chunk, so we're gonna use all of it!\n");
                    curr->size += 1; // mark as in-use
                    // we don't have to change our previous or following heap structure
                    // pointers because we are consuming the whole chunk
                    return (void*)((uint64_t)curr + _chunk_size);
                }
            } else {
                printf(" this chunk is not big enough for us! (size=0x%lx)\n", curr->size);
                curr = curr->next;
            }
        } else {
            printf(" curr is in-use (size=0x%lx @ 0x%lx)\n", curr->size, (uint64_t)curr);
            curr = curr->next;
        }
    } while (((uint64_t*)curr) != _heap_location_ptr);
    return (void*)-1;
}

int main(int argc, char** argv) {
    void* my_ptrs[4];
    printf("[+] Malloc & Free algorithms for re-implementation into aarch64 assembly for aoc 2022\n");
    
    my_ptrs[0] = _malloc(0x1);
    printf("[+] Malloc @ 0x%lx\n", (uint64_t)my_ptrs[0]);
    // dump_heap();
    
    my_ptrs[1] = _malloc(0x30);
    printf("[+] Malloc @ 0x%lx\n", (uint64_t)my_ptrs[1]);
    // dump_heap();

    my_ptrs[2] = _malloc(0x100);
    printf("[+] Malloc @ 0x%lx\n", (uint64_t)my_ptrs[2]);
    // dump_heap();

    my_ptrs[3] = _malloc(0x1);
    printf("[+] Malloc @ 0x%lx\n", (uint64_t)my_ptrs[3]);
    printf("before all the free's:\n");
    // dump_heap();

    for (int i=3; i >= 0; i--) {
        printf("[+] Freeing %d @ 0x%lx\n", i, (uint64_t)my_ptrs[i]);
        _free(my_ptrs[i]);
        // dump_heap();
    }
    printf("[i] heap state:\n");
    dump_heap();
    return 0;
}