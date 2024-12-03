call:
	mov rcx, 0x1401d7414 ; TLS
	mov ecx, dword ptr [rcx] ; ecx = TLS
	mov rax, 0x0123456789ABCDEF ; TlsGetValue addr
	call rax; call TlsGetValue
	mov r8, 0x0123456789ABCDEF ; string
	mov edx, 0xffffd8ee ; global
	mov r12, qword ptr [rax + 0x18] ; lua state
	mov rcx, r12 ; put lua in arg
	mov rax, 0x0123456789ABCDEF ; get top addr
	call rax; get func
	mov rcx, r12 ; put lua in arg (rcx clobbered)
	mov edx, 0 ; nargs
	mov r8d, 0 ; nresult
	; mov r9d, 0 ; err func
	; pcall was having issues so not using it
	mov rax, 0x0123456789ABCDEF ; call addr
	call rax; call func
	ret

