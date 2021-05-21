! ok, the read went well so we get current cursor position and save it for
! posterity.
! 获取光标位置 =>  0x9000:0      ! 现在将光标位置保存以备今后使用。
	mov  	 ax,#INITSEG	! 将ds置成#INITSEG(0x9000)。这已经在bootsect程序中设置过，但是现在是setup程序，Linus觉得需要再重新设置一下。
	mov 	 ds,ax
	mov 	 ah,#0x03	! BIOS中断0x10的读光标功能号ah = 0x03。输入：bh = 页号。返回：ch = 扫描开始线，cl = 扫描结束线，dh = 行号(0x00是顶端)，dl = 列号(0x00是左边)。
	xor 	 bh,bh
	int 	 0x10		! save it in known place, con_init fetches
	mov 	 [0],dx		! it from 0x90000. 上两句是说将光标位置信息存放在0x90000处，控制台初始化时会来取。

! Get memory size (extended mem, kB)
! 获取拓展内存大小 => 0x9000:2。 下面3句取扩展内存的大小值（KB）。是调用中断0x15，功能号ah = 0x88，返回：ax = 从0x100000（1M）处开始的扩展内存大小(KB)。
	mov  	 ah,#0x88
	int 	 0x15
	mov 	 [2],ax          ! 将扩展内存数值存在0x90002处（1个字）。

! Get hd0 data
! 获取硬盘参数 => 0x9000:80  大小：16B
	mov 	 ax,#0x0000
	mov 	 ds,ax
	lds 	 si,[4*0x41]
	mov 	 ax,#INITSEG
	mov 	 es,ax
	mov 	 di,#0x0080
	mov 	 cx,#0x10
	rep
	movsb
! first we move the system to it's rightful place
! 首先我们将system模块移到正确的位置。
! bootsect引导程序是将system模块读入到从0x10000（64k）开始的位置。由于当时假设
! system模块最大长度不会超过0x80000（512k），也即其末端不会超过内存地址0x90000，
! 所以bootsect会将自己移动到0x90000开始的地方，并把setup加载到它的后面。
! 下面这段程序的用途是再把整个system模块移动到0x00000位置，即把从0x10000到0x8ffff
! 的内存数据块(512k)，整块地向内存低端移动了0x10000（64k）的位置。
       mov      ax,#0x0000
       cld                     ! 'direction'=0, movs moves forward
       do_move:
       mov      es,ax           ! destination segment ! es:di目的地址(初始为0x0000:0x0)
       add      ax,#0x1000
       cmp      ax,#0x9000      ! 已经把从0x8000段开始的64k代码移动完？
       jz       end_move
       mov      ds,ax           ! source segment  ! ds:si源地址(初始为0x1000:0x0)
       sub      di,di
       sub      si,si
       mov      cx,#0x8000! 移动0x8000字（64k字节）。
       rep
       movsw
       jmp      do_move



! 这里设置进入32位保护模式运行。首先加载机器状态字(lmsw-Load Machine Status Word)，也称控制寄存器CR0，其比特位0置1将导致CPU工作在保护模式。
       mov      ax,#0x0001      ! protected mode (PE) bit ! 保护模式比特位(PE)。
       mov      cr0,ax		! This isit! !就这样加载机器状态字。  将cr0的PE位置置为1，说明此时此刻CPU进入保护模式。 (补充：cr0的PE位置为0时，代表CPU处于实模式，为1时，处于保护模式)
       jmpi     0,8             ! jmp offset 0 of segment 8 (cs) ! 跳转至cs段8，偏移0处。
! 我们已经将system模块移动到0x00000开始的地方，所以这里的偏移地址是0。这里的段值的8已经是保护模式下的段选择符了，用于选择描述符表和描述符表项以及所要求的特权级。
! 段选择符长度为16位（2字节）；位0-1表示请求的特权级0-3，linux操作系统只用到两级：0级（系统级）和3级（用户级）；位2用于选择全局描述符表(0)还是局部描述符表(1)；
! 位3-15是描述符表项的索引，指出选择第几项描述符。所以段选择符8(0b0000,0000,0000,1000)表示请求特权级0、使用全局描述符表中的第1项，该项指出代码的基地址是0（参见209行），
! 因此这里的跳转指令就会去执行system中的代码。



















! 前面修改了ds寄存器，这里将其设置为0x9000
	mov 	 ax,#INITSEG
	mov 	 ds,ax
	mov 	 ax,#SETUPSEG
	mov 	 es,ax  

!显示 Cursor POS: 字符串
	mov    	 ah,#0x03		! read cursor pos
	xor 	 bh,bh
	int 	 0x10
	mov 	 cx,#11
	mov 	 bx,#0x0007		! page 0, attribute c 
	mov 	 bp,#cur
	mov 	 ax,#0x1301		! write string, move cursor
	int 	 0x10

!调用 print_hex 显示具体信息
	mov      ax,[0]
	call     print_hex
	call     print_nl

!显示 Memory SIZE: 字符串
	mov 	 ah,#0x03		! read cursor pos
	xor 	 bh,bh
	int 	 0x10
	mov 	 cx,#12
	mov 	 bx,#0x0007		! page 0, attribute c 
	mov 	 bp,#mem
	mov 	 ax,#0x1301		! write string, move cursor
	int 	 0x10

!显示 具体信息
	mov      ax,[2]
	call     print_hex

!显示相应 提示信息
	mov 	 ah,#0x03		! read cursor pos
	xor 	 bh,bh
	int 	 0x10
	mov 	 cx,#25
	mov 	 bx,#0x0007		! page 0, attribute c 
	mov 	 bp,#cyl
	mov 	 ax,#0x1301		! write string, move cursor
	int 	 0x10

!显示具体信息
	mov      ax,[0x80]
	call     print_hex
	call     print_nl

！显示 提示信息
	mov 	 ah,#0x03		! read cursor pos
	xor 	 bh,bh
	int 	 0x10
	mov 	 cx,#8
	mov 	 bx,#0x0007		! page 0, attribute c 
	mov 	 bp,#head
	mov 	 ax,#0x1301		! write string, move cursor
	int 	 0x10

！显示 具体信息
	mov      ax,[0x80+0x02]
	call     print_hex
	call     print_nl

！显示 提示信息
	mov 	 ah,#0x03		! read cursor pos
	xor 	 bh,bh
	int 	 0x10
	mov 	 cx,#8
	mov 	 bx,#0x0007		! page 0, attribute c 
	mov 	 bp,#sect
	mov 	 ax,#0x1301		! write string, move cursor
	int 	 0x10

！显示 具体信息
	mov      ax,[0x80+0x0e]
	call     print_hex
	call     print_nl

!死循环
l:  jmp l

!以16进制方式打印ax寄存器里的16位数
print_hex:
	mov 	 cx,#4   ! 4个十六进制数字
	mov 	 dx,ax   ! 将ax所指的值放入dx中，ax作为参数传递寄存器
print_digit:
	rol 	 dx,#4  ! 循环以使低4比特用上 !! 取dx的高4比特移到低4比特处。
	mov 	 ax,#0xe0f  ! ah = 请求的功能值,al = 半字节(4个比特)掩码。
	and 	 al,dl ! 取dl的低4比特值。
	add 	 al,#0x30  ! 给al数字加上十六进制0x30
	cmp 	 al,#0x3a
	jl  	 outp  !是一个不大于十的数字
	add      al,#0x07  !是a~f,要多加7
outp:
	int      0x10
	loop     print_digit
	ret

!打印回车换行
print_nl:
	mov 	 ax,#0xe0d
	int 	 0x10
	mov 	 al,#0xa
	int 	 0x10
	ret

msg1:
	.byte    13,10
	.ascii   "Now we are in setup..."
	.byte    13,10,13,10
cur:
	.ascii   "Cursor POS:"
mem:
	.ascii   "Memory SIZE:"
cyl:
	.ascii   "KB"
	.byte    13,10,13,10
	.ascii   "HD Info"
	.byte    13,10
	.ascii   "Cylinders:"
head:
	.ascii   "Headers:"
sect:
	.ascii   "Secotrs:"

.text
endtext:
.data
enddata:
.bss
endbss:
