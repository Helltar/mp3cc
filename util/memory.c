/********************************************************************
	
	memory.c - memory handling routines

  Niksa Orlic, 2005-03-22

********************************************************************/

#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "memory.h"
#include "error.h"
//#include "message.h"

#define SLOWLIST 1

static memory_object* memory_object_list_begin = NULL;
static memory_object* memory_object_list_end = NULL;

/*
	every live block is also indexed by its address. mem_free and mem_realloc used to
	walk the whole list from its first block to find the one they were handed, so each
	call cost as much as there were live blocks, and a unit of a few tens of kilobytes
	took minutes to compile on a phone. the list itself stays: mem_close still frees
	whatever was left in it, and a pointer that is not in it is still ignored.
*/
#define HASH_BITS 16
#define HASH_SIZE (1 << HASH_BITS)

static memory_object* memory_object_hash[HASH_SIZE];

static unsigned int hash_of(char *data)
{
	uintptr_t value = (uintptr_t) data;

	return ((unsigned int) (value >> 4) * 2654435761u) >> (32 - HASH_BITS);
}

static void hash_insert(memory_object *object)
{
	unsigned int bucket = hash_of(object->data);

	object->hash_next = memory_object_hash[bucket];
	memory_object_hash[bucket] = object;
}

/* takes the block that owns the address out of the index, NULL if there is none */
static memory_object* hash_remove(char *data)
{
	memory_object **link = &memory_object_hash[hash_of(data)];

	while (*link != NULL)
	{
		memory_object *object = *link;

		if (object->data == data)
		{
			*link = object->hash_next;
			return object;
		}

		link = &object->hash_next;
	}

	return NULL;
}


/*
	Initialize the list of memory objects
*/
void mem_init()
{
	memory_object_list_begin = (memory_object*)malloc(sizeof(memory_object));
	memory_object_list_begin->next = NULL;
	memory_object_list_begin->prev = NULL;
	memory_object_list_begin->data = NULL;
	memory_object_list_begin->hash_next = NULL;
	memory_object_list_end = memory_object_list_begin;
	memset(memory_object_hash, 0, sizeof(memory_object_hash));
}

/*
	Clean up the list of memory objects
*/
void mem_close()
{
	memory_object *it = memory_object_list_begin;
	memory_object *old_object;

	while (it != NULL)
	{		
		old_object = it;
		it = it->next;
#if SLOWLIST
		if (old_object->data != NULL)
			free(old_object->data);
		free(old_object);
#else
		mem_free(old_object);
#endif
	}
}

/*
	Allocate the new block of memory and append it into the list
*/
void* mem_alloc(size_t s)
{
#if SLOWLIST
	memory_object *wrapper = (memory_object*)malloc(sizeof(memory_object));	
#else
	memory_object *wrapper = (memory_object*)malloc(sizeof(memory_object) + s);
#endif	
	if (wrapper == NULL)
		return NULL;

#if SLOWLIST
	wrapper->data = malloc(s);
	if (wrapper->data == NULL)
		return NULL;
#else	
	wrapper->data = (char*)wrapper + sizeof(memory_object);
#endif

	wrapper->next = NULL;
	wrapper->prev = memory_object_list_end;
	memory_object_list_end->next = wrapper;
	memory_object_list_end = wrapper;

#if SLOWLIST
	hash_insert(wrapper);
#endif

	if (memory_object_list_end == NULL)
		die(26);

	return wrapper->data;
}


/*
	Reallocate the new block of memory and append it into the list
*/
void* mem_realloc(char* old_block, int s)
{
	memory_object *wrapper;
	memory_object *prev, *next;

	void *new_block;

	prev = next = NULL;

#if SLOWLIST
	/* a block that was never allocated here is a plain allocation */
	if (old_block == NULL)
		return mem_alloc(s);

	/* find the block */
	{
		memory_object *it = hash_remove(old_block);

		it->data = realloc(it->data, s);
		hash_insert(it);

		return it->data;
	}
#else
	prev = ((memory_object*)(old_block - sizeof(memory_object)))->prev;
	next = ((memory_object*)(old_block - sizeof(memory_object)))->next;

	new_block = realloc(old_block - sizeof(memory_object), sizeof(memory_object) + s);

	if (new_block == NULL)
	{
		mem_free(old_block);
		return NULL;
	}

	if ((old_block - sizeof(memory_object)) == new_block)
		return old_block;

	wrapper = (memory_object*) new_block;

	if (prev != NULL)
		prev->next = wrapper;
	wrapper->prev = prev;

	if (next != NULL)
		next->prev = wrapper;
	wrapper->next = next;

	mem_free(old_block);

	return wrapper->data;
#endif
}

/*
	Free the block of memory
*/
void mem_free(char* old_block)
{	
	memory_object *prev, *next;

	prev = next = NULL;

	if (old_block == NULL)
		return;	

#if SLOWLIST
	/* find the block */
	{
		memory_object *it = hash_remove(old_block);

		if (it == NULL)
			return;

		prev = it->prev;
		next = it->next;

		free(old_block);
		free(it);
	}
#else
	prev = ((memory_object*)(old_block - sizeof(memory_object)))->prev;
	next = ((memory_object*)(old_block - sizeof(memory_object)))->next;

	free(old_block - sizeof(memory_object));
#endif

	if (prev != NULL)	
		prev->next = next;
	
	if (next != NULL)
		next->prev = prev;

	if (next == NULL)
		memory_object_list_end = prev;

	if (memory_object_list_end == NULL)
	{
		int a = 1;
	}

}