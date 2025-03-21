package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:math"
import c "core:c/libc"
import "core:sys/unix"

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

foreign import termios "system:libc.so"
foreign termios {
    tcgetattr :: proc "c" (fd: c.int, t: ^term) -> c.int ---
    tcsetattr :: proc "c" (fd: c.int, optional_actions: c.int, t: ^term) -> c.int ---
}

ICANON :c.int : 0x0002
ECHO   :c.int : 0x0008
TCSANOW :c.int : 0

token_e :: enum {
    NUM,
    OP,
    LOGIC,
};

op_e :: enum {
    ADD,
    SUB,
    MUL,
    DIV,
    POW,
    PAROP,
    PARCL,
}

precedence := [len(op_e)]u32 {
    0,
    0,
    1,
    1,
    2,
    3,
    3,
};

token_s :: struct {
    type: token_e,
    op: op_e,
    val: f64,
};

node_s :: struct {
    token: token_s,
    left: ^node_s,
    middle: ^node_s,
    right: ^node_s,
}

tokens := make([dynamic]token_s, 0, 2048);

isRightAssociative :: proc(op: op_e) -> bool {
    if (op == op_e.POW) do return true;
    return false;
}

parsePrimary :: proc() -> (ret: ^node_s) {
    ret = new(node_s);
    if (tokens[0].type == token_e.OP) {
        if (tokens[0].op == op_e.MUL || tokens[0].op == op_e.DIV) {
            fmt.eprint("'*' or '/' cannot be a primary expression..\n");
            return nil;
        }

        ret.token = {type=token_e.NUM, val=0};
    } else if (tokens[0].type == token_e.LOGIC) {
        if (tokens[0].op == op_e.PARCL) {
            fmt.eprint("')' cannot be a primary expression..\n");
            return nil;
        }

        free(ret);
        pop_front(&tokens);
        return parseExpr(parsePrimary(), 0);
    } else {
        ret.token = pop_front(&tokens);
    }

    return ret;
}

parseExpr :: proc(lhs: ^node_s, minPrecedence: u32) -> (ret: ^node_s) {
    if (lhs == nil) do return nil;
    if len(tokens) == 0 do return lhs;
    lhs := lhs;

    lookAhead := tokens[0];
    for (lookAhead.type == token_e.OP && precedence[lookAhead.op] >= minPrecedence) {
        op := new(node_s);
        op.token = pop_front(&tokens);

        rhs := parsePrimary();
        if (len(tokens) == 0) {
            op.left = lhs;
            op.right = rhs;
            return op;
        }

        lookAhead = tokens[0];

        for (lookAhead.type == token_e.OP && precedence[lookAhead.op] >= precedence[op.token.op]) {
            if (precedence[lookAhead.op] == precedence[op.token.op]) {
                if (!isRightAssociative(lookAhead.op)) do break;
                rhs = parseExpr(rhs, precedence[op.token.type]);
            } else {
                rhs = parseExpr(rhs, precedence[op.token.type] + 1);
            }

            if (len(tokens) == 0) do break;
            lookAhead = tokens[0];
        }

        op.left = lhs;
        op.right = rhs;
        lhs = op;
        if (len(tokens) == 0) do break;
    } 

    if (lookAhead.type == token_e.LOGIC) {
        pop_front(&tokens);
    }

    return lhs;
}

solve :: proc(cur: ^node_s) -> f64 {
    if (cur.token.type == token_e.NUM) do return cur.token.val;

    if (cur.token.op == op_e.ADD) {
        return solve(cur.left) + solve(cur.right);
    } else if (cur.token.op == op_e.SUB) {
        return solve(cur.left) - solve(cur.right);
    } else if (cur.token.op == op_e.MUL) {
        return solve(cur.left) * solve(cur.right);
    } else if (cur.token.op == op_e.DIV) {
        return solve(cur.left) / solve(cur.right);
    } else if (cur.token.op == op_e.POW) {
        return math.pow(solve(cur.left), solve(cur.right));
    }

    return 0;
}

nodeCounter := 0;
drawNode :: proc(f: os.Handle, node: ^node_s) {
    myCount := nodeCounter;
    if (node.token.type == token_e.OP) {
        fmt.fprint(f, "    ", nodeCounter, " [label=\"", node.token.type, ": ", node.token.op, "\"]\n");
    } else if (node.token.type == token_e.NUM) {
        fmt.fprint(f, "    ", nodeCounter, " [label=\"", node.token.type, ": ", node.token.val, "\"]\n");
    }

    if (node.left != nil) {
        nodeCounter += 1;
        fmt.fprint(f, "    ", myCount, " -> ", nodeCounter, ";\n");
        drawNode(f, node.left);
    }
    if (node.middle != nil) {
        nodeCounter += 1;
        fmt.fprint(f, "    ", myCount, " -> ", nodeCounter, ";\n");
        drawNode(f, node.middle);
    }
    if (node.right != nil) {
        nodeCounter += 1;
        fmt.fprint(f, "    ", myCount, " -> ", nodeCounter, ";\n");
        drawNode(f, node.right);
    }
}

drawGraph :: proc(node: ^node_s) {
    os.remove("./graph.dot");
    {
        f, err := os.open("./graph.dot", os.O_CREATE | os.O_RDWR, 0o666);
        defer os.close(f);

        if (err != os.ERROR_NONE) {
            fmt.eprint("Could not open graph.dot: ", err, "\n");
            os.exit(1);
        }

        fmt.fprint(f, "digraph G {\n");
        drawNode(f, node);
        fmt.fprintf(f, "}");
    }

    c.system("dot -Tpng graph.dot -o graph.png");
    os.remove("graph.dot");
}

addNum :: proc(num: ^f64, buildingNum: ^bool) {
    buildingNum := buildingNum;
    if (buildingNum^) {
        append(&tokens, token_s({type=token_e.NUM, val=num^}));
        buildingNum^ = false;
        num^ = 0;
    }
}

tokenize :: proc(buf: [dynamic]u8) {
    num: f64 = 0;
    buildingNum := false;
    for ch, index in buf[:len(buf)] {
        if ch == ' ' || ch == '\n' {
            addNum(&num, &buildingNum);
        } else if ch == '+' {
            addNum(&num, &buildingNum);
            append(&tokens, token_s({type=token_e.OP, op=op_e.ADD}));
        } else if (ch == '-') {
            addNum(&num, &buildingNum);
            append(&tokens, token_s({type=token_e.OP, op=op_e.SUB}));
        } else if (ch == '*') {
            addNum(&num, &buildingNum);
            if (len(tokens) > 0 && tokens[len(tokens)-1].type == token_e.OP && tokens[len(tokens)-1].op == op_e.MUL) {
                tokens[len(tokens)-1].op = op_e.POW;
            } else {
                append(&tokens, token_s({type=token_e.OP, op=op_e.MUL}));
            }
        } else if (ch == '^') {
            addNum(&num, &buildingNum);
            append(&tokens, token_s({type=token_e.OP, op=op_e.POW}));
        } else if (ch == '/') {
            addNum(&num, &buildingNum);
            append(&tokens, token_s({type=token_e.OP, op=op_e.DIV}));
        } else if (ch == '(' || ch == '[' || ch == '{') {
            addNum(&num, &buildingNum);
            append(&tokens, token_s({type=token_e.LOGIC, op=op_e.PAROP}));
        } else if (ch == ')' || ch == ']' || ch == '}') {
            addNum(&num, &buildingNum);
            append(&tokens, token_s({type=token_e.LOGIC, op=op_e.PARCL}));
        } else {
            buildingNum = true;
            num = num*10 + f64(ch)-48;
        }
    }
}

preprocess :: proc() {
    last := tokens[0];
    for i in 1..<len(tokens) {
        token := tokens[i];

        if (last.type == token_e.NUM && token.type == token_e.LOGIC && token.op == op_e.PAROP) {
            for j := len(tokens)-1; j > i; j-=1 do tokens[j] = tokens[j-1];
            tokens[i] = {type=token_e.OP, op=op_e.MUL};
            token = tokens[i];
        }

        last = token;
    }
}

help := `Cli calculator

-h (--help)      see help
-s (--separate)  take each argument as separate problems
`

separate := false;

checkFlag :: proc(arg: string) -> (isFlag: bool) {
    if (arg[0] != '-') do return false;

    switch (arg) {
    case "-h", "--help":
        fmt.print(help, "\n");
        return true;
    case "-s", "--separate":
        separate = true;
        return true;
    }
    return false;
}

run :: proc(buf: [dynamic]u8) {
    buf := buf;
    append(&buf, '\n');

    tokenize(buf);
    if (len(tokens) > 0) {
        preprocess();
        tree := parseExpr(parsePrimary(), 0);
        if (tree == nil) do return;
        fmt.print(solve(tree), "\n");

        when ODIN_DEBUG {
            drawGraph(tree);
        }
    }
}

stdin: c.int = 0;
old := term{};
setupTermios :: proc() {
    tcgetattr(stdin, &old);

    raw := old;
    raw.c_lflag &= ~(ICANON | ECHO);
    tcsetattr(stdin, TCSANOW, &raw);
}

cursor := 0;
buf := make([dynamic]u8, 0, 4096);

handleInput :: proc(key: [4]u8) {
    if (key[0] == 27 && key[1] == 91) {
        switch key[2] {
        case 65: // up
            break;
        case 66: // down
            break;
        case 67: // right
            if (cursor < len(buf)) {
                cursor += 1;
            }
            break;
        case 68: // left
            if (cursor > 0) {
                cursor -= 1;
            }
            break;
        }
    } else {
        switch key[2] {
        case '0'..='9','*', '+', '-', '/', '^':
            fmt.printf("%c", key[2]);
            append(&buf, key[2]);
            cursor += 1;
            break;
        case 10: // enter
            break;
        case 127: // backspace
            if (cursor > 0) {
                for i in cursor-1..<len(buf)-1 {
                    buf[i] = buf[i+1];
                }
                resize(&buf, len(buf)-1);
                cursor -= 1;
            }
            break;
        }
    }

    // fmt.printf("%s %d\n", string(buf[:len(buf)]), cursor);
    fmt.printf("\r\x1b[K");
    fmt.print(string(buf[:len(buf)]));

}

main :: proc() {
    setupTermios();
    defer tcsetattr(stdin, TCSANOW, &old);

    defer delete(buf);
    defer delete(tokens);

    if len(os.args) > 1 {
        offset: int = 0;
        for arg in os.args[1:] {
            if (checkFlag(arg)) do continue;

            append(&buf, arg);
            if (separate) {
                run(buf);
                clear(&buf);
            }
        }

        if (!separate) do run(buf);

        return;
    }

    key: [4]u8;
    for unix.sys_read(int(stdin), &key[0], 1) > 0 {
        key[0] = key[1];
        key[1] = key[2];
        key[2] = key[3];

        // fmt.print(key[2], "\n");
        handleInput(key);
        // if (key[0] == 10) {
        //     if len(buf) == 0 do break;
        //     fmt.printf("%c", key[0]);
        //     run(buf);
        //     clear(&buf);
        // } else if (key[0] == 127) {
        //     fmt.print("\b \b");
        //     pop(&buf);
        // } else if ((key[0] >= 48 && key[0] <= 57) || (key[0] >= 40 && key[0] <= 43) || key[0] == 45 || key[0] == 47 || key[0] == 123 || key[0] == 125 || key[0] == 91 || key[0] == 93 || key[0] == 94) {
        //     append(&buf, key[0]);
        //     fmt.printf("%c", key[0]);
        // }
    }
}
