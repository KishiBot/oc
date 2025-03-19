# OC

### About

A simple cli calculator. Really nothing more.

### Requirements

Odin compiler

### Installation

Run `install.sh` script. It will call odin to build the program and copy it into "/usr/local/bin/". For that reason it will prompt you to enter your password. If you do not trust this program take a look at it. And it is <b>recommended</b> to not blindly trust random stuff on the internet.

### Usage

There are two ways to use the calculator. Enter an interactive mode by calling `oc` with no arguments. An interactive mode can be exited by entering in an emtpy line. Or you can give you problem as an argument `oc "2+3"`. You can pass in multiple arguments and they will be processed as single math problem. The argument has to be a string otherwise special characters like <b>*</b> will be handled incorrectly by bash.

### Why

OC, stands for odin calculator, is a personal in which I meant to write a cli calculator that is not a pain in the ... to use. Programs like bc are fine and all and bc itself does work very similarly to oc but has some quirks that irritate me. And for that reason, as well as my weird obsession with writing calculators, I have set out to write my own calculator in basically every language that I learn. (Currently it's c#, python, c and now odin).
