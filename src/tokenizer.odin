package main

import "core:strings"
import "core:fmt"

token_e:: enum {
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

token_s :: struct {
    type: token_e,
    op: op_e,
    val: f64,
    var: string,
};

tokens := make([dynamic]token_s, 0, 2048);
var := make([dynamic]u8, 0, 64);
tokenizerErr := false;

@(private="file")
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
