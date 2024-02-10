import os
import rand
import readline

pub struct File {
mut:
    main_lines []string
    sects map[string][]string
}

pub struct App {
mut:
    files map[string]File
    main_vars map[string]string
    run bool
}

pub fn (mut a App) read_lines(file string) []string {
	mut result := []string{}

	mut lines := os.read_lines(file) or { panic(err) }

	for line in lines {
		if line.len == 0 { continue }
		if line[0].ascii_str() == '#' && line[1].ascii_str() != '!' { continue }

		result << line.trim_right('\n')
	}

	return result
}

pub fn (mut a App) read_vars(lines []string) map[string]string {
	mut vars := []string{}
	mut data := map[string]string

	for line in lines {
		if line.len == 0 { continue }
		if line[0].ascii_str() == '#' && line[1].ascii_str() != '!' { continue }
		if line[0].ascii_str() != '$' { continue }

		sep := line.trim_string_left('$').split(" ")
        data[sep[0]] = sep[1..].join(" ")
        if sep[0] in vars {
            println("error same variable can't be declared more than once!")
            continue
        }

        vars << sep[0]
	}

	vars.sort(a > b)

	for c in vars {
		for x, y in data {
			if c == x {
				continue
			}

			data[x] = y.replace("%"+c, data[c])
		}
	}

	return data
}

pub fn (mut a App) apply_variables(str string, vars map[string]string) string {
	mut result := str

	for var, val in vars {
		if result.contains('%$var') {
			result = result.replace('%$var', val)
		}
	}

	return result
}

pub fn (mut a App) apply(lines []string, vars map[string]string) []string {
	mut result := []string{}

	for line in lines {
        if line[0].ascii_str() == '$' { continue }

		result << a.apply_variables(line, vars)
	}

	return result
}

pub fn (mut a App) get_lines(lines []string) []string {
    mut result := []string{}
    mut in_snippet := false

    mut line_number := 0

    for line in lines {
        if line[0].ascii_str() == '{' {
            in_snippet = true
            continue
        } else if in_snippet {
            if line[0].ascii_str() == '}' {
                in_snippet = false
            }
            continue
        }

        result << line.replace('%linenum', line_number.str())
        line_number++
    }

    return result
}

pub fn (mut a App) read_snippets(lines []string) [][]string {
    mut in_snippet := false
    mut snippets := [][]string{}
    mut snippet := []string{}

    mut line_number := 0

    for line in lines {
        if line == '{' {
            in_snippet = true
            snippet = []string{}
        } else if in_snippet {
            if line != '}' {
                snippet << line.replace("%linenum", line_number.str())
                line_number++
            } else {
                in_snippet = false
                snippets << snippet
                snippet = []string{}
                line_number = 0
            }
        }
    }

    return snippets
}

pub fn (mut a App) print_snippets(snippets [][]string) {
    mut index := 0

    for snippet in snippets {
        for line in snippet {
            println(line)
        }
        index++
        if index != snippets.len {
            println("")
        }
    }
}

pub fn (mut a App) read_file(filename string) {
    if filename in a.files.keys() { return }

    if ! os.exists(os.getwd() + "/registry/" + filename) { return }

    lines := a.read_lines(os.getwd() + "/registry/" + filename)

    mut main_lines := []string{}

    mut sects := map[string][]string{}
    mut sect_name := ""

    mut index := 0

    for line in lines {
        if line[0].ascii_str() == '[' && line[line.len-1].ascii_str() == ']' {
            sect_name = line.trim_left('[').trim_right(']')
        } else if index == lines.len || line == '[endsect]' {
            sect_name = ""
        } else if sect_name != "" {
            sects[sect_name] << line.replace('%sectname', sect_name)
        } else {
            main_lines << line
        }
        index++
    }

    main_vars := a.read_vars(main_lines)

    mut new_sects := map[string][]string{}

    for sectname, sect1 in sects {
        mut new_sect := []string{}

        vars := a.read_vars(sect1)
        new_sect = a.apply(sect1, vars)
        new_sect = a.apply(new_sect, main_vars)

        new_sects[sectname] = new_sect.clone()
    }

    mut file := File{}
    file.sects = new_sects.clone()
    file.main_lines = a.apply(main_lines, main_vars)

    a.files[filename] = file
}

pub fn (mut a App) print_rand_snippets(snippets [][]string, count1 int) {
    mut count := count1

    if count > snippets.len {
        count = snippets.len
    } else if count < 1 {
        count = 1
    } else if count > 20 {
        count = 20
    }

    mut i := 0

    mut printed := []int{}

    for i < count {
        randval := rand.intn(snippets.len) or {0}
        if !printed.contains(randval) {
            printed << randval

            for line in snippets[randval] {
                println(line)
            }

            i++
        }
    }
}

pub fn (mut a App) action(cmd string) {
    args := cmd.split(" ")

    a.read_file(args[0])

    if !(args[0] in a.files.keys()) { return }

    file := a.files[args[0]]

    if args.len == 1 {
        for line in a.get_lines(file.main_lines) {
            println(line)
        }
    } else {
        match args[1] {
            "reload" {
                a.files.delete(args[0])
                a.read_file(args[0])
            }

            "snips" {
                a.print_snippets(a.read_snippets(file.main_lines))
            }

            "randsnip" {
                snippets := a.read_snippets(file.main_lines)

                mut count := 1

                if args.len == 3 {
                    if args[2].is_int() {
                        count = args[2].int()
                    }
                }

                a.print_rand_snippets(snippets, count)
            }

            "sect" {
                if args.len < 3 { return }
                if !(args[2] in file.sects.keys()) { return }

                for line in a.get_lines(file.sects[args[2]]) {
                    println(line)
                }
            }

            "sectsnips" {
                if args.len < 3 { return }
                if !(args[2] in file.sects.keys()) { return }

                a.print_snippets(a.read_snippets(file.sects[args[2]]))
            }

            "sectrandsnip" {
                if args.len < 3 { return }
                if !(args[2] in file.sects.keys()) { return }

                snippets := a.read_snippets(file.sects[args[2]])

                mut count := 1

                if args.len == 4 {
                    if args[3].is_int() {
                        count = args[3].int()
                    }
                }

                a.print_rand_snippets(snippets, count)
            }

            else { return }
        }
    }
}

fn main() {
    mut app := App{}
    app.run = true

    mut r := readline.Readline{}

    newline := $if windows { '\r\n' } $else { '\n' }

    for app.run == true {
        mut line := r.read_line('> ')!
        line = line.trim_right(newline)

        if line == "exit" {
            app.run = false
        } else {
            app.action(line)
        }

        continue
    }
}
