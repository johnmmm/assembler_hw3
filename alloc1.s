.section .data

msg:
	.ascii "you get it!\n"
	len = .-msg

#This points to the beginning of the memory
heap_begin:
.long 0
#This points to one location past the memory we are managing
current_break:
.long 0

#size of space for memory region header
.equ HEADER_SIZE, 8
#Location of the "available" flag in the header
.equ HDR_AVAIL_OFFSET, 0
#Location of the size field in the header
.equ HDR_SIZE_OFFSET, 4

.equ UNAVAILABLE, 0
.equ AVAILABLE, 1
.equ SYS_BRK, 45	#system call number for brk
.equ LINUX_SYSCALL, 0x80

#alloc.s
.section .text

.globl allocate_init
.type allocate_init, @function
allocate_init:
	pushl %ebp
	movl %esp, %ebp
	
	#If the brk system call is called with 0 in %ebx, 
	#it returns the first invalid address
	movl $SYS_BRK, %eax
	movl $0, %ebx
	int $LINUX_SYSCALL
	movl %eax, current_break #%eax now has the first invalid address
	movl %eax, heap_begin

	movl %ebp, %esp #exit the function
	popl %ebp
	ret

.globl allocate
.type allocate, @function
.equ ST_MEN_SIZE, 8	#stack position of the memory size to allocate
allocate:
	pushl %ebp
	movl %esp, %ebp
	movl ST_MEN_SIZE(%ebp), %ecx #%ecx will hold the size

	#We are looking for (which is the first only parameter)
	movl heap_begin, %eax #%eax will hold the search location
	movl current_break, %ebx #%ebx will hold the current break	

	loop_begin:		#we iterate through memory regions
		#cmpl %ebx, %eax #need more memory if these are equal
		movl %eax, %edi
		addl %ecx, %edi
		addl $HEADER_SIZE, %edi
		addl $HEADER_SIZE, %edi
		cmpl %edi, %ebx
		pushl %eax
        			
		jl move_break

		#grab the size of this memory
		movl HDR_SIZE_OFFSET(%eax), %edx
		cmpl $UNAVAILABLE, HDR_AVAIL_OFFSET(%eax)
		je next_location	#if unavailable, go to the next
		cmpl %edx, %ecx  #if available, check the size
		jle allocate_here	#big enough, go to allocate_here

	next_location:	
		addl $HEADER_SIZE, %eax
		addl $HEADER_SIZE, %eax
		addl %edx, %eax	#The total size of the memory
		jmp loop_begin

	allocate_here:
		#if we have made it here, that means the region header of the 
		#region to allocate is in %eax, mark space as unavailable
		movl $UNAVAILABLE, HDR_AVAIL_OFFSET(%eax)
		#addl $HEADER_SIZE, %eax  #move %eax to usable memory
		movl HDR_SIZE_OFFSET(%eax), %edi
		movl %ecx, HDR_SIZE_OFFSET(%eax)

		#set %edi as the size
		subl $HEADER_SIZE, %edi
		subl $HEADER_SIZE, %edi
		subl %ecx, %edi

		addl $HEADER_SIZE, %eax
		pushl %eax	#save the actual place

		addl %ecx, %eax		#write tailor
		movl $UNAVAILABLE, HDR_AVAIL_OFFSET(%eax)
		movl %ecx, HDR_SIZE_OFFSET(%eax)

		addl $HEADER_SIZE, %eax		#write header
		movl $AVAILABLE, HDR_AVAIL_OFFSET(%eax)
		movl %edi, HDR_SIZE_OFFSET(%eax)

		addl $HEADER_SIZE, %eax		#write tailor
		addl %edi, %eax
		movl $AVAILABLE, HDR_AVAIL_OFFSET(%eax)
		movl %edi, HDR_SIZE_OFFSET(%eax)

		popl %eax
	
		movl %ebp, %esp
		popl %ebp
		ret
	
	move_break:
		movl %ebx, %eax
		addl $HEADER_SIZE, %ebx
		addl $HEADER_SIZE, %ebx #add space for the headers structure
		#addl %ecx, %ebx   	#add space to the break for the data request
		
		#movl %ecx, %esi
		#addl $HEADER_SIZE, %esi
		#addl $HEADER_SIZE, %esi
		movl $512, %edi
	do_mul:
		addl $512, %edi		#enlarge the brk
		cmpl %edi, %ecx
		jl continue_move
                jmp do_mul
		
	continue_move:
		addl %edi, %ebx
		pushl %eax		#save needed registers
		movl $SYS_BRK, %eax	#reset the break
		int $LINUX_SYSCALL
		popl %eax		#no error check?
	
		#set this memory as unavailable, since we're about to give it away
		movl $UNAVAILABLE, HDR_AVAIL_OFFSET(%eax)
		movl %ecx, HDR_SIZE_OFFSET(%eax)

		#set %edi as the size
		subl $HEADER_SIZE, %edi
		subl $HEADER_SIZE, %edi
		subl %ecx, %edi

		addl $HEADER_SIZE, %eax
		pushl %eax	#save the place %eax

		#set the tail of this place
		addl %ecx, %eax
		movl $UNAVAILABLE, HDR_AVAIL_OFFSET(%eax)
		movl %ecx, HDR_SIZE_OFFSET(%eax)

		addl $HEADER_SIZE, %eax		#write header
		movl $AVAILABLE, HDR_AVAIL_OFFSET(%eax)
		movl %edi, HDR_SIZE_OFFSET(%eax)

		addl %edi, %eax		#write tail header
		addl $HEADER_SIZE, %eax
		movl $AVAILABLE, HDR_AVAIL_OFFSET(%eax)
		movl %edi, HDR_SIZE_OFFSET(%eax)
		popl %eax	#read the exact place of this pointer
		
		#movl %ecx, HDR_SIZE_OFFSET(%eax) #set the size of the memory
		#move %eax to the actual start of
						 #usable memory
		movl %ebx, current_break	 #save the new break
	
		movl %ebp, %esp
		popl %ebp
		ret

.globl deallocate
.type deallocate, @function
.equ ST_MEMORY_SEG, 4

deallocate:
	movl ST_MEMORY_SEG(%esp), %eax
	#get the pointer to the real beginning of the memory
	subl $HEADER_SIZE, %eax
	#mark it as available
	movl $AVAILABLE, HDR_AVAIL_OFFSET(%eax)
	pushl %eax
	movl HDR_SIZE_OFFSET(%eax), %edi
	addl $HEADER_SIZE, %eax
	addl %edi, %eax
	movl $AVAILABLE, HDR_AVAIL_OFFSET(%eax)
	popl %eax
	pushl %eax	#save ti

	front_merge:
		movl %eax, %ecx
		cmpl heap_begin, %eax
		je back_merge
		
		subl $HEADER_SIZE, %eax
		cmpl $UNAVAILABLE, HDR_AVAIL_OFFSET(%eax)
		je back_merge
		
	front_begin:
		subl HDR_SIZE_OFFSET(%eax), %eax
		subl $HEADER_SIZE, %eax
		addl HDR_SIZE_OFFSET(%eax), %edi
		addl $HEADER_SIZE, %edi
		addl $HEADER_SIZE, %edi
		movl %edi, HDR_SIZE_OFFSET(%eax)
		movl %eax, %ecx		#use %ecx to record the left head
		jmp front_merge

	back_merge:
		popl %eax
	back_merge1:
		cmpl current_break, %eax
		je end_de

		movl HDR_SIZE_OFFSET(%eax), %edx
		addl %edx, %eax		#move to the tail and update it
		addl $HEADER_SIZE, %eax
		movl %edi, HDR_SIZE_OFFSET(%eax)
		addl $HEADER_SIZE, %eax
		cmpl $UNAVAILABLE, HDR_AVAIL_OFFSET(%eax)#end if unavailable
		je end_de

	back_begin:
		addl HDR_SIZE_OFFSET(%eax), %edi
		addl $HEADER_SIZE, %edi		#come into next place
		addl $HEADER_SIZE, %edi
		movl %edi, HDR_SIZE_OFFSET(%ecx)#update the size
		jmp back_merge1

	end_de:

	ret
