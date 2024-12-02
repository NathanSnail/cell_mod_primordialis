call:
	mov rcx, 0x1401d7414 
	mov ecx, dword ptr [rcx] 
	mov rax, 0x0123456789ABCDEF 
	call rax
	mov r8, 0x0123456789ABCDEF 
	mov edx, 0xffffd8ee 
	mov r12, qword ptr [rax + 0x18] 
	mov rcx, r12 
	mov rax, 0x0123456789ABCDEF 
	call rax
	mov rcx, r12 
	mov edx, 0 
	mov r8d, 0 
	
	
	mov rax, 0x0123456789ABCDEF 
	call rax
	ret

