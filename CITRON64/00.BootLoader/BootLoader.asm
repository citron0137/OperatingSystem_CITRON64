[ORG 0x00]          ; 코드의 시작 어드레스를 0x00으로 설정
[BITS 16]           ; 16비트 코드로 설정

SECTION .text       ; text섹션 정의

jmp 0x07C0:START    ; 0x07C0(부트로더 영역)으로 CS 레지스터 지정 및 START로 이동

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 환경 설정 값
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
TOTALSECTORCOUNT:       dw 1024    
KERNEL32SECTORCOUNT:    dw 1024     

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Main 코드 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
START:
    ; CS(코드영역), ES (비디오 메모리 어드레스) 지정
    mov ax, 0x07C0
    mov ds, ax      ; 부트로더의 시작 주소를 DS 레지스터에 저장  
    mov ax, 0xB800      
    mov es, ax      ; ES 레지스터에 0xB800 (비디오 메모리 어드레스) 지정

    ; 스택 지정 (0x0000:0000~0x0000:FFFF)
    mov ax, 0x0000
    mov ss, ax
    mov sp, 0xFFFE
    mov bp, 0xFFFE

; 화면 지우기 
    mov si, 0       ; SI 레지스터(문자열 원본 인덱스 레지스터) 초기화    
.SCREENCLEARLOOP:
    mov byte [ es: si ], 0          ; 화면에 아무 문자도 안보이게끔
    mov byte [ es: si + 1 ], 0x06   ; 글자서식을 검정바탕에 노란색으로 지정    
    add si, 2
    cmp si, 80 * 25 * 2 ; 화면 전체 초기화
    jl .SCREENCLEARLOOP

; 화면 상단에 시작 메시지 출력
    push MESSAGE1           ; 출력 메시지
    push 0                  ; Y 좌표
    push 0                  ; X 좌표
    call PRINTMESSAGE
    add sp, 6               ; 스택 정리

; 이미지 로딩 메시지 출력 
    push IMAGELOADINGMESSAGE
    push 1
    push 0
    call PRINTMESSAGE
    add sp, 6
    
; 디스크 로딩 Step 1. 디스크 초기화
RESETDISK:
    ; BIOS RESET FUNCTION 호출
    mov ax, 0   ; 서비스 번호 0
    mov dl, 0   ; 드라이브 번호 0 (Floppy)
    int 0x13
    jc HANDLEDISKERROR  ; 에러가 발생한 경우 핸들러로 이동

; 디스크 로딩 Step 2. 디스크 섹터 읽기
    mov si, 0x1000         
    mov es, si          
    mov bx, 0x00000      ; 0x10000에 복사하기 위해 es, bx 지정 
    mov di, word [ TOTALSECTORCOUNT ]   ; 복사할 총 섹터수를 di에 저장

READDATA:
    cmp di, 0       
    je READEND          ; 모든 디스크를 다 읽은 경우 READEND로 이동
    sub di, 0x01

    ; BIOS READ Function으로 읽기
    mov ah, 0x02                    ; 서비스 번호 2 (Read Sector)
    mov al, 0x1                     ; 1개의 섹터 읽기
    mov ch, byte [ TRACKNUMBER ]    ; 읽을 트랙 번호 지정
    mov cl, byte [ SECTORNUMBER ]   ; 읽을 섹터 번호 지정
    mov dh, byte [ HEADNUMBER ]     ; 읽을 헤드 번호 지정
    mov dl, 0x00                    ; 읽을 드라이브 번호 0(Floppy) 지정
    int 0x13
    jc HANDLEDISKERROR              ; 에러 발생 확인

    ; 다음으로 읽을 어드레스, 트랙, 헤드, 섹터 계산
    add si, 0x0020                  ; 한번에 512(0x200)바이트씩 읽음, es에 더하기 위함
    mov es, si

    mov al, byte [ SECTORNUMBER ]   ; 읽은 섹터 번호 저장
    add al, 0x01                    ; 하나 증가
    mov byte [ SECTORNUMBER ], al   ; 다시 저장
    cmp al, 37  
    jl READDATA                     ; 19보다 작으면 다시 읽기

    xor byte [ HEADNUMBER ], 0x01   ; 헤드 번호를 토글하기
    mov byte [ SECTORNUMBER ], 0x01 ; 섹터번호를 다시 1로 설정

    cmp byte [ HEADNUMBER ], 0x00   ; 헤드 넘버가 0->1 으로 변경된 경우 
    jne READDATA                    ; 별다른 처리 없이 다시 읽기

    ; 트랙을 1 증가시킨 후 다시 섹터 읽기로 이동
    add byte [ TRACKNUMBER ], 0x01  ; 트랙번호 1증가
    jmp READDATA                    ; 다시 읽기
READEND:

; 디스크 로딩 Step 3(마지막). 성공 메시지 출력
    push LOADINGCOMPLETEMESSAGE
    push 1
    push 16
    call PRINTMESSAGE
    add sp, 6

; 로딩한 코드로 이동 
    jmp 0x1000:0x0000

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 함수 코드 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; 디스크 에러 처리 함수
HANDLEDISKERROR:
    push DISKERRORMESSAGE
    push 1
    push 16                 ; Image Loading... 뒤에 출력되도록
    call PRINTMESSAGE
    jmp $


; 메시지 출력함수
PRINTMESSAGE: 
    push bp
    mov bp, sp
    push es
    push si
    push di
    push ax
    push cx
    push dx

    ; 비디오 메모리 어드레스 지정
    mov ax, 0xB800
    mov es, ax

    ; 라인 주소구하기
    mov ax, word [ bp + 6 ] ; Y 좌표
    mov si, 160             ; 
    mul si                  ; * 160
    mov di, ax              ; di에 저장

    ; X좌표 x2로 들여쓰기 주소 구하기
    mov ax, word [ bp + 4 ] ; X 좌표
    mov si, 2               ;
    mul si                  ; * 2
    add di, ax              ; di에 더하기

    ; 출력할 문자열 주소 
    mov si, word [ bp + 8 ]

    ;출력 반복문
.MESSAGELOOP:
    mov cl, byte [ si ] ; 한 단어 복사
    cmp cl, 0           ; 0(끝) 이면 Break
    je .MESSAGEEND
    
    mov byte [ es: di ], cl ; 한글자를 해당 위치(es:di)에 출력
    
    add si, 1               ; 문자열 포인터는 1Byte씩 증가
    add di, 2               ; 비디오 메모리 포인터는 2Byte씩 증가
    jmp .MESSAGELOOP
.MESSAGEEND:
    
    ; 복귀 코드
    pop dx
    pop cx
    pop ax
    pop di
    pop si
    pop es
    pop bp
    ret 

; PRINTMESSAGE 종료 
    

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 데이터 영역 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 상수들
MESSAGE1:               db "CITRON64 OS BootLoader, Let's go!", 0 
IMAGELOADINGMESSAGE:    db "Image Loading...", 0
DISKERRORMESSAGE:       db " Fail, Disk Error", 0
LOADINGCOMPLETEMESSAGE: db " Success!", 0

; 변수들
SECTORNUMBER:           db 0x02
HEADNUMBER:             db 0x00
TRACKNUMBER:            db 0x00 

times 510 - ( $ - $$ )    db  0x00    ;510바이트를 00으로 채움 

db 0x55             ; 
db 0xAA             ; 0x55 0xAA로 부트섹터를 표시함
