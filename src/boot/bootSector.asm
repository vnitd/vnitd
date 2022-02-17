;;
;; bootSector.asm: the prolouge of the OS
;;

use16
	org 0x7c00					; 'origin' of Boot code; helps make sure address won't change
	mov byte [drive_num], dl	; DL contain initial drive # on boot
	
	xor ax, ax
	mov es, ax			; ES = 0
	
	;; READ FILETABLE INTO MEMORY FIRST
	mov bl, 0x01		; Will be reading 2 sectors 
	mov di, 0x500		; Memory address to read sectors into (0x0000:0x1000)

	mov dx, 0x1f2		; Sector count port
	mov al, 0x02		; # of sector to read
	out dx, al

	mov dx, 0x1f3		; Sector # port
	mov al, 0x05		; Sector to start reading at (sectors are 1-based)
	out dx, al

	call load_sectors

	;; READ SECONDSTAGE INTO MEMORY SECOND
	mov bl, 0x02		; Will be reading 3 sectors 
	mov di, 0x7e00		; Memory address to read sectors into (0x0000:0x1000)

	mov dx, 0x1f2		; Sector count port
	mov al, 0x03		; # of sector to read
	out dx, al

	mov dx, 0x1f3		; Sector # port
	mov al, 0x02		; Sector to start reading at (sectors are 1-based)
	out dx, al

	call load_sectors
	
	;; READ KERNEL INTO MEMORY THIRD
	mov bl, 0x1F		; Will be reading 31 sectors 
	mov di, 0x900		; Memory address to read sectors into (0x0000:0x1000)

	mov dx, 0x1f2		; Sector count port
	mov al, 0x20		; # of sector to read
	out dx, al

	mov dx, 0x1f3		; Sector # port
	mov al, 0x07		; Sector to start reading at (sectors are 1-based)
	out dx, al

	call load_sectors

	mov dl, [drive_num]
	jmp 0x0:7e00h
load_sectors:
	mov dx, 0x1f6		; Head & drive # port
	mov al, [drive_num]	; Drive # - hard disk 1
	and al, 0xf			; Head # (low nibble)
	or  al, 0xa0		; default high nibble to 'primary' drive (drive 1), 'secondary' drive (drive 2)
						; would be hex B or 1011b
	out dx, al			; Send head/drive #

	mov dx, 0x1f4		; Cylinder low port
	xor al, al			; Cylinder low #
	out dx, al

	mov dx, 0x1f5		; Cylinder high port
	xor al, al			; Cylinder high #
	out dx, al

	mov dx, 0x1f7		; Command port (writing port 0x1f7)
	mov al, 0x20		; Read with retry
	out dx, al

	; Poll status port after reading 1 sector
	.loop:
		in  al, dx		; Status register (reading port 0x1f7)
		test al, 8		; Sector buffer requires servicing
		jz  .loop		; Keep trying until sector buffer is ready

		mov cx, 256		; # of words to read for 1 sector
		mov dx, 0x1f0	; Data port, reading
		rep insw		; Read bytes from DX port # into DI, CX # of times

		; 400ns delay - Read alternate status register
		mov dx, 0x3f6
		in  al, dx
		in  al, dx
		in  al, dx
		in  al, dx

		cmp bl, 0
		je  .return

		dec bl
		mov dx, 0x1f7
		jmp .loop
	.return:
		ret


drive_num: db 0
	times 510-($-$$) db 0
	dw 0xaa55