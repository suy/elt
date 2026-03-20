package = 'elt'
version = '0.1.0-1'
source = {
    url = 'git://github.com/suy/elt.git',
    branch = 'elt',
    tag = 'v0.1.0'
}
description = {
    summary = 'Embedded Lua Templates - A template engine in pure Lua',
    detailed = [[
        ELT is a library that implements a template engine for Lua. It provides
        code to convert text templates with parameters into the desired final result,
        supporting logic for loops, conditions, and variable interpolation.
    ]],
    homepage = 'https://github.com/suy/elt',
    license = 'MIT'
}
dependencies = {
    'lua >= 5.1'
}
build = {
    type = 'builtin',
    modules = {
        elt = 'src/elt.lua'
    }
}
