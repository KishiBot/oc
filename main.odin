package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"
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
    VAR,
    OP,
    LOGIC,
    FUN,
};

op_e :: enum {
    ADD,
    SUB,
    MUL,
    DIV,
    POW,
    PAROP,
    PARCL,
    SEP,
}

precedence := [len(op_e)]u32 {
    0,
    0,
    1,
    1,
    2,
    3,
    3,
    3,
};

funcDescription := `Each function has following structure: func(..)
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
`;
functions := [?]string {"sin", "cos", "tan", "cot", "rad", "deg", "round", "floor", "ceil", "max", "min"};
funcArgNum := [?]int {
    1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0
}

token_s :: struct {
    type: token_e,
    op: op_e,
    val: f64,
    var: string,
};

node_s :: struct {
    token: token_s,
    left: ^node_s,
    right: ^node_s,
    children: [dynamic]^node_s,
}

tokens := make([dynamic]token_s, 0, 2048);
parseErr := false;
tokenizeErr := false;

isRightAssociative :: proc(op: op_e) -> bool {
    if (op == op_e.POW) do return true;
    return false;
}

parsePrimary :: proc() -> (ret: ^node_s) {
    ret = new(node_s);
    ret.token = {type=token_e.NUM, val=0};

    if len(tokens) == 0 {
        fmt.eprint("Missing primary token..\n");
        parseErr = true;
        return ret;
    }

    if (tokens[0].type == token_e.FUN) {
        ret.token = pop_front(&tokens);
        ret.children = make([dynamic]^node_s, 0, 8);
        for len(tokens) > 0 && tokens[0].type == token_e.LOGIC && (tokens[0].op == op_e.PAROP || tokens[0].op == op_e.SEP) {
            pop_front(&tokens);
            append(&ret.children, parseExpr(parsePrimary(), 0));
        }
    } else if (tokens[0].type == token_e.OP) {
        if (tokens[0].op == op_e.MUL || tokens[0].op == op_e.DIV) {
            parseErr = true;
            fmt.eprint("'*' or '/' cannot be a primary expression..\n");
            return ret;
        }

        ret.token = {type=token_e.NUM, val=0};
    } else if (tokens[0].type == token_e.LOGIC) {
        if (tokens[0].op == op_e.PARCL) {
            parseErr = true;
            fmt.eprint("')' cannot be a primary expression..\n");
            return ret;
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
    if (parseErr) do return nil;

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
                rhs = parseExpr(rhs, precedence[op.token.op]);
            } else {
                rhs = parseExpr(rhs, precedence[op.token.op] + 1);
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
        if (lookAhead.op != op_e.SEP) do pop_front(&tokens);
    }

    return lhs;
}

solve :: proc(cur: ^node_s) -> f64 {
    when !ODIN_DEBUG {
        defer {
            if (cur.children != nil) do delete(cur.children);
            free(cur);
        }
    }

    if (cur.token.type == token_e.NUM) do return cur.token.val;
    if (cur.token.type == token_e.VAR) {
        switch (cur.token.var) {
        case "ans", "ANS":
            return ans;
        case "pi", "PI":
            return math.PI;
        case "e", "E":
            return math.e;
        case:
            fmt.print("Unkown variable: ", cur.token.var, "\n", sep="");
            return 0;
        }
    }
    if (cur.token.type == token_e.FUN) {
        i := 0;
        for func, index in functions {
            if (cur.token.var == func) {
                i = index;
                break;
            }
        }

        if (funcArgNum[i] == 0) {
            if (len(cur.children) == 0) {
                fmt.eprintf("Invalide number of arguments. Expected: 1+, got: '%d'..\n", funcArgNum[i], len(cur.children));
                parseErr = true;
                return 0;
            }

        } else if (len(cur.children) != funcArgNum[i]) {
            fmt.eprintf("Invalide number of arguments. Expected: '%d', got: '%d'..\n", funcArgNum[i], len(cur.children));
            parseErr = true;
            return 0;
        }

        switch (cur.token.var) {
        case "sin":
            return math.sin(solve(cur.children[0]));
        case "cos":
            return math.cos(solve(cur.children[0]));
        case "tan":
            return math.tan(solve(cur.children[0]));
        case "cot":
            return 1 / math.tan(solve(cur.children[0]));
        case "rad":
            return math.to_radians(solve(cur.children[0]));
        case "deg":
            return math.to_degrees(solve(cur.children[0]));
        case "round":
            return math.round(solve(cur.children[0]));
        case "floor":
            return math.floor(solve(cur.children[0]));
        case "ceil":
            return math.ceil(solve(cur.children[0]));
        case "max":
            max := math.NEG_INF_F64;
            for child in cur.children {
                solved := solve(child);
                if (solved > max) do max = solved;
            }
            return max;
        case "min":
            min := math.INF_F64;
            for child in cur.children {
                solved := solve(child);
                if (solved < min) do min = solved;
            }
            return min;
        }
    }

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
    defer {
        if (node.children != nil) do delete(node.children);
        free(node);
    }

    myCount := nodeCounter;
    if (node.token.type == token_e.OP) {
        fmt.fprint(f, "    ", nodeCounter, " [label=\"", node.token.type, ": ", node.token.op, "\"]\n");
    } else if (node.token.type == token_e.NUM) {
        fmt.fprint(f, "    ", nodeCounter, " [label=\"", node.token.type, ": ", node.token.val, "\"]\n");
    } else {
        fmt.fprint(f, "    ", nodeCounter, "[label=\"", node.token.type, ": ", node.token.var, "\"]\n");
    }

    if (node.left != nil) {
        nodeCounter += 1;
        fmt.fprint(f, "    ", myCount, " -> ", nodeCounter, ";\n");
        drawNode(f, node.left);
    }
    if (node.children != nil) {
        for child in node.children {
            nodeCounter += 1;
            fmt.fprint(f, "    ", myCount, " -> ", nodeCounter, ";\n");
            drawNode(f, child);
        }
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

addNum :: proc(num: ^f64, buildingNum: ^bool, decimal: ^u64, var: ^[dynamic]u8) {
    if (len(var) != 0) {
        token: token_s = {type=token_e.VAR};
        token.var = strings.clone(string(var^[:]));

        for fun in functions {
            if token.var == fun {
                token.type = token_e.FUN;
                break;
            }
        }

        append(&tokens, token);
        clear(var);
    } else {
        buildingNum := buildingNum;
        if (buildingNum^) {
            append(&tokens, token_s({type=token_e.NUM, val=num^}));
            buildingNum^ = false;
            decimal^ = 0;
            num^ = 0;
        }
    }
}

var := make([dynamic]u8, 0, 64);
tokenize :: proc(buf: ^[dynamic]u8) {
    clear(&var);
    num: f64 = 0;
    buildingNum := false;
    decimal: u64 = 0;

    for ch, index in buf^[:len(buf)] {
        switch ch {
        case ' ', '\n':
            addNum(&num, &buildingNum, &decimal, &var);
        case '+':
            addNum(&num, &buildingNum, &decimal, &var);
            append(&tokens, token_s({type=token_e.OP, op=op_e.ADD}));
        case '-':
            addNum(&num, &buildingNum, &decimal, &var);
            append(&tokens, token_s({type=token_e.OP, op=op_e.SUB}));
        case '*':
            addNum(&num, &buildingNum, &decimal, &var);
            if (len(tokens) > 0 && tokens[len(tokens)-1].type == token_e.OP && tokens[len(tokens)-1].op == op_e.MUL) {
                tokens[len(tokens)-1].op = op_e.POW;
            } else {
                append(&tokens, token_s({type=token_e.OP, op=op_e.MUL}));
            }
        case '^':
            addNum(&num, &buildingNum, &decimal, &var);
            append(&tokens, token_s({type=token_e.OP, op=op_e.POW}));
        case '/':
            addNum(&num, &buildingNum, &decimal, &var);
            append(&tokens, token_s({type=token_e.OP, op=op_e.DIV}));
        case '(', '[', '{':
            addNum(&num, &buildingNum, &decimal, &var);
            append(&var, ch);
            append(&tokens, token_s({type=token_e.LOGIC, op=op_e.PAROP, var=strings.clone(string(var[:]))}));
            clear(&var);
        case ')', ']', '}':
            addNum(&num, &buildingNum, &decimal, &var);
            append(&var, ch);
            append(&tokens, token_s({type=token_e.LOGIC, op=op_e.PARCL, var=strings.clone(string(var[:]))}));
            clear(&var);
        case ',':
            addNum(&num, &buildingNum, &decimal, &var);
            append(&var, ch);
            append(&tokens, token_s({type=token_e.LOGIC, op=op_e.SEP, var=strings.clone(string(var[:]))}));
            clear(&var);
        case '.':
            if decimal > 0 {
                fmt.eprint("Two instances of '.' in one token..\n");
                resize(buf, 0);
            }
            decimal = 10;
        case '0'..='9':
            if decimal > 0 {
                num += (f64(ch)-48) / f64(decimal);
                decimal *= 10;
            } else {
                buildingNum = true;
                num = num*10 + f64(ch)-48;
            }
        case 'a'..='z', 'A'..='Z':
            append(&var, ch);
        }
    }
}

par := make([dynamic]string, 0, 8);
preprocess :: proc() {
    last := tokens[0];
    clear(&par);

    for i := 0; i < len(tokens); i += 1 {
        token := tokens[i];

        if (i != 0) {
            if (last.type == token_e.NUM && token.type == token_e.LOGIC && token.op == op_e.PAROP) {
                t: token_s = {type=token_e.OP, op=op_e.MUL};
                inject_at(&tokens, i, t);
                token = tokens[i];
            } else if (last.type == token_e.LOGIC && last.op == op_e.SEP && token.type == last.type && token.op == last.op) {
                ordered_remove(&tokens, i);
                i -= 1;
                continue;
            }
        }

        if (token.type == token_e.FUN && (i == len(tokens)-1 || tokens[i+1].type != token_e.LOGIC || tokens[i+1].op != op_e.PAROP)) {
            fmt.eprint("Function has to be followed by '('..\n");
            tokenizeErr = true;
            return;
        } else if (token.type == token_e.FUN) {
            t: token_s = {type=token_e.LOGIC, op=op_e.SEP};
            inject_at(&tokens, i+2, t);
        }

        if (token.type == token_e.LOGIC && token.op == op_e.PAROP) {
            append(&par, token.var);
        } else if (token.type == token_e.LOGIC && token.op == op_e.PARCL) {
            lastPar := pop(&par);
            test: string;
            switch (lastPar) {
            case "(":
                test = ")"
            case "[":
                test = "]"
            case "{":
                test = "}"
            }
            if (token.var != test) {
                fmt.eprint("Expected: '", test, "', got: '", token.var, "'..\n", sep="");
                tokenizeErr = true;
                return;
            }
        }

        last = token;
    }

    if len(par) > 0 {
        missing: string;
        switch (par[len(par)-1]) {
        case "(":
            missing = ")"
        case "[":
            missing = "]"
        case "{":
            missing = "}"
        }
        fmt.eprint("Expected: '", missing, "'..\n", sep="");
        tokenizeErr = true;
    }
}

help := `Cli calculator

--help           see help
-s (--separate)  take each argument as separate problems
--history=n      set number of remembered problems (default 256)
-f (--functions) returns a list of all functions implemented
`

historyCount: int = 256;
separate := false;

cursor := 1;
buf := make([dynamic]u8, 0, 4096);

history := make([dynamic]string, 0, historyCount);
historyCursor := 0;
ans: f64 = 0;

checkFlag :: proc(arg: string) -> (isFlag: bool) {
    if (arg[0] != '-') do return false;

    if (len(arg) >= 11 && arg[:10] == "--history=") {
        historyCount = strconv.atoi(arg[10:]);
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
    }
    return false;
}

run :: proc(buf: ^[dynamic]u8) {
    buf := buf;
    append(buf, '\n');

    if (len(history) == historyCount) {
        pop_front(&history);
    }

    str, err := strings.clone(string(buf[:]));
    if (err != nil) {
        fmt.eprint("Could not copy problem into history:", err, "\n");
    } else {
        append(&history, str);
        historyCursor = len(history);
    }

    tokenize(buf);
    defer {
        clear(buf);
        clear(&tokens);
    }

    if (len(tokens) > 0) {
        preprocess();
        if (!tokenizeErr) {
            tree := parseExpr(parsePrimary(), 0);
            if (tree == nil) do return;
            if (!parseErr) {
                ans = solve(tree);
                if (!parseErr) do fmt.print(ans, "\n");
            }

            when ODIN_DEBUG {
                drawGraph(tree);
            }
        }
        tokenizeErr = false;
        parseErr = false;
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

handleInput :: proc(key: [4]u8) -> (exit: bool) {
    if (key[1] == '\x1b') do return;
    if (key[0] == '\x1b' && key[1] == '[') {
        switch key[2] {
        case 65: // up
            historyCursor = max(historyCursor-1, 0);
            resize(&buf, len(history[historyCursor])-1);
            for i in 0..<len(buf) {
                buf[i] = history[historyCursor][i];
            }
            cursor = len(buf)+1;
            break;
        case 66: // down
            historyCursor = min(historyCursor+1, len(history)-1);
            resize(&buf, len(history[historyCursor])-1);
            for i in 0..<len(buf) {
                buf[i] = history[historyCursor][i];
            }
            cursor = len(buf)+1;
        case 67: // right
            if (cursor <= len(buf)) {
                cursor += 1;
            }
            break;
        case 68: // left
            if (cursor > 1) {
                cursor -= 1;
            }
            break;
        }
    } else {
        switch key[2] {
        case '0'..='9','*', '+', '-', '/', '^', 'a'..='z', 'A'..='Z', ' ', '.', '(', ')', '[', ']', '{', '}', ',':
            resize(&buf, len(buf)+1);
            for i := len(buf)-1; i >= cursor; i-=1 {
                buf[i] = buf[i-1];
            }
            buf[cursor-1] = key[2];
            cursor += 1;
        case 10: // enter
            if (len(buf) == 0) do return true;
            fmt.printf("\r\x1b[K%s\x1b[%dG\n", string(buf[:len(buf)]),  cursor);
            run(&buf);
            cursor = 1;
            clear(&buf);
            return;
        case 127: // backspace
            if (cursor > 1) {
                for i in cursor-2..<len(buf)-1 {
                    buf[i] = buf[i+1];
                }
                resize(&buf, len(buf)-1);
                cursor -= 1;
            }
        }
    }

    fmt.printf("\r\x1b[K%s\x1b[%dG", string(buf[:len(buf)]),  cursor);

    return false;
}

main :: proc() {
    setupTermios();
    defer tcsetattr(stdin, TCSANOW, &old);

    defer delete(buf);
    defer delete(tokens);
    defer delete(var);
    defer delete(par);
    defer {
        for &str in history do delete(str);
        delete(history);
    }

    if len(os.args) > 1 {
        offset: int = 0;
        for arg in os.args[1:] {
            if (checkFlag(arg)) do continue;

            append(&buf, arg);
            if (separate) do run(&buf);
        }

        if (!separate) do run(&buf);

        return;
    }

    key: [4]u8;
    for unix.sys_read(int(stdin), &key[3], 1) > 0 {
        key[0] = key[1];
        key[1] = key[2];
        key[2] = key[3];

        if (handleInput(key)) do break;
    }
}
