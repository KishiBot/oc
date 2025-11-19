package main

import c "core:c/libc"
import "core:sys/unix"
import "core:fmt"
import "core:strconv"
import "core:os"
import "core:math"

foreign import termios "system:libc.so"
foreign termios {
    tcgetattr :: proc "c" (fd: c.int, t: ^term) -> c.int ---
    tcsetattr :: proc "c" (fd: c.int, optional_actions: c.int, t: ^term) -> c.int ---
}

term :: struct {
    c_iflag: c.int,
    c_oflag: c.int,
    c_cflag: c.int,
    c_lflag: c.int,
    c_line: c.uint8_t,
    c_cc: [32]u8,
    c_ispeed: c.int,
    c_ospeed: c.int,
}

ICANON :c.int : 0x0002
ECHO   :c.int : 0x0008
TCSANOW :c.int : 0

help :: `Cli calculator

 --help           see help
 -v (--version)   see currently installed version
 -s (--separate)  take each argument as separate problems
 --history=n      set number of remembered problems (default 256)
 -f (--functions) returns a list of all functions implemented
`
funcDescription :: `Each function has following structure: func(..)
Function can have either set number of arguments ( sin(n) ), or unlimited ( max(..) ).
Multiple arguments have to be separated by ',' ( max(n, m) ).

 - sin(n)       returns sin of n, n is expected in radians
 - cos(n)       returns cos of n, n is expected in radians
 - tan(n)       returns tan of n, n is expected in radians
 - cot(n)       returns cot of n, n is expected in radians

 - rad(n)       converts n from degres to radians
 - deg(n)       converts n from radians to degrees

 - round(n)     rounds n, round(2.4) = 2, round(2.5) = 3
 - floor(n)     floors n, floor(2.5) = 2
 - ceil(n)      ceils n,  ceil(2.4) = 3

 - max(..)      returns max of all arguments
 - min(..)      returns min of all arguments

 - abs(n)       returns absolute value of n
`;

inputBuf := make([dynamic]u8, 0, 4096);

history := make([dynamic]string, 0, historyCount);
historyCount: int = 256;
historyCursor := 0;

separate := false;
cursor := 0;

stdin: c.int = 0;
old := term{};
termiosInit :: proc() {
    tcgetattr(stdin, &old);

    raw := old;
    raw.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(stdin, TCSANOW, &raw);
}

termiosTerminate :: proc() {
    tcsetattr(stdin, TCSANOW, &old);
}

checkFlag :: proc(arg: string) -> (isFlag: bool) {
    if (arg[0] != '-') do return false;

    if (len(arg) >= 11 && arg[:10] == "--history=") {
        historyCount := strconv.atoi(arg[10:]);
        if (historyCount < 1) {
            fmt.eprint("History count has to be >0..\n");
            historyCount = 256;
        }
        return true;
    }

    switch (arg) {
    case "--help":
        fmt.print(help, "\n");
        return true;
    case "-s", "--separate":
        separate = true;
        return true;
    case "-f", "--functions":
        fmt.print(funcDescription, "\n");
        return true;
    case "-v", "--version":
        fmt.print("OC ", version, "\n", sep="");
        return true;
    }
    return false;
}

@(private="file")
key: [4]u8;

handleInput :: proc() {
    c.system("tput cols > /tmp/terminalColCount");
    data, success := os.read_entire_file("/tmp/terminalColCount");
    os.remove("/tmp/terminalColCount");

    cols := 0;
    if (success) {
        cols, success = strconv.parse_int(string(data));
    }

    fmt.printf("\x1b[2J\x1b[H");
    for unix.sys_read(int(stdin), &key[3], 1) > 0 {
        key[0] = key[1];
        key[1] = key[2];
        key[2] = key[3];
        //53 54 65 66

        if (key[1] == '\x1b') do continue;
        if (key[0] == '\x1b' && key[1] == '[') {
            switch key[2] {
            case 53: // page up
                if (len(history) == 0) do break;
                historyCursor = max(historyCursor-1, 0);
                resize(&inputBuf, len(history[historyCursor])-1);
                for i in 0..<len(inputBuf) {
                    inputBuf[i] = history[historyCursor][i];
                }
                cursor = len(inputBuf);
                break;
            case 54: // page down
                if (len(history) == 0) do break;
                historyCursor = min(historyCursor+1, len(history)-1);
                resize(&inputBuf, len(history[historyCursor])-1);

                for i in 0..<len(inputBuf) {
                    inputBuf[i] = history[historyCursor][i];
                }
                cursor = len(inputBuf);
            case 65: // up
                if (cursor > cols) {
                    cursor -= cols;
                } else {
                    cursor = 0;
                }
            case 66: // down
                if (cursor <= len(inputBuf)-cols) {
                    cursor += cols;
                } else {
                    cursor = len(inputBuf);
                }
            case 67: // right
                if (cursor <= len(inputBuf)) do cursor += 1;
            case 68: // left
                if (cursor > 0) do cursor -= 1;
            }
        } else {
            switch key[2] {
            case '0'..='9','*', '+', '-', '/', '^', 'a'..='z', 'A'..='Z', ' ', '.', '(', ')', '[', ']', '{', '}', ',', '!':
                inject_at(&inputBuf, cursor, key[2]);
                cursor += 1;
            case 10: // enter
                if (len(inputBuf) == 0) do return;
                fmt.print("\n");
                // fmt.printf("\r\x1b[K%s\x1b[%dG\n", string(inputBuf[:len(inputBuf)]),  cursor);
                process(&inputBuf);
                cursor = 0;
                clear(&inputBuf);
                continue;
            case 127: // backspace
                if (cursor > 0) {
                    ordered_remove(&inputBuf, cursor-1);
                    cursor -= 1;
                }
            }
        }

        col := int(cursor % cols)+1;
        row := int(cursor / cols)+1;
        fmt.printf("\r\x1b[2J\x1b[H%s\x1b[%d;%dH", string(inputBuf[:len(inputBuf)]),  row, col);
    }
}
