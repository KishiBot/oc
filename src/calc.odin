package main

import "core:os"

version := "1.1.1"

main :: proc() {
    if len(os.args) > 1 {
        offset: int = 0;
        for arg in os.args[1:] {
            if (checkFlag(arg)) do continue;

            append(&inputBuf, arg);
            if (separate) do process(&inputBuf);
        }

        if (!separate) do process(&inputBuf);

        return;
    }

    termiosInit();
    defer {
        termiosTerminate();
        delete(tokens);
        delete(var);
        delete(history);
        delete(inputBuf);
        delete(parList);
    }


    handleInput();
}
