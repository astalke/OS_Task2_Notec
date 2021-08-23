;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Tytuł: Systemy Operacyjne, zadanie 2, Współbieżny Szesnastkator Noteć ;
; Autor: Andrzej Stalke                                                 ;
; Data: 03 kwiecień 2021                                                ;
; Opis: Moduł Współbieżnego Szesnastkatora Noteć wykonującego           ;
;       obliczenia na 64-bitowych liczbach zapisywanych przy podstawie  ;
;       16 i używającego odwrotnej notacji polskiej. Można uruchomić N  ;
;       działających równolegle instancji Notecia, numerowanych od 0 do ;
;       N − 1, gdzie N jest parametrem kompilacji.                      ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Eksportowana funkcja.
        global  notec   
; Zewnętrzna funkcja: int64_t debug(uint32_t n, uint64_t *stack_pointer);
        extern  debug   

; Początek sekcji kodu.
        section .text  
; Eksportowana funkcja o sygnaturze języka C:
; uint64_t notec(uint32_t n, char const *calc);
; edi := n    - numer instancji Notecia.
; rsi := calc - wskaźnik na napis ASCIIZ, który opisuje polecenie do wykonania.
; Wartość zwracana: rax := Wynik obliczenia, czyli wartość z wierzchu stosu.
notec:
        enter   8, 0                ; 8 - aby zapamiętać edi
        mov     [rbp - 0x8], edi    ; Zapamiętujemy pierwszy argument: n
        push    r14                 ; Zachowujemy wartość r14 w rbp - 0x10
        push    r12                 ; Zachowujemy wartość r12 w rbp - 0x18
        push    r13                 ; Zachowujemy wartość r13 w rbp - 0x20

        xor     r13b, r13b          ; Zaczynamy poza trybem wpisywania liczby.
        mov     r14, rsi            ; Kopiujemy rsi do r14
; Główna pętla programu. Czytamy po 1 bajcie z stringa i porównujemy go z
; kolejnymi możliwymi znakami.
; Pętla kończy się po wczytaniu bajtu 0.
; al - tutaj zostaje wczytany znak.
; r14 - wskazuje na następny znak do odczytania.
.loop:
        mov     al, [r14]           ; Pobieramy bajt.
        inc     r14                 ; Zwiększamy wskaźnik.
        test    al, al              ; Czy al == 0?
        jz      .end                ; Tak - koniec programu.
        ; Wartość niezerowa. Zaczynamy porównywać z kolejnymi elementami.
        cmp     al, '='             ; Wyjście z trybu wpisywania liczby.
        je      f_eql
        cmp     al, '&'             ; Operacja and.
        je      f_and
        cmp     al, '*'             ; Iloczyn.
        je      f_mul
        cmp     al, '+'             ; Dodawanie.
        je      f_add
        cmp     al, '-'             ; Negacja szczytu stosu.
        je      f_neg
        cmp     al, 'X'             ; Zamień miejscami 2 wartości z szczytu.
        je      f_X
        cmp     al, 'Y'             ; Zduplikuj wartość na wierzchu stosu.
        je      f_Y
        cmp     al, 'Z'             ; Usuń wartość z wierzchu stosu.
        je      f_Z
        cmp     al, 'N'             ; Wrzuć na stos liczbę noteci.
        je      f_N
        cmp     al, '^'             ; XOR na 2 el. z wierzchu stosu.
        je      f_xor
        cmp     al, 'n'             ; Wrzuć na stos numer tego notecia.
        je      f_n
        cmp     al, '|'             ; OR na 2 el. z wierzchu stosu.
        je      f_or
        cmp     al, '~'             ; Zaneguj bitowo szczyt stosu.
        je      f_not
        cmp     al, 'g'             ; Wywołaj funkcję debug.
        je      f_deb
        cmp     al, 'W'             ; Synchronizacja z innym wątkiem.
        je      f_sync
        ; Zaczynamy sprawdzanie, czy znak nie jest 0-9, A-F lub a-f
        ; Wszystkie inne zostały już sprawdzone.
        cmp     al, '0'             
        jb      .not09
        cmp     al, '9'
        jbe     f_digit            ; Znaleziono cyfrę 0-9
.not09:
        cmp     al, 'A'
        jb      .notAF
        cmp     al, 'F'
        jbe     f_AF               ; Znaleziono cyfrę A-F
.notAF:
        cmp     al, 'a'
        jb      .end                ; Undefined behaviour.
        cmp     al, 'f'
        jbe     f_af               ; Znaleziono cyfrę a-f
        ; Nieznany znak - wychodzimy z pętli w niezdefiniowany sposób.
; Pobierz wartość z szczytu stosu do rax (jako wynik) i zakończ funkcję.
.end:        
        pop     rax
        mov     r12, [rbp - 0x18]   ; Przywracamy r12.
        mov     r13, [rbp - 0x20]   ; Przywracamy r13.
        mov     r14, [rbp - 0x10]   ; Przywracamy r14.
        leave
        ret

; Skaczemy tutaj, aby zaznaczyć wejście do trybu wpisywania liczby.
f_enable_reading:
        or      r13b, 1
        jmp     notec.loop          ; Wracamy na początek pętli.

; Skaczemy tutaj, gdy natrafimy na cyfrę od 0 do 9.
f_digit:
        sub     al, '0'             ; Konwersja znaku cyfry na cyfrę.
        jmp     f_handle_digit      ; Skok do kodu dodającego wartość na stos.

; Skaczemy tutaj, gdy natrafimy na literę od A do F.
f_AF:
        sub     al, 'A' - 10        ; Konwersja znaku na liczbę. A -> 10
        jmp     f_handle_digit      ; Skok do kodu dodającego wartość na stos.

; Skaczemy tutaj, gdy natrafimy na literę od a do f.
f_af:
        sub     al, 'a' - 10        ; Konwersja znaku na liczbę. a -> 10
        jmp     f_handle_digit      ; Skok do kodu dodającego wartość na stos.

; Skaczemy tutaj, gdy chcemy dodać wartość trzymaną w al na stos zależnie od
; aktualnego trybu wpisywania cyfr.
f_handle_digit:
        and     rax, 0xFF;          ; Upewniamy się, że nie ma śmieci w rax.
        test    r13b, r13b          ; Sprawdzamy flagę.
        jnz     .f_handle_digit_ok  ; Skok, jeśli flaga ustawiona.
        push    0                   ; Tworzymy nową wartość na stosie.
; Skaczemy tutaj, jeśli jest już wrzucona wartość do modyfikowania na stos.
.f_handle_digit_ok:
        shl     qword [rsp], 4      ; Mnożymy wartość na stosie przez bazę. 
        add     [rsp], rax          ; Dodajemy wynik do wartości na stosie.
        jmp     f_enable_reading    ; Ustawiamy flagę.

; Skaczemy tutaj, by wyjść z trybu wypisywania liczby.
f_eql:
        xor     r13b, r13b          ; Wychodzimy z trybu wypisywania liczby.
        jmp     notec.loop          ; Wracamy na początek pętli.

; Skaczemy tutaj, gdy chcemy wykonać operację AND na 2 elementach stosu.
f_and:
        pop     rax                 ; Pobierz wartość z szczytu stosu.
        and     [rsp], rax          ; Wywołaj AND na drugiej wartości z stosu.
        jmp     f_eql               ; Wyjście z trybu wypisywania liczby.

; Skaczemy tutaj, gdy chcemy wykonać mnożenie 2 wartości z szczytu stosu.
f_mul:
        pop     rax                 ; Pobierz wartość z szczytu stosu.
        mul     qword [rsp]         ; Oblicz iloczyn wartości z szczytu stosu.
        mov     [rsp], rax          ; Wstaw wynik na szczyt stosu.
        jmp     f_eql               ; Wyjście z trybu wypisywania liczby.
; Skaczemy tutaj, gdy chcemy dodać 2 wartości z szczytu stosu.
f_add:
        pop     rax                 ; Pobierz wartość z szczytu stosu.
        add     [rsp], rax          ; Dodaj wartość do wartości na szczycie.
        jmp     f_eql               ; Wyjdź z trybu wpisywania liczby.

; Skaczemy tutaj, aby zanegować arytmetycznie wartość z sczytu stosu.
f_neg:
        neg     qword [rsp]
        jmp     f_eql               ; Wyjdź z trybu wpisywania liczby.

; Skaczemy tutaj, gdy chcemy zamienić miejscami 2 wartości z szczytu stosu.
f_X:
        pop     rax                 ; Pobierz wartość z szczytu stosu.
        xchg    rax, [rsp]          ; Zamień ją z wartością z szczytu stosu.
        push    rax                 ; Wstaw z powrotem na stos.
        jmp     f_eql               ; Wyjdź z trybu wpisywania liczby.

; Skaczemy tutaj, gdy chcemy zduplikować wartość na wierzchu stosu.
f_Y:
        pop     rax                 ; Pobierz wartość z szczytu stosu.
        push    rax                 ; Wstaw z powrotem na stos.
        push    rax                 ; Wstaw z powrotem na stos.
        jmp     f_eql               ; Wyjdź z trybu wpisywania liczby.

; Skaczemy tutaj, gdy chcemy usunąć wartość z wierzchu stosu.
f_Z:
        pop     rax                 ; Pobierz wartość z szczytu stosu.
        jmp     f_eql               ; Wyjdź z trybu wpisywania liczby.

; Skaczemy tutaj, gdy chcemy wrzucić na stos liczbę noteci.
f_N: 
        mov     rax, N              ; Gdyż nie ma push imm64
        push    rax
        jmp     f_eql               ; Wyjdź z trybu wpisywania liczby.

; Skaczemy tutaj, gdy chcemy wykonać XOR na szczycie stosu.
f_xor:
        pop     rax                 ; Pobierz wartość z szczytu stosu.
        xor     [rsp], rax          ; XOR szczyt stosu
        jmp     f_eql               ; Wyjdź z trybu wpisywania liczby.

; Skaczemy tutaj, gdy chcemy wrzucić na stos wartość tego notecia.
f_n:
        mov     eax, [rbp - 0x8]    ; Tutaj trzymamy numer notecia.
        push    rax
        jmp     f_eql               ; Wyjdź z trybu wpisywania liczby.

; Skaczemy tutaj, gdy chcemy wykonać OR na szczycie stosu.
f_or:
        pop     rax                 ; Pobierz wartość z szczytu stosu.
        or      [rsp], rax          ; Wywołaj OR na szczycie stosu.
        jmp     f_eql               ; Wyjdź z trybu wpisywania liczby.

; Skaczemy tutaj, gdy chcemy wykonać NOT na szczycie stosu.
f_not:
        not     qword [rsp]         ; Zaneguj szczyt stosu.
        jmp     f_eql               ; Wyjdź z trybu wpisywania liczby.

; Skaczemy tutaj, gdy chcemy wywołać funkcję debug.
; Debug ma sygnaturę: int64_t debug(uint32_t n, uint64_t *stack_pointer);
f_deb:
        mov     r12, rsp            ; Zachowujemy wskaźnik stosu.
        and     rsp, 0xFFFFFFFFFFFFFFF0 ; Wyrównanie stosu do 16.
        mov     edi, [rbp - 0x8]    ; Numer instancji Notecia.
        mov     rsi, r12            ; Wierzchołek stosu Notecia.
        call    debug               ; Wołamy zewnętrzną funkcję debug.
        mov     rsp, r12            ; Przywracamy stos.
        sal     rax, 3              ; Mnożmy wymagane przesunięcie stosu o 8. 
        add     rsp, rax            ; Dodajemy przesunięcie stosu.
        jmp     f_eql               ; Wyjdź z trybu wpisywania liczby.

; Skaczemy tutaj, gdy chcemy dokonać synchronizacji z innym wątkiem i zamienić
; się wartościami z wierzchu stosu.
; Zakładamy, że rax != 0 (co założyć możemy, bo al == 'W'.
; r8  := adres tablicy blokad.
; r9  := adres tablicy celów oczekiwania.
; r10 := adres tablicy wymian między wątkami.
; r11 := adres głównego mutexa.
f_sync:
        pop     rsi                 ; Pobieramy cel z wierzchu stosu (w esi).
        ; Potrzebne w obu sytuacjach.
        lea     r8,  [rel block]    ; Pobieramy adres tablicy blokad.
        lea     r9,  [rel target]   ; Pobieramy adres tab. oczekiwania
        lea     r10, [rel swap]     ; Adres tablicy wymian między wątkami.
        lea     r11, [rel mutex]    ; Adres głównego mutexa.
; Poniżej ustawiamy wartość, którą wymienimy z mutexem. Ważne jest tylko by 
; wstawiana wartość była niezerowa (al == 'W'). Zero oznacza wolny mutex.
.mutex_loop:
        xchg    rax, [r11]          ; Pobieramy wartość mutexa.
        test    rax, rax            ; Czy mamy wstęp?
        jnz     .mutex_loop         ; Skok, jeśli nie mamy wstępu.
        ; Mamy wstęp, rax == 0
        lea     rdx, [r8 + rsi]     ; Mamy adres stanu blokady celu.
        mov     al, [rdx]           ; Pobieramy stan celu.
        test    al, al              ; al == 0, jeśli cel jest niezablokowany.
        jz      .not_blocked
; Docieramy do tej etykiety, jeśli cel synchronizacji jest zablokowany.
.blocked:
        lea     rdi, [r9 + 4 * rsi] ; [rdi] to na kogo czeka cel.
        mov     eax, [rdi]          ; Pobieramy wartość.
        cmp     [rbp - 0x8], eax    ; Porównujemy z numerem tego Notecia.
        jne     .not_blocked        ; Nie czeka na nas - blokujemy się.
        ; Czeka na nas. Dokonujemy wymiany.
        lea     rdi, [r10 + 8 * rsi]; [rdi] - adres wartości z wierzchu
        pop     rax                 ; Pobieramy wartość z wierzchu stosu.
        xchg    rax, [rdi]          ; Zamieniamy się.
        push    rax                 ; Wrzucamy wartość z powrotem na stos.
        xor     eax, eax            ; Zerujemy rax.
        mov     [rdx], al           ; Zerujemy blokadę drugiego wątku.
        ; Nie oddajemy mutexu. Jest on dziedziczony przez budzony.
        jmp     f_eql               ; Wyjdź z trybu wpisywania liczby.
; Docieramy do tej etykiety, jeśli cel synchronizacji nie czeka na nas.
.not_blocked:
        mov     edx, [rbp - 0x8]    ; Pobieramy nasz numer.
        lea     rdi, [r8 + rdx]     ; Adres naszej blokady.
        mov     byte [rdi], 0x01    ; Zaznaczamy, że jesteśmy zablokowani.
        lea     rdi, [r9 + 4 * rdx] ; Adres na kogo czekamy.
        mov     [rdi], esi          ; Zaznaczamy na kogo czekamy.
        pop     rax                 ; Pobieramy wartość z wierzchu stosu.
        lea     rdi, [r10 + 8 * rdx]; Adres pola SWAP.
        mov     [rdi], rax          ; Umieszczamy wierzch stosu w tablicy SWAP.
        xor     eax, eax
        xchg    [r11], rax          ; Oddajemy mutex.
        add     r8, rdx             ; r8 - wskaźnik na blokadę.
        mov     al, 1               ; Umieszczamy niezerową wartość dla blokady.
; Pętla w której czekamy na zwolnienie blokady.
.blocked_loop:
        xchg    [r8], al            ; Pobierz blokadę.
        test    al, al              ; Czekamy na al == 0.
        jnz     .blocked_loop
        ; Zwolniona blokada - w rdi wciąż jest adres naszego SWAP.
        mov     [r8], al            ; Przywracamy stary stan blokady.
        mov     rax, [rdi]          ; Pobieramy otrzymaną wartość.
        push    rax                 ; I wrzucamy ją na stos.        
        xor     eax, eax
        xchg    [r11], rax          ; Oddajemy odziedziczony mutex.
        jmp     f_eql               ; Wyjdź z trybu wpisywania liczby.
      

; Początek sekcji niezainicjowanych danych.
        align 8
        section .bss
; Mutex pilnujący dostępu do tablicy blokad. 0 oznacza, że jest wolny dostęp.
; Przejęcie mutexa musi być wykonane z blokadą (xchg lub prefiks lock).
mutex:  resq    1                   

; Poniżej zdefiniowana jest tablica blokad. Dla każdego wątku trzymamy wartość
; czy jest zablokowany. 0 - niezablokowany, cokolwiek innego - zablokowany.
; Zmiana jakiejkolwiek wartości w tym bloku musi być poprzedzona blokadą mutexa.
; Służy również wątkom do wieszania się.
block:  resb    N                   

; Jeśli pole w tablicy block jest ustawione na wartość niezerową, to w poniższej
; tablicy jest numer wątku (4bajty) na jaki czeka wątek.
target: resd    N

; Pamięć służąca do wymiany danych między wątkami. Drugi wątek nie ma dostępu
; do stosu drugiego wątku, więc ma do tego poniższą tablicę. Wątek blokując się
; wstawia tutaj wartość z szczytu stosu. Drugi wątek zamienia wartość z tej
; tablicy z swoją wartością. Po zakończeniu oczekiwania, czekający zamienia
; wartość z wierzchu stosu z wartością z tej tablicy.
swap:   resq    N

