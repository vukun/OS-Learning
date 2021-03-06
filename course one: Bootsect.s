问题1：当对计算机进行开机操作时，计算机发生了什么？

    答案： (1)、首先计算机刚开机时，CPU是处于实模式下的。其寻址的方式是“段地址+偏移地址”。

           (2)、计算机开机时，代表代码的段寄存器CS=0xFFFFF;偏移地址IP=0x0000。这段是初始的代码区域，是事先写死在ROM中的，因为计算机开机总是要从
    去内存中取出指令进行执行。这段代码也是BIOS的映射区。其主要作用是：检查RAM、键盘、显示器、软硬磁盘是否正常。正常的话，继续向下执行。不正常的话
    就开不了机器了。

           (3)、然后，CS会指向磁盘的0磁道0扇区，其地址为0x7c00处。IP为0x0000。注意，一个扇区是512字节。该部分为操作系统的引导扇区 bootsect.s。
    引导扇区是启动设备的第一个扇区。也是存放着计算机开机后执行的第一段我们可以控制的程序。


问题2：bootsect.s的代码解读

    .globl begtext, begdata, begbss, endtext, enddata, endbss
    .text
    begtext:
    .data
    begdata:
    .bss
    begbss:
    .text

    SETUPLEN = 4			! setup程序代码占用扇区数
    BOOTSEG  = 0x07c0			! bootsect程序代码所在内存原始地址
    INITSEG  = 0x9000			! 将bootsect移动到0x9000处
    SETUPSEG = 0x9020			! setup程序开始的地址

    entry _start
    _start:

    ! 下面这段代码将自身从原来的0x07c0处复制到0x9000处
	    mov		ax,#BOOTSEG
	    mov		ds,ax
	    mov		ax,#INITSEG
	    mov		es,ax
	    mov		cx,#256
	    sub		si,si
	    sub		di,di
	    rep
	    movw
	
    ! 复制完成从0x9000的go标号处开始执行，jmpi表示段间跳转
	    jmpi	go,INITSEG 
    go:	    mov	        ax,cs
	    mov  	ds,ax  !设置ds=es=cs
	    mov 	es,ax

    ! 加载setup.s程序。setup.s的功能：setup的主要功能是首先获得光标，内存，显卡，磁盘等参数存放在0x90000为起始地址的空间中，然后将system模块从起始地址0x10000的所有代码，
      挪到0x0000(内存的起始地址处，之后system就一直存在于此处)。然后setup会初始化gdt表，idt表等等，最后用一个很酷的指令开启32位寻址方式，
      进入保护模式(在bootsect和setup执行的过程中cpu一直处于实模式，16位地址模式，最多能寻址1M的空间)。保护模式可以寻址4G的内存空间。
      
    ! 其中es:bx=内存地址; int 0x13是BIOS读磁盘扇区的中断。就是此时需要中断执行程序，让CPU去磁盘读数据
    ! 从磁盘哪点开始读数据呢？从cl开始扇区开始读, cl=02：即从第二个扇区开始读, al为扇区的个数，即读al=4个扇区。这4个扇区就是setup的扇区。
    ! 将读到的数据放在bootsect数据的之后的512字节的位置。512字节对应的是0x0200, es此时的值为0x9000, 故读到内存地址为0x90200位置。
    load_setup: 
	    mov		dx,#0x0000		! drive 0, head 0
	    mov		cx,#0x0002		! sector 2, track 0;      ch=柱面号, cl=开始扇区, dh=磁头号, dl=驱动器号
	    mov		bx,#0x0200		! address = 512, in INITSEG
	    mov		ax,#0x0200+SETUPLEN	! service 2, nr of sectors;  ah=0x02(读磁盘), al=扇区数量(SETUPLEN=4)
	    int		0x13			! read it
	    jnc		ok_load_setup		! ok - continue
	    ！加载错误
	    mov		dx,#0x0000
	    mov		ax,#0x0000		! reset the diskette
	    int		0x13
	    j		load_setup

    ! 载入setup模块：在显示屏上输出一些信息。其中0x10是BIOS输出显示信息的中断。
    ok_load_setup:

	    mov 	ah,#0x03		! read cursor pos; 因为要将字符串输出在显示器的光标位置，首先要获取显示器的光标位置。
	    xor 	bh,bh			! 页号，应该是屏幕位置的页号
	    int 	0x10			! 读取光标所在的位置 返回参数保存在dx寄存器中
	
	    mov 	cx,#37                  ! cx代表要输出字符串的个数, 要根据取“msg1的长度” 实时调整。要注意：除了我们设置的字符串 msg1 之外，还有三个换行 + 回车，一共是 6 个字符。故总的长度为“msg1的长度+6”。
	    mov 	bx,#0x000c		! page 0, attribute c;  读取光标所在的位置 返回参数保存在dx寄存器中。
	    mov 	bp,#msg1		! es:bp 指向待显示 字符串地址。bp是指要显示的字符串在内存中的偏移地址。
	    mov 	ax,#0x1301		! write string, move cursor; ah = 0x13 表示显示字符功能号，al = 0x01 表示光标的属性在bl保存。
	    int 	0x10			! 开启中断，开始从内存中读字符到屏幕中
    !开始执行setup代码
	    jmpi 0,SETUPSEG

    msg1:
	    .byte 13,10
	    .ascii "Hello OS world, my name is Kwin"
	    .byte 13,10,13,10

    .org 508
    boot_flag:
	    .word 0xAA55
    .text
    endtext:
    .data
    enddata:
    .bss
    endbss:
