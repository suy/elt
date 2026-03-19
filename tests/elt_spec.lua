-- Copyright (c) 2024-2025 Alejandro Exojo Piqueras
-- SPDX-License-Identifier: MIT

require '../tests/luassert-reversed-en'

local elt = require 'elt'

local plain_text = true -- For clarity in some string.find() calls.

--------------------------------------------------------------------------------
describe('The elt module', function()
    it('has the basics in it', function()
        assert.is_string(elt._COPYRIGHT)
        assert.is_string(elt._DESCRIPTION)
        assert.is_string(elt._VERSION)

        assert.is_table(elt.Chunks)
        assert.is_table(elt.Generator)
        assert.is_table(elt.Parser)

        assert.is_function(elt.compile)
        assert.is_function(elt.render)
    end)

end)


--------------------------------------------------------------------------------
describe('Chunks helper', function()
    it('is a table with helper functions', function()
        assert.is_table(elt.Chunks)
        assert.is_function(elt.Chunks.new)
        assert.is_function(elt.Chunks.append)
    end)

    it('can create instances with `new`', function()
        local chunks = elt.Chunks:new()
        assert.is_table(chunks)
        assert.is_table(getmetatable(chunks))
        assert.is_same(getmetatable(chunks), elt.Chunks)
    end)

    it('has an append function with two overloads', function()
        local chunks = elt.Chunks:new()
        chunks:append('foo')
        chunks:append('bar')
        assert.is_equal(#chunks, 2)
        assert.is_string(chunks[1])
        assert.is_string(chunks[2])

        chunks:append('baz', 42, elt.Chunks.CODE)
        assert.is_equal(#chunks, 3)
        assert.is_table(chunks[3])
        assert.is_string(chunks[3][1])
        assert.is_number(chunks[3][2])
        assert.is_equal(chunks[3][3], elt.Chunks.CODE)

        chunks:append('quux', 42, elt.Chunks.RAW)
        assert.is_equal(#chunks, 4)
        assert.is_table(chunks[4])
        assert.is_string(chunks[4][1])
        assert.is_number(chunks[4][2])
        assert.is_equal(chunks[4][3], elt.Chunks.RAW)
    end)

end)


--------------------------------------------------------------------------------
describe('Generator class', function()
    it('is a table with helper functions', function()
        assert.is_table(elt.Generator)
        assert.is_function(elt.Generator.new)
        assert.is_function(elt.Generator.generate)
        assert.is_function(elt.Generator.result)
    end)

    it('can create instances with `new`', function()
        local generator = elt.Generator:new()
        assert.is_table(generator)
        assert.is_table(getmetatable(generator))
        assert.is_same(getmetatable(generator), elt.Generator)
    end)

    local generator, chunks

    describe('once created', function()
        before_each(function()
            generator = elt.Generator:new()
            chunks = elt.Chunks:new()
        end)

        it('starts with an empty buffer and result', function()
            assert.is_table(generator.buffer)
            assert.is_same(#generator.buffer, 0)
            local result = generator:result()
            assert.is_same(result, '')
        end)

        it('generates a basic program with empty chunks', function()
            local result = generator:generate(chunks)
            assert.is_not_nil(result:find('local __insert, __buffer, __stringify, __escape = ...', 1, plain_text))
            assert.is_not_nil(result:find('return __buffer', 1, plain_text))
        end)

        it('generates a program that produces basic text', function()
            chunks:append([[Bob's "regular" text]])
            local result = generator:generate(chunks)
            local pattern = [[__insert(__buffer, "Bob's \"regular\" text")]]
            assert.is_not_nil(result:find(pattern, 1, plain_text))
        end)

        it('generates a program that inserts code verbatim', function()
            chunks:append('if condition then', 42, chunks.CODE)
            chunks:append('Condition was true')
            chunks:append('end', 44, chunks.CODE)
            local result = generator:generate(chunks)
            local pattern = [[__insert(__buffer, "Condition was true")]]
            assert.is_not_nil(result:find([=[--[[42]] if condition then]=], 1, plain_text))
            assert.is_not_nil(result:find(pattern, 1, plain_text))
            assert.is_not_nil(result:find([=[--[[44]] end]=], 1, plain_text))
        end)

        it('generates a program that interpolates values', function()
            chunks:append('interpolated', 42, chunks.RAW)
            local result = generator:generate(chunks)
            local pattern = [=[--[[42]] __insert(__buffer, __stringify(interpolated))]=]
            assert.is_not_nil(result:find(pattern, 1, plain_text))
        end)

        it('generates a program that interpolates and escapes values', function()
            chunks:append('escaped', 42, chunks.ESCAPE)
            local result = generator:generate(chunks)
            local pattern = [=[--[[42]] __insert(__buffer, __escape(__stringify(escaped)))]=]
            assert.is_not_nil(result:find(pattern, 1, plain_text))
        end)

        it('has functions that can be overridden', function()
            -- Entirely override the original function. This also happens to be
            -- useful to more easily check the output here in the tests.
            generator.result = function(self)
                return self.buffer
            end
            -- Override the original, but reusing the original implementation.
            generator.header = function(self)
                elt.Generator.header(self) -- Not as pretty as `super()`, but works.
                self:assign(('%q'):format('Special start'))
            end
            local result = generator:generate(chunks)
            assert.is_same(result[1], 'local __insert, __buffer, __stringify, __escape = ...\n')
            assert.is_same(result[2], '__insert(__buffer, ')
            assert.is_same(result[3], '"Special start"')
            assert.is_same(result[4], ')\n')
        end)

    end)

end)


--------------------------------------------------------------------------------
describe('Parser class', function()
    it('is a table with helper functions', function()
        assert.is_table(elt.Parser)
        assert.is_function(elt.Parser.new)
        assert.is_function(elt.Parser.wrap_source)
        assert.is_function(elt.Parser.parse)
    end)

    it('can create instances with `new`', function()
        local parser = elt.Parser:new()
        assert.is_table(parser)
        assert.is_table(getmetatable(parser))
        assert.is_same(getmetatable(parser), elt.Parser)
        assert.is_same(parser.delimiters, elt.delimiters)
        assert.is_not_equal(parser.delimiters, elt.delimiters)

        local copy = parser:new()
        assert.is_same(parser.delimiters, copy.delimiters)
        assert.is_not_equal(parser.delimiters, copy.delimiters)
        copy.delimiters.line = '|'
        assert.is_not_same(parser.delimiters, copy.delimiters)
    end)

    it('can wrap strings and arrays of strings in an iterator', function()
        local sources = {
            'first\nsecond\nthird\n',        -- UNIX LF.
            'first\nsecond\nthird',          -- UNIX LF, but no LF at EOF.
            'first\r\nsecond\r\nthird\r\n',  -- DOS CRLF.
            'first\r\nsecond\r\nthird',      -- DOS CRLF, but no CRLF at EOF.
            { 'first', 'second', 'third' },  -- Array of strings.
        }
        for _, source in ipairs(sources) do
            local results = {}
            for line in elt.Parser.wrap_source(source) do
                table.insert(results, line)
            end
            assert.is_same(results, {'first', 'second', 'third'})
        end

        -- Some more tests with empty lines.
        local results = {}
        for line in elt.Parser.wrap_source('1\n\n3\n\n\n') do
            table.insert(results, line)
        end
        assert.is_same(results, {'1', '', '3', '', ''})

        results = {}
        for line in elt.Parser.wrap_source({'1', '', '3', '', ''}) do
            table.insert(results, line)
        end
        assert.is_same(results, {'1', '', '3', '', ''})

        -- Now with "trivial" cases, without multiple lines.
        results = {}
        for line in elt.Parser.wrap_source('') do
            table.insert(results, line)
        end
        assert.is_same(results, {})

        results = {}
        for line in elt.Parser.wrap_source('Example') do
            table.insert(results, line)
        end
        assert.is_same(results, {'Example'})

        results = {}
        for line in elt.Parser.wrap_source({}) do
            table.insert(results, line)
        end
        assert.is_same(results, {})

        results = {}
        for line in elt.Parser.wrap_source({'Example'}) do
            table.insert(results, line)
        end
        assert.is_same(results, {'Example'})
    end)

    -- The above tests just use the Parser "class", without instance. Now we
    -- need to make one and work with it.
    local parser

    describe('once created', function()
        before_each(function()
            parser = elt.Parser:new()
        end)

        it('parses an empty string into empty chunks', function()
            local chunks = parser:parse('')
            assert.is_table(chunks)
            assert.is_table(getmetatable(chunks))
            assert.is_same(getmetatable(chunks), elt.Chunks)
            assert.is_same(#chunks, 0)
        end)

        it('parses a simple string into one chunk', function()
            local chunks = parser:parse('hello world')
            assert.is_same(chunks, {'hello world\n'})
        end)

        it('parses a simple string with a trailing newline into one chunk', function()
            local chunks = parser:parse('hello world\n')
            assert.is_same(chunks, {'hello world\n'})
        end)

        it('parses a simple string made of two lines into one chunk', function()
            local chunks = parser:parse('hello\nworld')
            assert.is_same(chunks, {'hello\nworld\n'})
        end)

        it('parses two simple strings into one large chunk', function()
            local chunks = parser:parse({'hello', 'world'})
            assert.is_same(chunks, {'hello\nworld\n'})
        end)

        it('parses lists of strings with empty lines', function()
            local chunks = parser:parse({'hello', '', '', 'world'})
            assert.is_same(chunks, {'hello\n\n\nworld\n'})
        end)

        it('parses the single line code mode', function()
            local chunks = parser:parse('% if something then')
            assert.is_same(chunks, {
                {' if something then', 1, elt.Chunks.CODE}
            })
        end)

        it('parses the start of entering into code mode', function()
            local chunks = parser:parse('<% if something then')
            assert.is_same(chunks, {
                {' if something then', 1, elt.Chunks.CODE}
            })
        end)

        it('parses entering and exiting code mode', function()
            local chunks = parser:parse('<% if something then %>')
            assert.is_same(chunks, {
                {' if something then ', 1, elt.Chunks.CODE},
                '\n',
            })
        end)

        it('parses two consecutive code blocks', function()
            local chunks = parser:parse('<% code1 %><% code2 %>')
            assert.is_same(chunks, {
                {' code1 ', 1, elt.Chunks.CODE},
                {' code2 ', 1, elt.Chunks.CODE},
                '\n',
            })
        end)

        it('parses a raw value output', function()
            local chunks = parser:parse('<%=value%>')
            assert.is_same(chunks, {
                {'value', 1, elt.Chunks.RAW},
                '\n',
            })
        end)

        it('parses an escaped value output', function()
            local chunks = parser:parse('<%!value%>')
            assert.is_same(chunks, {
                {'value', 1, elt.Chunks.ESCAPE},
                '\n',
            })
        end)

        it('does only look at the printing delimiter immediately after the open delimiter', function()
            -- This tests a bug that the library had at some point, in which it
            -- got confused by the equal sign in the middle of the code.
            local chunks = parser:parse('<% for index = 1, 3 do %>')
            assert.is_same(chunks, {
                {' for index = 1, 3 do ', 1, elt.Chunks.CODE},
                '\n',
            })
        end)

        --
        -- Start mixing modes.
        --

        it('parses a single line of text followed by code', function()
            local chunks = parser:parse('text<%code()%>')
            assert.is_same(chunks, {
                'text',
                {'code()', 1, elt.Chunks.CODE},
                '\n',
            })
        end)

        it('parses a single line of text, code and text again', function()
            local chunks = parser:parse('some text <% code() %> more text')
            assert.is_same(chunks, {
                'some text ',
                {' code() ', 1, elt.Chunks.CODE},
                ' more text\n',
            })
        end)

        it('parses text, a code block and text again (in multiple lines)', function()
            local chunks = parser:parse({
                'some text',
                '<% code() %>',
                'more text',
            })
            assert.is_same(chunks, {
                'some text\n',
                {' code() ', 2, elt.Chunks.CODE},
                '\nmore text\n',
            })
        end)

        it('parses text, a single-line code block and text again (in multiple lines)', function()
            local chunks = parser:parse({
                'some text',
                '% code()',
                'more text',
            })
            assert.is_same(chunks, {
                'some text\n',
                {' code()', 2, elt.Chunks.CODE},
                'more text\n',
            })
        end)

        it('parses a mix of text and code, with code ending on a different line', function()
            local chunks = parser:parse({
                'Text only',
                'Code about to start',
                '<% code()',
                '%> code ended',
            })
            assert.is_same(chunks, {
                'Text only\nCode about to start\n',
                {' code()', 3, elt.Chunks.CODE},
                {'', 4, elt.Chunks.CODE},
                ' code ended\n',
            })
        end)

        it('parses a mix of text and code, with code starting on a different line', function()
            local chunks = parser:parse({
                'Code about to start <%',
                'code() %>',
                'Code ended',
            })
            assert.is_same(chunks, {
                'Code about to start ',
                {'code() ', 2, elt.Chunks.CODE},
                '\nCode ended\n',
            })
        end)

        it('parses a mix of text and code, with a for loop', function()
            local chunks = parser:parse({
                'Hello',
                '% for i, item in pairs(items) do',
                '* <%= item %>',
                '% end',
            })
            assert.is_same(chunks, {
                'Hello\n',
                {' for i, item in pairs(items) do', 2, elt.Chunks.CODE},
                '* ',
                {' item ', 3, elt.Chunks.RAW},
                '\n',
                {' end', 4, elt.Chunks.CODE},
            })
        end)

        --
        -- Alternative markers.
        --

        it('parses with different delimiters', function()
            local chunks = parser:parse({
                '{{{if something then}}}',
                '{{{<=value}}}',
                '{{{end}}}',
            }, {
                open='{{{', close='}}}', raw='<='
            })
            assert.is_same(chunks, {
                {'if something then', 1, elt.Chunks.CODE},
                '\n',
                {'value', 2, elt.Chunks.RAW},
                '\n',
                {'end', 3, elt.Chunks.CODE},
                '\n',
            })
            chunks = parser:parse({
                '|if something then|',
                '|!value|',
                '|end|',
            }, {
                open='|', close='|', raw='!'
            })
            assert.is_same(chunks, {
                {'if something then', 1, elt.Chunks.CODE},
                '\n',
                {'value', 2, elt.Chunks.RAW},
                '\n',
                {'end', 3, elt.Chunks.CODE},
                '\n',
            })

            -- Try changing the delimiters in the instance.
            parser.delimiters = {
                open='|', close='|', raw='!'
            }
            chunks = parser:parse({
                '|if something then|',
                '|!value|',
                '|end|',
            })
            assert.is_same(chunks, {
                {'if something then', 1, elt.Chunks.CODE},
                '\n',
                {'value', 2, elt.Chunks.RAW},
                '\n',
                {'end', 3, elt.Chunks.CODE},
                '\n',
            })
            local copy = parser:new()
            copy.delimiters = {
                open='||', close='||', raw='!!'
            }
            chunks = copy:parse({
                '||if something then||',
                '||!!value||',
                '||end||',
            })
            assert.is_same(chunks, {
                {'if something then', 1, elt.Chunks.CODE},
                '\n',
                {'value', 2, elt.Chunks.RAW},
                '\n',
                {'end', 3, elt.Chunks.CODE},
                '\n',
            })
        end)

    end)

end)


--------------------------------------------------------------------------------
describe('The `amend_error` function', function()
    it('rewrites the line number to reference the template line', function()
        -- Copied from `elt.loader`. This is pretty much everything it does.
        local loader = function(code_text, code_name)
            local load_function = type(loadstring) == 'function' and loadstring or load
            return load_function(code_text, code_name)
        end

        local prefix = 'local __buffer, __stringify, __escape = ...'
        local postfix = 'return __buffer'
        local function wrap(code)
            table.insert(code, 1, prefix)
            table.insert(code, postfix)
            return table.concat(code, '\n')
        end

        local code = wrap({'--[[1]] if true then'})
        local template, original = loader(code)
        assert.is_nil(template)
        assert.is_string(original)
        local amended = elt.amend_error(original, code)
        assert.is_string(amended)
        -- Fail at finding the original line indicator.
        assert.is_nil(amended:find(':2:', 1, plain_text))
        assert.is_not_nil(amended:find(':~1(elt):', 1, plain_text))

        code = wrap({
            '--[[1]] if true then',
            '--[[2]] __insert(__buffer, __stringify( 42|0 ))',
            '--[[3]] end',
        })
        template, original = loader(code)
        assert.is_nil(template)
        assert.is_string(original)
        amended = elt.amend_error(original, code)
        assert.is_string(amended)
        assert.is_nil(amended:find(':3:', 1, plain_text))
        assert.is_not_nil(amended:find(':~2(elt):', 1, plain_text))

        code = wrap({
            '--[[1]] if true then',
            '--[[2]] __insert(__buffer, __stringify( valid ))',
            '--[[3]] end',
            '--[[4]] failure_here',
        })
        template, original = loader(code)
        assert.is_nil(template)
        assert.is_string(original)
        amended = elt.amend_error(original, code)
        assert.is_string(amended)
        assert.is_nil(amended:find(':6:', 1, plain_text))
        assert.is_not_nil(amended:find(':~4(elt):', 1, plain_text))
    end)
end)


--------------------------------------------------------------------------------
describe('The `loader` function', function()
    -- For Lua >=5.2 compatibility.
    local setfenv = setfenv or function(wrapped, environment)
        local upvalue = 1
        while true do
            local name = debug.getupvalue(wrapped, upvalue)
            if name == '_ENV' then
                debug.upvaluejoin(wrapped, upvalue, (function()
                    return environment
                end), 1)
                break
            elseif not name then
                break
            end
            upvalue = upvalue + 1
        end
        return wrapped
    end

    it('returns a callable function from correct Lua code in a string', function()
        local callable, err = elt.loader('return 42')
        assert.is_function(callable)
        assert.is_same(callable(), 42)
        assert.is_nil(err)

        callable, err = elt.loader('return 40 + 2')
        assert.is_function(callable)
        assert.is_same(callable(), 42)
        assert.is_nil(err)

        callable, err = elt.loader('return value')
        setfenv(callable, { value = 42 })
        assert.is_function(callable)
        assert.is_same(callable(), 42)
        assert.is_nil(err)
    end)

end)


--------------------------------------------------------------------------------
describe('The `execute` function', function()
    it('calls a function with an environment and passing some parameters', function()
        local called = false
        local prefilled_buffer = {'previous text'}
        local environment = {example=true, value=42}

        local f = function(insert, buffer)
            called = true
            insert(buffer, 'new content')
            if example then
                insert(buffer, 'example was true')
            end
            insert(buffer, tostring(value))

            return buffer
        end

        local result = elt.execute(f, environment, prefilled_buffer)
        assert.is_same(called, true)
        assert.is_same(result, {
            'previous text',
            'new content',
            'example was true',
            '42',
        })

        called = false
        prefilled_buffer = {'previous text'}
        environment = {}
        result = elt.execute(f, environment, prefilled_buffer)
        assert.is_same(called, true)
        assert.is_same(result, {
            'previous text',
            'new content',
            'nil',
        })
    end)

end)


--------------------------------------------------------------------------------
describe('The `to_code` function', function()
    it('checks for `options` being a table or nil', function()
        assert.has_errors(function()
            elt.to_code('hello', 42)
        end)
        assert.has_errors(function()
            elt.to_code('hello', 'there')
        end)
    end)

    it('uses the default Parser and Generator if not provided', function()
        local new = spy.on(elt.Parser, 'new')
        elt.to_code('hello')
        assert.spy(new).was_called()
        elt.Parser.new:revert()

        new = spy.on(elt.Generator, 'new')
        elt.to_code('hello')
        assert.spy(new).was_called()
        elt.Generator.new:revert()
    end)

    it('uses the provided Parser and Generator to replace the defaults', function()
        local generator = elt.Generator:new()
        generator.header = function(self)
            -- Replicate the usual header preamble, but add an extra message.
            elt.Generator.header(self)
            self:assign(('%q'):format('Special start'))
        end
        local result = elt.to_code('hello', {generator = generator})
        assert.is_not_nil(result:find('Special start', 1, plain_text))

        local parser = elt.Parser:new()
        parser.parse = function()
            -- It never parses anything.
            local chunks = elt.Chunks:new()
            chunks:append('goodbye')
            return chunks
        end
        result = elt.to_code('hello', {parser = parser})
        assert.is_not_nil(result:find('goodbye', 1, plain_text))
        assert.is_nil(result:find('hello', 1, plain_text))
    end)

end)


--------------------------------------------------------------------------------
describe('The `compile` function', function()
    it('creates a ready to use function from a text template', function()
        local template = elt.compile('Hello world')
        assert.is_same(template(), 'Hello world\n')

        template = elt.compile('Hello <%= greeting_name %>')
        assert.is_same(template(), 'Hello nil\n')
        assert.is_same(template({greeting_name = 'world'}), 'Hello world\n')
        assert.is_same(template({greeting_name = 'Bob'}), 'Hello Bob\n')
        _G.greeting_name = 'global'
        assert.is_same(template(), 'Hello global\n')
        _G.greeting_name = nil
    end)

    it('creates a function that can take a buffer to append to', function()
        local hello = elt.compile('Hello')
        local world = elt.compile('world')
        local buffer = { 'Previous content\n' }
        hello({}, buffer)
        world({}, buffer)
        assert.is_same(buffer, { 'Previous content\n', 'Hello\n', 'world\n' })
    end)
end)



--------------------------------------------------------------------------------
describe('The render function', function()
    it('produces the expected text correctly', function()
        local files = {
            '01-hello-world',
            '02-no-nl-at-eof',
            '03-multiple-lines',
            '04-empty-lines',
            '11-hello-void',
            '12-hello-void',
            '13-hello-void',
            '21-hello-name',
            '22-hello-name',
            '23-hello-hello',
            '24-hello-hello',
            '25-hello-lines',
            '26-hello-lines',
            '27-hello-lines',
            '31-skips-newline',
            '32-skips-newline',
            '33-list-in-loop',
            '34-list-in-loop',
            '35-list-in-loop',
            '51-complex-mix',
            '52-print-delimiters',
        }
        local data = {
            name='world',
            list={'foo', 'bar', 'baz'},
            truthy=true,
        }

        for _, name in ipairs(files) do
            local template_file = assert(io.open('tests/samples/' .. name .. '.elt', 'r'))
            local expected_file = assert(io.open('tests/samples/' .. name .. '.txt', 'r'))
            local template_data = template_file:read('*all')
            local expected_data = expected_file:read('*all')

            local rendered = elt.render(template_data, data)
            assert.equal(rendered, expected_data)

            --[[
            -- Just some useful boilerplate to inspect the template's internals.
            print(('=== %s ==='):format(name))
            local inspect = require('inspect')
            local parser = elt.Parser:new()
            local chunks = parser:parse(template_data)
            for _, chunk in ipairs(chunks) do
                print(inspect(chunk))
            end
            local generator = elt.Generator:new()
            print(generator:generate(chunks))
            --]]

        end
    end)

    it('supports the escape option correctly', function()
        local options = {}
        local context = {}
        local hardcoded = function()
            return "hardcoded"
        end

        context.bad = 42
        assert.equal(elt.render('<%! bad %>', context, options), '42\n')

        options.escape = hardcoded
        assert.equal(elt.render('<%! bad %>', context, options), 'hardcoded\n')

        context.bad = '<script>alert("xss")</script>'
        options.escape = elt.escape_html
        assert.equal(elt.render('<%! bad %>', context, options),
            '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;\n')

        -- Escape function can't be shadowed (accidentally or maliciously).
        context.__escape = false
        assert.equal(elt.render('<%! bad %>', context, options),
            '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;\n')
        context.__escape = function(value) return value end
        assert.equal(elt.render('<%! bad %>', context, options),
            '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;\n')
    end)

    it('escapes correctly when setting the escape function globally', function()
        local options = {}
        local context = {}

        context.bad = '<script>alert("xss")</script>'
        elt.escape = elt.escape_html
        assert.equal(elt.render('<%! bad %>', context, options),
            '&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;\n')
        -- Restore it.
        elt.escape = function(value)
            return value
        end
    end)

    -- We used to use `table.insert` in the template implementation to append to
    -- the buffer. Now we pass that function as an argument, so `table` is free.
    it('supports the name `table` in the context', function()
        local context = { table = 'correct' }
        assert.equal(elt.render('<%! table %>', context),
            'correct\n')
    end)

end)
