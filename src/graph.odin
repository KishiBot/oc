package main

import "core:os"
import "core:fmt"
import c "core:c/libc"

@(private="file")
nodeCounter := 0;

@(private="file")
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
