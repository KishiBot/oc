# OC

### About

A simple cli calculator. Really nothing more.

### Requirements

Odin compiler

### Installation

Run `install.sh` script. It will call odin to build the program and copy it into "/usr/local/bin/". For that reason it will prompt you to enter your password. If you do not trust this program take a look at it. And it is <b>recommended</b> to not blindly trust random stuff on the internet.

### Usage

There are two ways to use the calculator. Enter an interactive mode by calling `oc` with no arguments. An interactive mode can be exited by entering in an emtpy line. Or you can give your problem as an argument `oc "2+3"`. You can pass in multiple arguments and they will be processed as single math problem. You can set arguments to be considered as standalone problems with `-s` or `--separate` flag. This flag will influence only the arguments following it. The argument has to be a string otherwise special characters like <b>*</b> may be handled incorrectly by bash.<br>
The calculator uses history on runtime, meaning you can use <b>up</b> and <b>down</b> arrows on your keyobard to get past inputs without rewriting them manually. Length of history buffer can be changed with `--history=n` where n is the new length.

### Why

OC, stands for odin calculator, is a personal in which I meant to write a cli calculator that is not a pain in the ... to use. Programs like bc are fine and all and bc itself does work very similarly to oc but has some quirks that irritate me. And for that reason, as well as my weird obsession with writing calculators, I have set out to write my own calculator in basically every language that I learn. (Currently it's c#, python, c and now odin).
