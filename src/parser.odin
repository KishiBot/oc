package main

import "core:strings"
import "core:fmt"
import "core:math"

ans: f64;

functions := [?]string {"sin", "cos", "tan", "cot", "rad", "deg", "round", "floor", "ceil", "max", "min", "abs"};
funcArgNum := [?]int {
    1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1
}

node_s :: struct {
    token: token_s,
    left: ^node_s,
    right: ^node_s,
    children: [dynamic]^node_s,
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

parserErr := false;

parList := make([dynamic]string, 0, 8);
preprocess :: proc() {
    last := tokens[0];
    clear(&parList);

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
            parserErr = true;
            return;
        } else if (token.type == token_e.FUN) {
            t: token_s = {type=token_e.LOGIC, op=op_e.SEP};
            inject_at(&tokens, i+2, t);
        }

        if (token.type == token_e.LOGIC && token.op == op_e.PAROP) {
            append(&parList, token.var);
        } else if (token.type == token_e.LOGIC && token.op == op_e.PARCL) {
            lastPar := pop(&parList);
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
                parserErr = true;
                return;
            }
        }

        last = token;
    }

    if len(parList) > 0 {
        missing: string;
        switch (parList[len(parList)-1]) {
        case "(":
            missing = ")"
        case "[":
            missing = "]"
        case "{":
            missing = "}"
        }
        fmt.eprint("Expected: '", missing, "'..\n", sep="");
        parserErr = true;
    }
}

process :: proc(buf: ^[dynamic]u8) {
    buf := buf;
    append(buf, '\n');

    if (len(history) == historyCount) do pop_front(&history);

    // Save into history
    str, err := strings.clone(string(buf[:]));
    if (err != nil) {
        fmt.eprint("Could not copy input into history:", err, "\n");
    } else {
        append(&history, str);
        historyCursor = len(history);
    }

    tokenize(buf);
    defer {
        clear(buf);
        clear(&tokens);
        tokenizerErr = false;
        parserErr = false;
    }

    if (len(tokens) <= 0 || tokenizerErr) do return;

    preprocess();
    if (parserErr) do return;

    tree := parseExpr(parsePrimary(), 0);
    if (tree == nil || parserErr) do return;

    ans = solve(tree);
    if (!parserErr) do fmt.print(ans, "\n");

    when ODIN_DEBUG {
        drawGraph(tree);
    }
}

isRightAssociative :: proc(op: op_e) -> bool {
    if (op == op_e.POW) do return true;
    return false;
}

parsePrimary :: proc() -> (ret: ^node_s) {
    ret = new(node_s);
    ret.token = {type=token_e.NUM, val=0};

    if len(tokens) == 0 {
        fmt.eprint("Missing primary token..\n");
        parserErr = true;
        return ret;
    }

    if (tokens[0].type == token_e.FUN) {
        ret.token = pop_front(&tokens);
        ret.children = make([dynamic]^node_s, 0, 8);
        for len(tokens) > 0 && tokens[0].type == token_e.LOGIC && (tokens[0].op == op_e.PAROP || tokens[0].op == op_e.SEP) {
            pop_front(&tokens);
            append(&ret.children, parseExpr(parsePrimary(), 0, popLogic=false));
        }

        if len(tokens) > 0 && tokens[0].type == token_e.LOGIC && tokens[0].op == op_e.PARCL {
            pop_front(&tokens);
        } else {
            fmt.eprint("Expected ')' got '", tokens[0].var, "'..\n", sep="");
            parserErr = true;
            return ret;
        }
    } else if (tokens[0].type == token_e.OP) {
        if (tokens[0].op == op_e.MUL || tokens[0].op == op_e.DIV) {
            parserErr = true;
            fmt.eprint("'*' or '/' cannot be a primary expression..\n");
            return ret;
        }
    } else if (tokens[0].type == token_e.LOGIC) {
        if (tokens[0].op == op_e.PARCL) {
            parserErr = true;
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

parseExpr :: proc(lhs: ^node_s, minPrecedence: u32, popLogic: bool = true) -> (ret: ^node_s) {
    if (parserErr || lhs == nil) do return nil;
    if len(tokens) == 0 do return lhs;

    lhs := lhs;

    lookAhead := tokens[0];
    for (lookAhead.type == token_e.OP && precedence[lookAhead.op] >= minPrecedence) {
        op := new(node_s);
        op.token = pop_front(&tokens);

        rhs := parsePrimary();
        if len(tokens) == 0 {
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
        if len(tokens) == 0 do break;
    } 

    if len(tokens) > 0 && popLogic && lookAhead.type == token_e.LOGIC {
        pop_front(&tokens);
    }

    return lhs;
}

@(private="file")
solveConst :: proc(cur: ^node_s) -> f64 {
    switch (cur.token.var) {
    case "ans", "ANS":
        return ans;
    case "pi", "PI":
        return math.PI;
    case "e", "E":
        return math.e;
    case "inf", "INF", "Inf":
        return math.INF_F64;
    case:
        fmt.print("Unkown variable: ", cur.token.var, "\n", sep="");
        return 0;
    }
}

@(private="file")
solveFunc :: proc(cur: ^node_s) -> f64 {
    funcIndex := 0;
    for func, index in functions {
        if (cur.token.var == func) {
            funcIndex = index;
            break;
        }
    }

    if (funcArgNum[funcIndex] == 0) {
        if (len(cur.children) == 0) {
            fmt.eprintf(
                "Invalide number of arguments for function %s. Expected: 1+, got: '%d'..\n",
                cur.token.var, funcArgNum[funcIndex], len(cur.children));

            parserErr = true;
            return 0;
        }

    } else if (len(cur.children) != funcArgNum[funcIndex]) {
        fmt.eprintf(
            "Invalide number of arguments for function %s. Expected: '%d', got: '%d'..\n",
            cur.token.var, funcArgNum[funcIndex], len(cur.children));

        parserErr = true;
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
    case "abs":
        return math.abs(solve(cur.children[0]));
    }

    return 0;
}

solve :: proc(cur: ^node_s) -> f64 {
    when !ODIN_DEBUG {
        defer {
            if (cur.children != nil) do delete(cur.children);
            free(cur);
        }
    }

    if (cur.token.type == token_e.NUM) do return cur.token.val;
    if (cur.token.type == token_e.VAR) do return solveConst(cur);
    if (cur.token.type == token_e.FUN) do return solveFunc(cur);

    #partial switch cur.token.op {
    case .ADD:
        return solve(cur.left) + solve(cur.right);
    case .SUB:
        return solve(cur.left) - solve(cur.right);
    case .MUL:
        return solve(cur.left) * solve(cur.right);
    case.DIV:
        return solve(cur.left) / solve(cur.right);
    case.POW:
        n := solve(cur.left);
        exp := solve(cur.right);
        if (((exp > -1 && exp < 0) || (exp > 0 && exp < 1)) && n < 0) {
            fmt.eprint("Too complex..\n");
            parserErr = true;
            return 0;
        }
        return math.pow(n, exp);
    }

    return 0;
}
